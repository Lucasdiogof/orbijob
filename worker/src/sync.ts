import { Deduper, canonicalUrl, fingerprint, shouldMarkClosed } from './dedupe';
import { HttpError, RateLimiter, withRetry, type RetryOptions } from './http';
import type { Connector, NormalizedJob } from './types';

/** One row of `public.jobs` (no `id`, `cluster_id`, `isco08` or the generated `search` column). */
export interface JobRow {
  source_id: string;
  external_id: string;
  company: string;
  title: string;
  description: string;
  country: string | null;
  city: string | null;
  language: string | null;
  work_mode: 'remote' | 'hybrid' | 'onsite' | 'unspecified';
  contract_type: string | null;
  salary_min: number | null;
  salary_max: number | null;
  salary_currency: string | null;
  salary_period: 'hour' | 'day' | 'week' | 'month' | 'year' | null;
  published_at: string | null;
  last_checked_at: string;
  requirements: string[];
  skills: string[];
  original_url: string;
  apply_url: string | null;
  status: 'open' | 'closed' | 'unknown';
  geo_restrictions: string[];
  fingerprint: string;
  canonical_url: string;
}

/** One row of `public.sync_runs`: counts and status only, never payloads or personal data. */
export interface SyncRunRow {
  source_id: string;
  scope: string;
  started_at: string;
  finished_at: string;
  status: 'ok' | 'partial' | 'failed';
  fetched: number;
  upserted: number;
  duplicates: number;
  closed: number;
  http_errors: number;
  error_class: string | null;
}

export function toJobRow(j: NormalizedJob): JobRow {
  return {
    source_id: j.source,
    external_id: j.externalId,
    company: j.company,
    title: j.title,
    description: j.description,
    country: j.country,
    city: j.city,
    language: j.language,
    work_mode: j.workMode,
    contract_type: j.contractType,
    salary_min: j.salaryMin,
    salary_max: j.salaryMax,
    salary_currency: j.salaryCurrency,
    salary_period: j.salaryPeriod,
    published_at: j.publishedAt,
    last_checked_at: j.lastCheckedAt,
    requirements: j.requirements,
    skills: j.skills,
    original_url: j.originalUrl,
    apply_url: j.applyUrl,
    status: j.status,
    geo_restrictions: j.geoRestrictions,
    fingerprint: fingerprint(j),
    canonical_url: canonicalUrl(j.originalUrl),
  };
}

/** Persistence port. The Supabase implementation lives in `store/supabase.ts`; tests use an in-memory one. */
export interface JobStore {
  /** Insert-or-update by (source_id, external_id): running the same page twice leaves one row. */
  upsertJobs(rows: JobRow[]): Promise<void>;
  listOpenExternalIds(sourceId: string): Promise<string[]>;
  markClosed(sourceId: string, externalIds: string[]): Promise<void>;
  /**
   * Records that the source itself just confirmed these stored jobs are still open (their `last_checked_at` moves to now).
   * Without it a job that left the 7-day feed could never be told apart from one nobody has verified for weeks.
   */
  confirmOpen?(sourceId: string, externalIds: string[]): Promise<void>;
  /** Every stored external id of the source, whatever its status (used to count jobs that would be NEW; see `maxNewJobs`). */
  listKnownExternalIds?(sourceId: string): Promise<string[]>;
  recordRun(run: SyncRunRow): Promise<void>;
}

export interface SyncOptions {
  connector: Connector;
  store: JobStore;
  /** Source-specific filter (Jobicy: `geo=usa&industry=engineering`). */
  scope?: string;
  now?: () => Date;
  sleep?: (ms: number) => Promise<void>;
  retry?: Partial<RetryOptions>;
  /** Safety cap on pages per pass. */
  maxPages?: number;
  /**
   * Epoch milliseconds after which no new request is started. The pass then ends as `partial` (error class `deadline`)
   * and nothing is closed: a Worker invocation has a wall-clock limit and must stop on its own terms.
   */
  deadlineAt?: number;
  /** Where the final run record goes. Default: `store.recordRun` (a new row). A caller that opened the row earlier (lease) updates it instead. */
  recordRun?: (run: SyncRunRow) => Promise<void>;
  /**
   * Declares that a COMPLETE traversal of [scope] lists every open job of the source (a single-board source). Only then is
   * "absent from a full snapshot" treated as closed. Default false: with several scopes under one source id (one board per
   * company), a snapshot of one scope says nothing about the jobs of the others, and closing them would be wrong.
   * Sources that expose a status endpoint (Jobicy) do not need this: they close only what the source itself reports closed.
   */
  snapshotCoversSource?: boolean;
  /**
   * `full` (default): the normal pass. `revalidate`: no feed request, no upsert; only the status check of stored open jobs
   * (close the confirmed closed, stamp the confirmed open, leave everything else). Requires a connector with `checkStatuses`.
   */
  mode?: 'full' | 'revalidate';
  /** `full` only: at most this many jobs not already stored are added in this pass; the rest wait for a later pass. Needs `store.listKnownExternalIds`. */
  maxNewJobs?: number;
  /** Structured log sink. Receives counts and error classes only: never job content, URLs of users, keys or tokens. */
  log?: (event: string, data: Record<string, unknown>) => void;
}

