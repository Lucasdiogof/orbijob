import { describe, expect, it } from 'vitest';
import { RunConflict, acquireLease, slotRunId, type RunLedger, type RunPatch, type RunRef } from '../src/lease';

/**
 * IN-MEMORY model of the ledger. Its beginRun enforces the primary key the way PostgreSQL does (an existing id is refused),
 * and every call yields to the scheduler (with optional random delays) so concurrent callers interleave like separate
 * isolates. What this proves is the LOGIC around the atomic insert; that PostgreSQL really refuses the duplicate through
 * PostgREST is proven by the live tests (test/live/*), which run in CI against a real PostgREST.
 */
type Row = RunRef & { source_id: string; finished_at?: string };

class MemoryLedger implements RunLedger {
  rows: Row[] = [];
  private n = 0;
  constructor(private delay: () => number = () => 0) {}
  private tick = () => new Promise<void>((r) => setTimeout(r, this.delay()));
  async runningRuns(sourceId: string) { await this.tick(); return this.rows.filter((r) => r.source_id === sourceId && r.status === 'running').map((r) => ({ ...r })); }
  async finishedSince(sourceId: string, since: string) { await this.tick(); return this.rows.filter((r) => r.source_id === sourceId && r.status !== 'running' && Date.parse(r.started_at) >= Date.parse(since)).map((r) => ({ ...r })); }
  async beginRun(row: { id?: string; source_id: string; scope: string; started_at: string }) {
    await this.tick(); // the request travels...
    const id = row.id ?? `gen-${++this.n}`;
    if (this.rows.some((r) => r.id === id)) throw new RunConflict(); // ...and the primary key decides, atomically, in one step
    this.rows.push({ id, source_id: row.source_id, status: 'running', started_at: row.started_at, error_class: null });
    return id;
  }
  async finishRun(id: string, patch: RunPatch) { await this.tick(); Object.assign(this.rows.find((r) => r.id === id)!, patch); }
}

const T0 = new Date('2026-10-10T12:00:00.000Z');
const at = (min: number) => new Date(T0.getTime() + min * 60_000);
const opts = (now: Date) => ({ sourceId: 'jobicy', scope: '', now });

/** Small seeded PRNG so a "random" run is reproducible when it fails. */
const prng = (seed: number) => () => { seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };

describe('slotRunId', () => {
  it('is the same on every instance for the same source and slot, whatever the time inside the slot', async () => {
    const a = await slotRunId('jobicy', T0.getTime(), 3_600_000);
    expect(await slotRunId('jobicy', T0.getTime() + 59 * 60_000 + 59_000, 3_600_000)).toBe(a);
    expect(await slotRunId('jobicy', T0.getTime(), 3_600_000)).toBe(a);
  });
  it('changes with the slot, the source and the slot length', async () => {
    const base = await slotRunId('jobicy', T0.getTime(), 3_600_000);
    expect(await slotRunId('jobicy', T0.getTime() + 3_600_000, 3_600_000)).not.toBe(base);
    expect(await slotRunId('lever', T0.getTime(), 3_600_000)).not.toBe(base);
    expect(await slotRunId('jobicy', T0.getTime(), 1_800_000)).not.toBe(base);
  });
  it('is a valid version-5 UUID that PostgreSQL will accept as a uuid key', async () => {
    expect(await slotRunId('jobicy', T0.getTime(), 3_600_000)).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  });
});

