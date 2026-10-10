/**
 * Exclusive run of one source across Worker instances, decided by the DATABASE, atomically.
 *
 * Why not a global variable: a Worker runs in many isolates, in many places, and Cloudflare documents no exactly-once
 * delivery for Cron Triggers nor anything about overlapping runs. A module-level flag only protects one isolate.
 *
 * Why not "read, insert, read again": that is an optimistic check. Each step is a separate request on its own connection,
 * a fresh row is not instantly visible to every reader, and ordering rivals by clock/id after the fact can let two runs
 * pass. A pause makes it rarer, never impossible (measured on a real PostgREST: see docs/JOBICY_WORKER.md).
 *
 * What this does instead, with the tables that already exist (so NO database change is needed):
 *   The id of a run is NOT random: it is derived from (source, one-hour slot). `sync_runs.id` is a PRIMARY KEY, so of any
 *   number of runs that try to start in the same slot, PostgreSQL lets exactly ONE insert succeed; every other insert is
 *   refused with a unique violation (HTTP 409 through PostgREST). The decision is made inside the database, in one
 *   statement, regardless of timing, connections, clocks or PostgREST version. No sleep takes part in it.
 *
 * Before claiming, two cheap checks avoid pointless attempts and give the reason in the logs:
 *   - a run still 'running' and younger than the TTL (it may belong to the previous slot, when a long run straddles the hour);
 *   - a run that finished less than `minIntervalMs` ago (the source's "one pass per hour" rule).
 * 'running' rows older than the TTL belong to a crashed run and are closed as failed (`stale_lock`).
 *
 * Residual cases, all harmless for correctness (every write is an upsert on a unique key and a job is only closed on the
 * source's own evidence): a run that straddles the slot boundary while a second delivery arrives in the next slot is stopped by
 * the 'running' check, not by the key; after a crash, the slot of the crashed run stays used until the next hour.
 */
export interface RunRef {
  id: string;
  status: string;
  started_at: string;
  error_class: string | null;
}

export interface RunPatch {
  status?: 'running' | 'ok' | 'partial' | 'failed';
  finished_at?: string;
  fetched?: number;
  upserted?: number;
  duplicates?: number;
  closed?: number;
  http_errors?: number;
  error_class?: string | null;
}

/** The ledger refused to create a run because that id already exists (primary key / unique violation). */
export class RunConflict extends Error {
  constructor() {
    super('run id already exists');
    this.name = 'RunConflict';
  }
}

export interface RunLedger {
  /** Runs of the source with status 'running', of any age. */
  runningRuns(sourceId: string): Promise<RunRef[]>;
  /** Runs of the source that are not 'running' and started at or after [sinceIso]. */
  finishedSince(sourceId: string, sinceIso: string): Promise<RunRef[]>;
  /**
   * Inserts a 'running' row and returns its id. With an explicit `id` the insert must be ATOMIC and fail with
   * {@link RunConflict} if that id exists already (that is the whole mutual exclusion).
   */
  beginRun(row: { id?: string; source_id: string; scope: string; started_at: string }): Promise<string>;
  finishRun(id: string, patch: RunPatch): Promise<void>;
}

export type LeaseResult =
  | { kind: 'acquired'; id: string }
  | { kind: 'skipped'; reason: 'running' | 'too_soon' | 'lost_race' };

export interface LeaseOptions {
  sourceId: string;
  scope: string;
  now: Date;
  /** A 'running' row older than this is a crashed run. Must exceed the longest run (the Worker budgets 12 min). Default 20 min. */
  ttlMs?: number;
  /** Minimum time between two runs, and the length of the slot that names a run. The Jobicy rule is one pass per hour. Default 60 min. */
  minIntervalMs?: number;
}

/** Rows closed by the lease itself say nothing about the source and must not throttle the next real run. */
const LEASE_CLASSES = new Set(['lost_lease', 'stale_lock']);

const t = (iso: string) => Date.parse(iso);

/**
 * Deterministic UUID (version 5 layout, SHA-256 based) for "this source, this slot". Same inputs, same id, on every instance.
 * A different source, slot length or slot gives a different id.
 */
export async function slotRunId(sourceId: string, nowMs: number, slotMs: number): Promise<string> {
  const slot = Math.floor(nowMs / slotMs);
  const bytes = new Uint8Array(
    await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`orbijob:sync-slot:${sourceId}:${slotMs}:${slot}`)),
  ).slice(0, 16);
  bytes[6] = (bytes[6]! & 0x0f) | 0x50;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export async function acquireLease(ledger: RunLedger, o: LeaseOptions): Promise<LeaseResult> {
  const ttl = o.ttlMs ?? 20 * 60_000;
  const minInterval = o.minIntervalMs ?? 60 * 60_000;
  const now = o.now.getTime();
  const nowIso = o.now.toISOString();

  const running = await ledger.runningRuns(o.sourceId);
  const live = running.filter((r) => now - t(r.started_at) < ttl);
  for (const stale of running.filter((r) => now - t(r.started_at) >= ttl)) {
    await ledger.finishRun(stale.id, { status: 'failed', finished_at: nowIso, error_class: 'stale_lock' }).catch(() => {});
  }
  if (live.length) return { kind: 'skipped', reason: 'running' };

  // `+ 1`: a run that started exactly one interval ago is no longer "within the interval" (it is the previous slot)
  const recent = (await ledger.finishedSince(o.sourceId, new Date(now - minInterval + 1).toISOString()))
    .filter((r) => !LEASE_CLASSES.has(r.error_class ?? ''));
  if (recent.length) return { kind: 'skipped', reason: 'too_soon' };

  // The decision: one atomic insert of a run whose id is the same for every contender of this slot.
  try {
    const id = await ledger.beginRun({ id: await slotRunId(o.sourceId, now, minInterval), source_id: o.sourceId, scope: o.scope, started_at: nowIso });
    return { kind: 'acquired', id };
  } catch (e) {
    if (e instanceof RunConflict) return { kind: 'skipped', reason: 'lost_race' };
    throw e;
  }
}
