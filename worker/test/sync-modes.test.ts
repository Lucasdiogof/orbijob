import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { verificationState } from '../src/freshness';
import { runScheduledSync } from '../src/scheduled';
import { FEED_JOBS, World, storedJob } from './helpers/world';

// Two explicit ways to run the same Worker: SYNC_MODE=revalidate (only the stored jobs are asked about, nothing is imported) and the
// full pass, whose growth of the catalogue can be capped with SYNC_MAX_NEW_JOBS. Real store, lease and runSync over the in-memory world.

const OLD = '2026-10-01T00:00:00.000Z';
const seed = (w: World, ids: string[], lastChecked = OLD) => {
  for (const id of ids) w.jobs.set(`jobicy:${id}`, { ...storedJob(id), last_checked_at: lastChecked });
};
const run = (w: World, over: Record<string, string> = {}) => runScheduledSync(w.env(over), w.deps());
const row = (w: World, id: string) => w.jobs.get(`jobicy:${id}`) as { status: string; last_checked_at: string };
const nextCycle = (w: World, hours = 6) => { w.clock = new Date(w.clock.getTime() + hours * 3_600_000); };
const neverDeletes = (w: World) => expect(w.requests.filter((r) => r.method === 'DELETE')).toEqual([]);

describe('SYNC_MODE=revalidate: only the stored jobs are asked about, nothing is imported', () => {
  const revalidate = (w: World, over: Record<string, string> = {}) => run(w, { SYNC_MODE: 'revalidate', ...over });
  const noFeed = (w: World) => { w.jobicyFault = () => { throw new Error('the feed must not be touched in revalidate mode'); }; };

  it('never reads the feed and never writes a new job; closes the confirmed closed and stamps the confirmed open', async () => {
    const w = new World(); noFeed(w);
    seed(w, ['111', '222', '333']); w.statuses['111'] = 'closed'; w.statuses['222'] = 'active'; w.statuses['333'] = 'unknown';
    const o = await revalidate(w);
    expect(o).toMatchObject({ status: 'ok', summary: { pages: 0, fetched: 0, upserted: 0, closed: 1, confirmed: 1, unverified: 1, runRecorded: true } });
    expect(w.calls.feed).toBe(0);
    expect(w.jobs.size).toBe(3);
    expect(['111', '222', '333'].map((id) => row(w, id).status)).toEqual(['closed', 'open', 'open']);
    expect(Date.parse(row(w, '222').last_checked_at)).toBeGreaterThan(Date.parse(OLD));
    expect(row(w, '333').last_checked_at).toBe(OLD);
    // no POST to jobs, no DELETE, no touch of job_sources or any user table
    expect(w.requests.filter((r) => r.table === 'jobs' && r.method === 'POST')).toEqual([]);
    expect(new Set(w.requests.map((r) => r.table))).toEqual(new Set(['sync_runs', 'jobs']));
    neverDeletes(w);
    expect(w.runs[0]).toMatchObject({ status: 'ok', scope: 'revalidate', fetched: 0, upserted: 0, closed: 1 });
  });

  it('revalidation AFTER expiry brings an expired job back to fresh; expiry itself never closed it', async () => {
    const w = new World(); noFeed(w);
    const stale = '2026-10-05T00:00:00.000Z';
    seed(w, ['222'], stale);
    expect(verificationState(stale, w.now())).toBe('expired');
    await revalidate(w);
    expect(verificationState(row(w, '222').last_checked_at, new Date())).toBe('fresh');
    expect(row(w, '222').status).toBe('open');
  });

  it('status endpoint down: nothing changes and the run is FAILED, not a silent success', async () => {
    const w = new World(); noFeed(w); seed(w, ['111']); w.statuses['111'] = 'closed';
    w.statusFault = () => new Response('{}', { status: 503 });
    const o = await revalidate(w);
    expect(o).toMatchObject({ status: 'failed', summary: { closed: 0, confirmed: 0, error_class: 'http_503', runRecorded: true } });
    expect(row(w, '111')).toMatchObject({ status: 'open', last_checked_at: OLD });
  });

  it('authentication error on the status step cannot happen silently: a wrong key stops at the lease, before any request to the source', async () => {
    const w = new World(); noFeed(w); seed(w, ['111']);
    await expect(run(w, { SYNC_MODE: 'revalidate', SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_WRONGKEYWRONGKEYWRONGKEY' })).rejects.toThrow(/auth/);
    expect(w.calls.status).toBe(0);
    expect(w.calls.feed).toBe(0);
  });

  it('timeout on a later batch: partial, the earlier batch stays proven', async () => {
    const w = new World(); noFeed(w); const ids = Array.from({ length: 150 }, (_, i) => String(1000 + i));
    seed(w, ids); for (const id of ids) w.statuses[id] = 'closed';
    w.statusFault = (n) => (n >= 1 ? Object.assign(new Error('timed out'), { name: 'TimeoutError' }) : null);
    const o = await revalidate(w);
    expect(o).toMatchObject({ status: 'partial', summary: { closed: 100, error_class: 'timeout' } });
    expect(ids.filter((id) => row(w, id).status === 'open')).toHaveLength(50);
  });

  it('repeated execution is safe and, one cycle later, changes nothing but the stamps', async () => {
    const w = new World(); noFeed(w); seed(w, ['111', '222']); w.statuses['111'] = 'closed';
    await revalidate(w);
    const snap = () => JSON.stringify([...w.jobs.entries()].map(([k, v]) => [k, { ...v, last_checked_at: undefined }]).sort());
    const first = snap();
    nextCycle(w);
    const o = await revalidate(w);
    expect(o).toMatchObject({ status: 'ok', summary: { closed: 0, confirmed: 1 } });
    expect(snap()).toBe(first);
    expect(w.runs.map((r) => r.status)).toEqual(['ok', 'ok']);
  });

  it('two revalidations at once: one runs, the other is skipped; the source is asked once', async () => {
    const w = new World(); noFeed(w); seed(w, ['111']); w.statuses['111'] = 'closed';
    const [a, b] = await Promise.all([revalidate(w), revalidate(w)]);
    expect([a.status, b.status].sort()).toEqual(['ok', 'skipped']);
    expect(w.calls.status).toBe(1);
  });

  it('a revalidation right after a full pass (or the other way round) is held back by the one-pass-per-hour rule', async () => {
    const w = new World(); seed(w, ['111']);
    await run(w);
    const o = await revalidate(w);
    expect(o).toMatchObject({ status: 'skipped', reason: 'too_soon' });
  });

  it('with nothing stored it makes no status request at all', async () => {
    const w = new World(); noFeed(w);
    const o = await revalidate(w);
    expect(o.status).toBe('ok');
    expect(w.calls.status).toBe(0);
  });

  it('favourites and applications are untouched: no table other than jobs and sync_runs is used', async () => {
    const w = new World(); noFeed(w); seed(w, ['111']); w.statuses['111'] = 'closed';
    await revalidate(w);
    expect([...new Set(w.requests.map((r) => r.table))].sort()).toEqual(['jobs', 'sync_runs']);
  });

  it('the mode is explicit: an unknown value is a configuration error before any request; unset means the normal full pass', async () => {
    const w = new World();
    await expect(run(w, { SYNC_MODE: 'everything' })).rejects.toThrow(/SYNC_MODE/);
    expect(w.calls.supabase).toBe(0);
    const o = await run(new World());
    expect(o).toMatchObject({ status: 'ok', summary: { upserted: 10 } });
  });
});

describe('SYNC_MAX_NEW_JOBS: the catalogue grows only as fast as it is told to', () => {
  const full = (w: World, cap: string) => run(w, { SYNC_MAX_NEW_JOBS: cap });
  const ids = FEED_JOBS.map((j) => String(j.id));

  it('adds at most N jobs that are not stored yet; stored ones are still refreshed; the rest is reported, not lost', async () => {
    const w = new World(); seed(w, ids.slice(0, 3));
    const o = await full(w, '4');
    expect(o).toMatchObject({ status: 'ok', summary: { upserted: 7, skippedNew: 3 } });
    expect(w.jobs.size).toBe(7);
    expect(w.allLogs()).toContain('"skippedNew":3');
    nextCycle(w);
    await full(w, '4');
    expect(w.jobs.size).toBe(10);
  });

  it('a cap of 0 adds nothing and still refreshes, confirms and closes what is stored', async () => {
    const w = new World(); seed(w, [ids[0]!, '111', '222']); w.statuses['111'] = 'closed';
    const o = await full(w, '0');
    expect(o).toMatchObject({ status: 'ok', summary: { upserted: 1, skippedNew: 9, closed: 1, confirmed: 1 } });
    expect(w.jobs.size).toBe(3);
  });

  it('no cap set: the normal pass is unchanged', async () => {
    const o = await run(new World());
    expect(o).toMatchObject({ summary: { upserted: 10, skippedNew: 0 } });
  });

  it('if the stored ids cannot be read, nothing is added (the cap cannot be honoured)', async () => {
    const w = new World();
    const orig = w.fetch;
    w.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
      const u = new URL(String(input));
      if (u.hostname === 'example.supabase.co' && u.pathname.endsWith('/jobs') && (init?.method ?? 'GET') === 'GET') return new Response('{}', { status: 500 });
      return orig(input, init);
    }) as typeof fetch;
    const o = await full(w, '5');
    expect(o.status).toBe('failed');
    expect(w.jobs.size).toBe(0);
  });

  it('an invalid cap is a configuration error', async () => {
    const w = new World();
    for (const bad of ['-1', '1.5', 'many', '10001']) await expect(full(w, bad)).rejects.toThrow(/SYNC_MAX_NEW_JOBS/);
  });
});

describe('the deployed configuration cannot widen the catalogue by accident', () => {
  const toml = readFileSync(new URL('../wrangler.toml', import.meta.url), 'utf8');
  it('wrangler.toml pins SYNC_MODE to revalidate and sets no cap that would suggest an import', () => {
    expect(toml).toMatch(/^\[vars\]\r?\nSYNC_MODE = "revalidate"/m);
    expect(toml).not.toMatch(/^SYNC_MODE = "full"/m);
    expect(toml).not.toMatch(/^SYNC_MAX_NEW_JOBS/m);
  });
});