export interface SyncSummary extends Omit<SyncRunRow, 'source_id' | 'scope' | 'started_at' | 'finished_at'> {
  pages: number;
  /** Records the adapter refused (invalid id/title/URL). Not a `sync_runs` column, so it lives only here and in the log. */
  rejected: number;
  /** Cursor expired mid-pass and the pass was restarted from the beginning (at most once). */
  restarted: boolean;
  runRecorded: boolean;
  /** `full` mode with `maxNewJobs`: listings of the feed that were NOT stored because the cap was reached. */
  skippedNew: number;
  /** Stored jobs the source confirmed open in this pass (status endpoint). */
  confirmed: number;
  /** Stored jobs the source could not confirm either way (answered 'unknown', or not answered): left as they are, never closed. */
  unverified: number;
}

function errorClass(e: unknown): string {
  if (e instanceof HttpError) return `http_${e.status}`;
  const name = (e as { name?: string } | null)?.name;
  if (name === 'TimeoutError' || name === 'AbortError') return 'timeout';
  return 'network_or_parse';
}

/**
 * One synchronization pass for one source and scope:
 *   fetch (rate limited, retried) -> validate/normalize (adapter) -> dedupe -> upsert page by page
 *   -> only after a COMPLETE traversal, decide which stored jobs are closed.
 * A failure never closes anything: closure needs a finished pass plus the source's own evidence.
 */
export async function runSync(o: SyncOptions): Promise<SyncSummary> {
  const now = o.now ?? (() => new Date());
  const sleep = o.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const log = o.log ?? (() => {});
  const retry: RetryOptions = { retries: 4, baseMs: 1000, maxMs: 30_000, sleep, ...o.retry };
  const scope = o.scope ?? '';
  const sourceId = o.connector.id;
  const limiter = new RateLimiter(o.connector.minIntervalMs);
  const deduper = new Deduper();
  const seen = new Set<string>();
  const startedAt = now().toISOString();
  const s: SyncSummary = {
    status: 'ok', fetched: 0, upserted: 0, duplicates: 0, closed: 0, http_errors: 0, error_class: null,
    pages: 0, rejected: 0, restarted: false, runRecorded: false, confirmed: 0, unverified: 0, skippedNew: 0,
  };

  let cursor: string | null = null;
  let completed = false;
  let lastPageFull = false;
  const fail = (e: unknown) => {
    s.http_errors += e instanceof HttpError ? 1 : 0;
    s.error_class = errorClass(e);
    s.status = s.upserted > 0 ? 'partial' : 'failed'; // 'partial' = something was stored before the failure
    log('sync.error', { source: sourceId, errorClass: s.error_class, pages: s.pages });
  };

  const pastDeadline = () => o.deadlineAt !== undefined && now().getTime() >= o.deadlineAt;
  const revalidateOnly = o.mode === 'revalidate';
  if (revalidateOnly && !o.connector.checkStatuses) { s.status = 'failed'; s.error_class = 'no_status_check'; }

  // `maxNewJobs`: the ids already stored (any status) tell which listings would be NEW; only that many are added.
  let known: Set<string> | null = null;
  let newCount = 0;
  if (!revalidateOnly && o.maxNewJobs !== undefined) {
    try {
      if (!o.store.listKnownExternalIds) throw new Error('store cannot list known ids');
      known = new Set(await withRetry(() => o.store.listKnownExternalIds!(sourceId), retry));
    } catch (e) {
      fail(e); // without knowing what is stored the cap cannot be honoured: add nothing
    }
  }

  for (let guard = 0; !revalidateOnly && s.status === 'ok' && guard < (o.maxPages ?? 50) + 1; guard++) {
    if (s.pages >= (o.maxPages ?? 50)) { s.status = 'partial'; s.error_class = 'max_pages'; break; }
    if (pastDeadline()) { s.status = s.upserted > 0 ? 'partial' : 'failed'; s.error_class = 'deadline'; break; }
    const wait = limiter.reserve();
    if (wait > 0) await sleep(wait);
    let page;
    try {
      page = await withRetry(() => o.connector.fetchPage(cursor, scope), retry);
    } catch (e) {
      // An expired/altered cursor is answered with HTTP 400 by Jobicy: the documented remedy is a new traversal.
      if (e instanceof HttpError && e.status === 400 && cursor !== null && !s.restarted) {
        s.restarted = true; s.http_errors++; cursor = null;
        log('sync.cursor_restart', { source: sourceId });
        continue;
      }
      fail(e);
      break;
    }
    s.pages++;
    s.fetched += page.jobs.length + (page.rejected?.length ?? 0);
    s.rejected += page.rejected?.length ?? 0;
    const fresh: NormalizedJob[] = [];
    for (const j of page.jobs) {
      seen.add(j.externalId);
      if (!deduper.accept(j)) { s.duplicates++; continue; }
      if (known && !known.has(j.externalId)) {
        if (newCount >= o.maxNewJobs!) { s.skippedNew++; continue; }
        newCount++; known.add(j.externalId);
      }
      fresh.push(j);
    }
    try {
      if (fresh.length) await withRetry(() => o.store.upsertJobs(fresh.map(toJobRow)), retry);
      s.upserted += fresh.length;
    } catch (e) {
      fail(e);
      break;
    }
    lastPageFull = page.isFullSnapshot;
    if (page.nextCursor === null) { completed = true; break; }
    cursor = page.nextCursor;
  }

  const acc = { closed: 0, confirmed: 0, unverified: 0 };
  if (revalidateOnly && s.status === 'ok') {
    // Revalidation only: every stored open job is "absent" (nothing was read from the feed) and is asked about; nothing is imported.
    try {
      await closeStale(o, sourceId, new Set(), false, retry, limiter, sleep, pastDeadline, acc);
    } catch (e) {
      fail(e);
      s.status = acc.closed + acc.confirmed > 0 ? 'partial' : 'failed'; // what earlier batches proved is already stored
    }
  } else if (completed && s.status === 'ok') {
    try {
      await closeStale(o, sourceId, seen, lastPageFull && o.snapshotCoversSource === true, retry, limiter, sleep, pastDeadline, acc);
    } catch (e) {
      fail(e); // the pass itself was fine; only the closure step is missing
      s.status = 'partial';
    }
  }
  s.closed = acc.closed; s.confirmed = acc.confirmed; s.unverified = acc.unverified;

  const run: SyncRunRow = {
    source_id: sourceId, scope, started_at: startedAt, finished_at: now().toISOString(),
    status: s.status, fetched: s.fetched, upserted: s.upserted, duplicates: s.duplicates, closed: s.closed,
    http_errors: s.http_errors, error_class: s.error_class,
  };
  try {
    await withRetry(() => (o.recordRun ?? ((r) => o.store.recordRun(r)))(run), retry);
    s.runRecorded = true;
  } catch (e) {
    log('sync.run_not_recorded', { source: sourceId, errorClass: errorClass(e) });
  }
  log('sync.done', { source: sourceId, status: s.status, pages: s.pages, fetched: s.fetched, upserted: s.upserted, duplicates: s.duplicates, rejected: s.rejected, closed: s.closed, confirmed: s.confirmed, unverified: s.unverified, skippedNew: s.skippedNew });
  return s;
}

