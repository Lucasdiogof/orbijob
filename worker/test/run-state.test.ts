import { describe, expect, it } from 'vitest';
import { runScheduledSync } from '../src/scheduled';
import { classifyDiscoverRun } from '../scripts/run-state.mjs';
import { evaluateHealth, worst } from '../scripts/ops-health-lib.mjs';
import { World, storedJob } from './helpers/world';

// 13.0: a source that reached its planned catalogue ceiling is HEALTHY (AT_CAPACITY, green run with a notice), never confused with a real failure,
// and a real failure in the same pass is never hidden by the full catalogue. Real runScheduledSync over the in-memory world, then the classifier.
const discover = (w: World, over: Record<string, string> = {}) => runScheduledSync(w.env({ SYNC_MODE: 'discover', ...over }), w.deps());
const nextCycle = (w: World, hours = 6) => { w.clock = new Date(w.clock.getTime() + hours * 3_600_000); };
const full = (w: World, n: number) => { for (let i = 0; i < n; i++) w.jobs.set(`jobicy:s${i}`, storedJob(`s${i}`)); };

describe('discovery pass states: SUCCESS, AT_CAPACITY, PARTIAL, FAILED', () => {
  it('a healthy source at its ceiling: the feed is read, nothing new is stored, the pass is AT_CAPACITY with exit code 0', async () => {
    const w = new World();
    full(w, 3);
    const o = await discover(w, { SYNC_MAX_CATALOGUE: '3' });
    expect(o).toMatchObject({ status: 'partial', summary: { upserted: 0, error_class: 'catalogue_full' } });
    expect(w.calls.feed).toBeGreaterThan(0);
    expect(w.jobs.size).toBe(3); // the ceiling still holds
    expect(classifyDiscoverRun({ outcome: o })).toEqual({ state: 'AT_CAPACITY', code: 0, reason: 'catalogue_full' });
  });

  it('a real failure in a pass of a full source is never reported as capacity', async () => {
    const w = new World();
    full(w, 3);
    w.jobicyFault = (call) => (call >= 1 ? new Response('', { status: 503 }) : null); // the second feed page fails
    const o = await discover(w, { SYNC_MAX_CATALOGUE: '3' });
    const st = classifyDiscoverRun({ outcome: o });
    expect(st.state).not.toBe('AT_CAPACITY');
    expect(['FAILED', 'PARTIAL']).toContain(st.state);
    expect(st.code).not.toBe(0);
  });

  it('a full source whose feed answers nothing, or with HTTP errors, or whose verification fails, is not healthy', () => {
    const at = (summary: Record<string, unknown>) => ({ status: 'partial', summary: { error_class: 'catalogue_full', ...summary } });
    expect(classifyDiscoverRun({ outcome: at({ fetched: 0, http_errors: 0 }) })).toMatchObject({ state: 'FAILED', code: 1 });
    expect(classifyDiscoverRun({ outcome: at({ fetched: 40, http_errors: 2 }) })).toMatchObject({ state: 'PARTIAL', code: 6 });
    expect(classifyDiscoverRun({ outcome: at({ fetched: 40, http_errors: 0 }), problems: ['uma vaga existente mudou'] })).toMatchObject({ state: 'FAILED', code: 1 });
    expect(classifyDiscoverRun({ outcome: at({ fetched: 40, http_errors: 0 }) })).toMatchObject({ state: 'AT_CAPACITY', code: 0 });
  });

  it('capacity is recovered once listings expire: the next pass imports again and is SUCCESS', async () => {
    const w = new World();
    full(w, 3);
    expect(classifyDiscoverRun({ outcome: await discover(w, { SYNC_MAX_CATALOGUE: '3' }) }).state).toBe('AT_CAPACITY');
    // the regular expiry closes two listings and the retention empties their text: they no longer count against the ceiling
    for (const id of ['s0', 's1']) w.jobs.set(`jobicy:${id}`, { ...storedJob(id, 'closed'), description: '' });
    nextCycle(w);
    const o = await discover(w, { SYNC_MAX_CATALOGUE: '3', SYNC_MAX_NEW_JOBS: '1' }); // room for 2; one new listing per pass here
    expect(o.summary?.upserted).toBe(1);
    expect(classifyDiscoverRun({ outcome: o })).toMatchObject({ state: 'SUCCESS', code: 0 });
  });

  it('the other outcomes keep their meaning and exit codes', () => {
    expect(classifyDiscoverRun({ outcome: { status: 'ok', summary: { fetched: 10 } } })).toMatchObject({ state: 'SUCCESS', code: 0 });
    expect(classifyDiscoverRun({ outcome: { status: 'skipped' } })).toMatchObject({ state: 'SUCCESS', code: 0, reason: 'skipped' });
    expect(classifyDiscoverRun({ outcome: { status: 'partial', summary: { error_class: 'deadline' } } })).toMatchObject({ state: 'PARTIAL', code: 6 });
    expect(classifyDiscoverRun({ outcome: { status: 'failed', summary: { error_class: 'http_5xx' } } })).toMatchObject({ state: 'FAILED', code: 1 });
    expect(classifyDiscoverRun({ crash: 'auth' })).toMatchObject({ state: 'FAILED', code: 4 });
    expect(classifyDiscoverRun({ crash: 'unreachable' })).toMatchObject({ state: 'FAILED', code: 5 });
    expect(classifyDiscoverRun({})).toMatchObject({ state: 'FAILED', code: 1 });
  });
});

describe('ops-health keeps a planned ceiling apart from real problems', () => {
  const now = new Date('2026-10-16T12:00:00Z');
  const ago = (h: number) => new Date(now.getTime() - h * 3_600_000).toISOString();
  const input = (newest: string, runs: { status: string; error_class: string | null }[]) => ({
    now, sources: [{ id: 'mpsvcz', can_redistribute: true }], newestChecked: { mpsvcz: newest }, visibleJobs: 25_000,
    runs24h: runs.map((r) => ({ source_id: 'mpsvcz', scope: 'discover', started_at: ago(2), ...r })),
  });

  it('a fresh source at its ceiling is AT_CAPACITY and the overall status stays OK', () => {
    const rows = evaluateHealth(input(ago(1), [{ status: 'partial', error_class: 'catalogue_full' }, { status: 'partial', error_class: 'catalogue_full' }]));
    expect(rows.find((r) => r.check === 'source_ceiling:mpsvcz')?.status).toBe('AT_CAPACITY');
    expect(rows.find((r) => r.check === 'source_runs:mpsvcz')).toBeUndefined();
    expect(worst(rows)).toBe('OK');
  });

  it('a full source that stopped refreshing, or that also failed, still raises WARN/ALERT', () => {
    expect(worst(evaluateHealth(input(ago(40), [{ status: 'partial', error_class: 'catalogue_full' }])))).toBe('ALERT');
    const rows = evaluateHealth(input(ago(1), [{ status: 'partial', error_class: 'catalogue_full' }, { status: 'failed', error_class: 'http_5xx' }]));
    expect(rows.find((r) => r.check === 'source_runs:mpsvcz')?.status).toBe('WARN');
    expect(worst(rows)).toBe('WARN');
  });
});
