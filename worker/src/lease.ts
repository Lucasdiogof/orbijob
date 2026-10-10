/**
 * Exclusive run of one source across Worker instances.
 *
 * Why not a global variable: a Worker runs in many isolates, in many places, and Cloudflare documents no exactly-once
 * delivery for Cron Triggers nor anything about overlapping runs. A module-level flag only protects one isolate.
 *
 * What this does instead, with tables that already exist (`sync_runs.status` allows 'running'; migration 6 gives the
 * service role select/insert/update on it), so NO database change is needed:
 *   1. a run still 'running' and younger than the TTL means somebody else is working: skip;
 *   2. a run that finished less than `minIntervalMs` ago means the source's "one pass per hour" rule would be broken: skip;
 *   3. otherwise insert our own 'running' row, then read the rows again: if an OLDER running row exists, we lost the race
 *      and step aside (the oldest row, ties broken by id, wins).
 *   4. 'running' rows older than the TTL belong to a crashed run: they are closed as failed (`stale_lock`).
 *
 * This is an optimistic lease, not a lock: two instances inserting at the very same instant with skewed clocks could both
 * proceed. That is harmless for correctness (every write is an upsert on a unique key, and a job is only closed on the
 * source's own evidence) and the only cost is one extra request to the source. A hard guarantee needs a unique partial
 * index on sync_runs(source_id) where status = 'running' (a migration) or a Durable Object; see docs/JOBICY_WORKER.md.
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

export interface RunLedger {
  /** Runs of the source with status 'running', of any age. */
  runningRuns(sourceId: string): Promise<RunRef[]>;
  /** Runs of the source that are not 'running' and started at or after [sinceIso]. */
  finishedSince(sourceId: string, sinceIso: string): Promise<RunRef[]>;
  /** Inserts a 'running' row and returns its id. */
  beginRun(row: { source_id: string; scope: string; started_at: string }): Promise<string>;
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
  /** Minimum time between two runs. The Jobicy rule is one pass per hour. Default 60 min. */
  minIntervalMs?: number;
  /**
   * Pause between the first and the second verification (default 1 s). A freshly inserted row is not instantly visible to a
   * concurrent reader, so one check can miss an older rival; after the pause both rivals see the same rows and exactly one
   * of them is the oldest. 0 disables the second check.
   */
  settleMs?: number;
  sleep?: (ms: number) => Promise<void>;
}

/** Rows closed by the lease itself say nothing about the source and must not throttle the next real run. */
const LEASE_CLASSES = new Set(['lost_lease', 'stale_lock']);

const t = (iso: string) => Date.parse(iso);
/** Older first; equal times are ordered by id so exactly one of two simultaneous rows is "first". */
const before = (a: RunRef, b: RunRef) => t(a.started_at) < t(b.started_at) || (t(a.started_at) === t(b.started_at) && a.id < b.id);

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

  const recent = (await ledger.finishedSince(o.sourceId, new Date(now - minInterval).toISOString()))
    .filter((r) => !LEASE_CLASSES.has(r.error_class ?? ''));
  if (recent.length) return { kind: 'skipped', reason: 'too_soon' };

  const id = await ledger.beginRun({ source_id: o.sourceId, scope: o.scope, started_at: nowIso });

  // Verify, twice: did anyone older start in the meantime? The second look comes after a pause because a row inserted a
  // moment ago by a rival may not be visible yet; with a clock tie (or a few ms of skew) both could otherwise pass.
  const stillFirst = async () => {
    const after = (await ledger.runningRuns(o.sourceId)).filter((r) => now - t(r.started_at) < ttl);
    const mine = after.find((r) => r.id === id);
    return !!mine && !after.some((r) => r.id !== id && before(r, mine));
  };
  const settle = o.settleMs ?? 1000;
  const wait = o.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  if (!(await stillFirst()) || (settle > 0 && (await wait(settle), !(await stillFirst())))) {
    await ledger.finishRun(id, { status: 'failed', finished_at: nowIso, error_class: 'lost_lease' }).catch(() => {});
    return { kind: 'skipped', reason: 'lost_race' };
  }
  return { kind: 'acquired', id };
}
