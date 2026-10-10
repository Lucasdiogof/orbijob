import { jobicyConnector, JOBICY_SOURCE } from './connectors/jobicy';
import { ConfigError, loadConfig, type Env } from './env';
import { HttpError, withRetry, type RetryOptions } from './http';
import { acquireLease } from './lease';
import { createLogger, type LogSink } from './log';
import { SupabaseJobStore } from './store/supabase';
import { runSync, type SyncRunRow, type SyncSummary } from './sync';

/** One scheduled pass of the Jobicy source. Everything the platform provides is injected, so tests need no Workers runtime. */
export interface Deps {
  fetch: typeof fetch;
  now: () => Date;
  sink: LogSink;
  sleep?: (ms: number) => Promise<void>;
  retry?: Partial<RetryOptions>;
}

/** A Worker invocation may run up to 15 minutes of wall clock (Cron Triggers); the pass stops on its own well before. */
export const RUN_BUDGET_MS = 12 * 60_000;
/** A running row older than this is a crashed run (must exceed RUN_BUDGET_MS). */
export const LEASE_TTL_MS = 20 * 60_000;
/** Jobicy: "do not start new automated synchronization passes more frequently than once per hour". */
export const MIN_INTERVAL_MS = 60 * 60_000;

export type Outcome =
  | { status: 'ok' | 'partial' | 'failed'; summary: SyncSummary }
  | { status: 'skipped'; reason: 'running' | 'too_soon' | 'lost_race' };

/** The run could not even start (no usable credential, database unreachable) or died unexpectedly. */
export class SyncFailure extends Error {
  constructor(readonly kind: 'auth' | 'unreachable' | 'unexpected') {
    super(`sync failure: ${kind}`);
    this.name = 'SyncFailure';
  }
}

export async function runScheduledSync(env: Env, deps: Deps): Promise<Outcome> {
  const plainLog = createLogger(deps.sink, [env.SUPABASE_SERVICE_ROLE_KEY ?? ''], deps.now);
  let cfg;
  try {
    cfg = loadConfig(env);
  } catch (e) {
    // Fail loudly and early: nothing else can work without a valid configuration. Only variable names and reasons are logged.
    plainLog('error', 'config_invalid', { problems: e instanceof ConfigError ? e.problems : ['unreadable configuration'] });
    throw e;
  }
  const log = createLogger(deps.sink, [cfg.serviceKey], deps.now);
  const retry: RetryOptions = { retries: 2, baseMs: 1000, maxMs: 15_000, sleep: deps.sleep, ...deps.retry };
  const store = new SupabaseJobStore(cfg.supabaseUrl, cfg.serviceKey, deps.fetch);
  const startedAt = deps.now();

  // 1. Take the lease BEFORE touching the source: a wrong credential or an unreachable database is found here, and no
  //    request is wasted on Jobicy.
  let lease;
  try {
    lease = await withRetry(
      () => acquireLease(store, { sourceId: JOBICY_SOURCE.id, scope: '', now: startedAt, ttlMs: LEASE_TTL_MS, minIntervalMs: MIN_INTERVAL_MS }),
      retry,
    );
  } catch (e) {
    const auth = e instanceof HttpError && (e.status === 401 || e.status === 403);
    log('error', auth ? 'supabase_auth_failed' : 'supabase_unreachable', { status: e instanceof HttpError ? e.status : undefined, keyKind: cfg.keyKind });
    throw new SyncFailure(auth ? 'auth' : 'unreachable');
  }
  if (lease.kind === 'skipped') {
    log('info', 'sync_skipped', { reason: lease.reason });
    return { status: 'skipped', reason: lease.reason };
  }

  // 2. The pass. Its final record goes to the row opened by the lease, so the table shows one row per run.
  log('info', 'sync_start', { runId: lease.id, maxPages: cfg.maxPages, budgetMs: RUN_BUDGET_MS });
  let summary: SyncSummary;
  try {
    summary = await runSync({
      connector: jobicyConnector(deps.fetch, deps.now, { origin: cfg.jobicyOrigin }),
      store,
      scope: '',
      now: deps.now,
      sleep: deps.sleep,
      retry: deps.retry,
      maxPages: cfg.maxPages,
      deadlineAt: startedAt.getTime() + RUN_BUDGET_MS,
      recordRun: (run: SyncRunRow) => store.finishRun(lease.id, {
        status: run.status, finished_at: run.finished_at, fetched: run.fetched, upserted: run.upserted,
        duplicates: run.duplicates, closed: run.closed, http_errors: run.http_errors, error_class: run.error_class,
      }),
      log: (event, data) => log(event === 'sync.error' || event === 'sync.run_not_recorded' ? 'warn' : 'info', event, data),
    });
  } catch {
    // runSync reports its own failures as a summary; reaching here is a bug. Leave a closed record instead of a stuck lease.
    await store.finishRun(lease.id, { status: 'failed', finished_at: deps.now().toISOString(), error_class: 'unexpected' }).catch(() => {});
    log('error', 'sync_crashed', { runId: lease.id });
    throw new SyncFailure('unexpected');
  }

  if (!summary.runRecorded) log('warn', 'run_record_missing', { runId: lease.id }); // the lease row stays 'running' until its TTL
  log(summary.status === 'ok' ? 'info' : summary.status === 'partial' ? 'warn' : 'error', `sync_${summary.status}`, {
    runId: lease.id, pages: summary.pages, fetched: summary.fetched, upserted: summary.upserted, duplicates: summary.duplicates,
    rejected: summary.rejected, closed: summary.closed, httpErrors: summary.http_errors, errorClass: summary.error_class,
    restarted: summary.restarted, durationMs: deps.now().getTime() - startedAt.getTime(),
  });
  return { status: summary.status, summary };
}