describe('acquireLease', () => {
  it('the first run gets the lease; its row is named by the slot, so every instance would compute the same id', async () => {
    const l = new MemoryLedger();
    const r = await acquireLease(l, opts(T0));
    expect(r).toEqual({ kind: 'acquired', id: await slotRunId('jobicy', T0.getTime(), 3_600_000) });
    expect(l.rows).toHaveLength(1);
    expect(l.rows[0]).toMatchObject({ status: 'running', started_at: T0.toISOString() });
  });

  it('a run that is still within its time budget blocks the next one, which writes nothing', async () => {
    const l = new MemoryLedger();
    await acquireLease(l, opts(T0));
    expect(await acquireLease(l, opts(at(5)))).toEqual({ kind: 'skipped', reason: 'running' });
    expect(l.rows).toHaveLength(1);
  });

  it.each([2, 3, 10])('%i simultaneous runs: exactly one proceeds; the others write NOTHING', async (n) => {
    const l = new MemoryLedger();
    const results = await Promise.all(Array.from({ length: n }, () => acquireLease(l, opts(T0))));
    expect(results.filter((r) => r.kind === 'acquired')).toHaveLength(1);
    expect(results.filter((r) => r.kind === 'skipped')).toHaveLength(n - 1);
    expect(l.rows).toHaveLength(1); // the losers were refused by the key: no row to clean up, nothing left "running" by them
    expect(l.rows[0]!.status).toBe('running');
  });

  it('the refusal by the key is reported as lost_race (not as an error), and the losers did not even need to see each other', async () => {
    const l = new MemoryLedger();
    // both pass the cheap checks before either inserts: only the key can separate them
    const res = await Promise.all([acquireLease(l, opts(T0)), acquireLease(l, opts(T0))]);
    const reasons = res.filter((r) => r.kind === 'skipped').map((r) => (r as { reason: string }).reason);
    expect(reasons).toHaveLength(1);
    expect(['lost_race', 'running']).toContain(reasons[0]);
  });

  it('PROPERTY: 150 rounds of 2-10 contenders with random per-request latency always give exactly one winner', async () => {
    const rnd = prng(20261010);
    for (let round = 0; round < 150; round++) {
      const n = 2 + Math.floor(rnd() * 9);
      const l = new MemoryLedger(() => Math.floor(rnd() * 3)); // 0-2 ms before each request lands
      const res = await Promise.all(Array.from({ length: n }, async () => {
        await new Promise((r) => setTimeout(r, Math.floor(rnd() * 3))); // contenders do not start at the same instant either
        return acquireLease(l, opts(T0));
      }));
      const winners = res.filter((r) => r.kind === 'acquired').length;
      if (winners !== 1) throw new Error(`round ${round}: ${winners} winners among ${n}`);
      expect(l.rows).toHaveLength(1);
    }
  }, 60_000);

  it('a finished run throttles the next one for the source\'s minimum interval, then lets it through (next slot)', async () => {
    const l = new MemoryLedger();
    const first = (await acquireLease(l, opts(T0))) as { id: string };
    await l.finishRun(first.id, { status: 'ok' });
    expect(await acquireLease(l, opts(at(30)))).toEqual({ kind: 'skipped', reason: 'too_soon' });
    expect((await acquireLease(l, opts(at(61)))).kind).toBe('acquired');
  });

  it('a failed run also counts: do not hammer a source that just refused us', async () => {
    const l = new MemoryLedger();
    const first = (await acquireLease(l, opts(T0))) as { id: string };
    await l.finishRun(first.id, { status: 'failed', error_class: 'http_429' });
    expect(await acquireLease(l, opts(at(10)))).toEqual({ kind: 'skipped', reason: 'too_soon' });
  });

  it('recovery after a failure: the next hour is a fresh slot and a fresh run', async () => {
    const l = new MemoryLedger();
    const first = (await acquireLease(l, opts(T0))) as { id: string };
    await l.finishRun(first.id, { status: 'failed', error_class: 'http_500' });
    const next = await acquireLease(l, opts(at(60)));
    expect(next.kind).toBe('acquired');
    expect((next as { id: string }).id).not.toBe(first.id);
  });

  it('rows closed by the lease itself (stale lock) never throttle a real run in another slot', async () => {
    const l = new MemoryLedger();
    l.rows.push({ id: 'x2', source_id: 'jobicy', status: 'failed', started_at: at(-6).toISOString(), error_class: 'stale_lock' });
    expect((await acquireLease(l, opts(T0))).kind).toBe('acquired');
  });

  it('a crashed run (running past the TTL) is closed as stale and does not block forever', async () => {
    const l = new MemoryLedger();
    l.rows.push({ id: 'old', source_id: 'jobicy', status: 'running', started_at: at(-45).toISOString(), error_class: null });
    const r = await acquireLease(l, opts(T0));
    expect(r.kind).toBe('acquired');
    expect(l.rows.find((x) => x.id === 'old')).toMatchObject({ status: 'failed', error_class: 'stale_lock' });
  });

  it('a crashed run keeps ITS slot: a retry inside the same hour is refused by the key; the next hour proceeds', async () => {
    const l = new MemoryLedger();
    const crashed = await slotRunId('jobicy', T0.getTime(), 3_600_000);
    l.rows.push({ id: crashed, source_id: 'jobicy', status: 'running', started_at: at(-5).toISOString(), error_class: null });
    // 25 minutes later the crashed row is past its TTL: it is cleaned, but the slot id is taken
    expect(await acquireLease(l, opts(at(20)))).toEqual({ kind: 'skipped', reason: 'lost_race' });
    expect(l.rows.find((x) => x.id === crashed)).toMatchObject({ status: 'failed', error_class: 'stale_lock' });
    expect((await acquireLease(l, opts(at(61)))).kind).toBe('acquired');
  });

  it('another source is independent', async () => {
    const l = new MemoryLedger();
    await acquireLease(l, { sourceId: 'jobicy', scope: '', now: T0 });
    expect((await acquireLease(l, { sourceId: 'lever', scope: '', now: T0 })).kind).toBe('acquired');
  });

  it('errors other than the key refusing the insert are NOT swallowed as "someone else got it"', async () => {
    const l = new MemoryLedger();
    l.beginRun = async () => { throw new Error('database unavailable'); };
    await expect(acquireLease(l, opts(T0))).rejects.toThrow('database unavailable');
  });

  it('if the ledger cannot be read the error reaches the caller (no run without a lease)', async () => {
    const l = new MemoryLedger();
    l.runningRuns = async () => { throw new Error('down'); };
    await expect(acquireLease(l, opts(T0))).rejects.toThrow('down');
  });

  it('the 6-hour cron path: each delivery is its own slot, one run per delivery', async () => {
    const l = new MemoryLedger();
    for (const h of [0, 6, 12, 18]) {
      const r = await acquireLease(l, opts(new Date(T0.getTime() + h * 3_600_000)));
      expect(r.kind).toBe('acquired');
      await l.finishRun((r as { id: string }).id, { status: 'ok' });
    }
    expect(l.rows).toHaveLength(4);
    expect(new Set(l.rows.map((r) => r.id)).size).toBe(4);
  });

  it('a duplicate delivery of the SAME cron tick (same minute) is stopped, whether or not the first has finished', async () => {
    const l = new MemoryLedger();
    const a = (await acquireLease(l, opts(T0))) as { id: string };
    expect((await acquireLease(l, opts(new Date(T0.getTime() + 2000)))).kind).toBe('skipped'); // first still running
    await l.finishRun(a.id, { status: 'ok' });
    expect(await acquireLease(l, opts(new Date(T0.getTime() + 4000)))).toEqual({ kind: 'skipped', reason: 'too_soon' });
    expect(l.rows).toHaveLength(1);
  });
});