/** Status questions per pass: bounds the extra requests when many old jobs are still open. The rest waits for the next pass. */
const STATUS_BATCH = 100;
const MAX_STATUS_BATCHES = 30;

/**
 * Closes only what the source proves closed (absent from a full snapshot that covers the whole source, or answered "closed" by its
 * status endpoint) and records what it confirms still open. Progress is applied per batch: if a later batch fails, what earlier
 * batches proved stays. A job the source answers "unknown" for, or does not answer for, is left exactly as it is.
 */
async function closeStale(
  o: SyncOptions, sourceId: string, seen: Set<string>, snapshotCovers: boolean, retry: RetryOptions,
  limiter: RateLimiter, sleep: (ms: number) => Promise<void>, pastDeadline: () => boolean,
  out: { closed: number; confirmed: number; unverified: number },
): Promise<void> {
  const open = await withRetry(() => o.store.listOpenExternalIds(sourceId), retry);
  const absent = open.filter((id) => !seen.has(id));
  if (!absent.length) return;
  const byAbsence: string[] = shouldMarkClosed({ isFullSnapshot: snapshotCovers }, open, seen);
  if (byAbsence.length) {
    await withRetry(() => o.store.markClosed(sourceId, byAbsence), retry);
    out.closed = byAbsence.length;
    return;
  }
  if (!o.connector.checkStatuses) return;
  const check = o.connector.checkStatuses.bind(o.connector);
  for (let i = 0, b = 0; i < absent.length && b < MAX_STATUS_BATCHES; i += STATUS_BATCH, b++) {
    if (pastDeadline()) throw new Error('deadline'); // the pass is reported as partial; what earlier batches proved is already stored
    const batch = absent.slice(i, i + STATUS_BATCH);
    const wait = limiter.reserve();
    if (wait > 0) await sleep(wait);
    const answers = await withRetry(() => check(batch), retry);
    const closed = batch.filter((id) => answers[id] === 'closed');
    const confirmed = batch.filter((id) => answers[id] === 'open');
    if (closed.length) { await withRetry(() => o.store.markClosed(sourceId, closed), retry); out.closed += closed.length; }
    if (confirmed.length && o.store.confirmOpen) { await withRetry(() => o.store.confirmOpen!(sourceId, confirmed), retry); }
    out.confirmed += confirmed.length;
    out.unverified += batch.length - closed.length - confirmed.length;
  }
}
