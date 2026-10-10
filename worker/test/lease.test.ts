import { describe, expect, it } from 'vitest';
import { acquireLease, type RunLedger, type RunPatch, type RunRef } from '../src/lease';

/** A shared ledger with a scheduler tick on every call, so concurrent callers interleave like separate isolates. */
class MemoryLedger implements RunLedger {
  rows: (RunRef & { source_id: string; finished_at?: string })[] = [];
  private n = 0;
  private tick = () => new Promise<void>((r) => setTimeout(r, 0));
  async runningRuns(sourceId: string) { await this.tick(); return this.rows.filter((r) => r.source_id === sourceId && r.status === 'running'); }
  async finishedSince(sourceId: string, since: string) { await this.tick(); return this.rows.filter((r) => r.source_id === sourceId && r.status !== 'running' && Date.parse(r.started_at) >= Date.parse(since)); }
  async beginRun(row: { source_id: string; scope: string; started_at: string }) {
    await this.tick();
    const id = `id-${String(++this.n).padStart(3, '0')}`;
    this.rows.push({ id, source_id: row.source_id, status: 'running', started_at: row.started_at, error_class: null });
    return id;
  }
  async finishRun(id: string, patch: RunPatch) { await this.tick(); Object.assign(this.rows.find((r) => r.id === id)!, patch); }
}

const T0 = new Date('2026-10-10T12:00:00.000Z');
const at = (min: number) => new Date(T0.getTime() + min * 60_000);
const opts = (now: Date) => ({ sourceId: 'jobicy', scope: '', now });

describe('acquireLease', () => {
  it('the first run gets the lease and leaves a running row', async () => {
    const l = new MemoryLedger();
    const r = await acquireLease(l, opts(T0));
    expect(r.kind).toBe('acquired');
    expect(l.rows).toHaveLength(1);
    expect(l.rows[0]).toMatchObject({ status: 'running', started_at: T0.toISOString() });
  });

  it('a run that is still within its time budget blocks the next one', async () => {
    const l = new MemoryLedger();
    await acquireLease(l, opts(T0));
    expect(await acquireLease(l, opts(at(5)))).toEqual({ kind: 'skipped', reason: 'running' });
    expect(l.rows).toHaveLength(1); // the skipped run wrote nothing
  });

  it('two simultaneous runs: exactly one proceeds, the other steps aside and closes its own row', async () => {
    const l = new MemoryLedger();
    const results = await Promise.all([acquireLease(l, opts(T0)), acquireLease(l, opts(T0)), acquireLease(l, opts(T0))]);
    expect(results.filter((r) => r.kind === 'acquired')).toHaveLength(1);
    expect(results.filter((r) => r.kind === 'skipped')).toHaveLength(2);
    expect(l.rows.filter((r) => r.status === 'running')).toHaveLength(1);
    expect(l.rows.filter((r) => r.error_class === 'lost_lease')).toHaveLength(2);
    const winner = results.find((r) => r.kind === 'acquired') as { id: string };
    expect(l.rows.find((r) => r.id === winner.id)!.status).toBe('running');
  });

  it('a finished run throttles the next one for the source\'s minimum interval, then lets it through', async () => {
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

  it('rows closed by the lease itself (lost race, stale lock) never throttle a real run', async () => {
    const l = new MemoryLedger();
    l.rows.push({ id: 'x1', source_id: 'jobicy', status: 'failed', started_at: at(-5).toISOString(), error_class: 'lost_lease' });
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

  it('other sources are independent', async () => {
    const l = new MemoryLedger();
    await acquireLease(l, { sourceId: 'jobicy', scope: '', now: T0 });
    expect((await acquireLease(l, { sourceId: 'lever', scope: '', now: T0 })).kind).toBe('acquired');
  });

  it('if the ledger cannot be read the error reaches the caller (no run without a lease)', async () => {
    const l = new MemoryLedger();
    l.runningRuns = async () => { throw new Error('down'); };
    await expect(acquireLease(l, opts(T0))).rejects.toThrow('down');
  });

  it('after a clean finish and the interval, the next cycle is a fresh lease (the 6-hour cron path)', async () => {
    const l = new MemoryLedger();
    for (const h of [0, 6, 12]) {
      const r = await acquireLease(l, opts(new Date(T0.getTime() + h * 3_600_000)));
      expect(r.kind).toBe('acquired');
      await l.finishRun((r as { id: string }).id, { status: 'ok' });
    }
    expect(l.rows).toHaveLength(3);
  });
});
