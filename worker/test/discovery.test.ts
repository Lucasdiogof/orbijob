import { describe, expect, it } from 'vitest';
import { DISCOVER_DEFAULT_CAP, DISCOVER_DEFAULT_CATALOGUE, loadConfig } from '../src/env';
import { runScheduledSync } from '../src/scheduled';
import { FEED_JOBS, World, storedJob } from './helpers/world';

// SYNC_MODE=discover: the incremental import of NEW listings. Real store, lease and runSync over the in-memory world (Supabase REST + Jobicy).
// Its promises: only INSERTs of ids not stored yet; a stored row is never updated, re-opened, closed or blanked; only listings the status
// endpoint confirms active are imported; one pass per hour shared with the revalidation; every failure leaves the catalogue as it was.

const FEED_IDS = FEED_JOBS.map((j) => String(j.id));
const discover = (w: World, over: Record<string, string> = {}) => runScheduledSync(w.env({ SYNC_MODE: 'discover', ...over }), w.deps());
const nextCycle = (w: World, hours = 6) => { w.clock = new Date(w.clock.getTime() + hours * 3_600_000); };
const stored = (w: World, id: string) => w.jobs.get(`jobicy:${id}`) as Record<string, unknown> | undefined;
const snapshot = (w: World) => JSON.stringify([...w.jobs.entries()].sort());

describe('SYNC_MODE=discover: what it imports', () => {
  it('adds the listings that are not stored, with the Jobicy URL, source and a fresh verification date; asks the status endpoint first', async () => {
    const w = new World();
    const o = await discover(w);
    expect(o).toMatchObject({ status: 'ok', summary: { fetched: 10, upserted: 10, alreadyKnown: 0, duplicates: 0, inactive: 0, closed: 0, runRecorded: true } });
    expect([...w.jobs.keys()].sort()).toEqual(FEED_IDS.map((id) => `jobicy:${id}`).sort());
    for (const j of w.jobs.values()) {
      expect(j).toMatchObject({ source_id: 'jobicy', status: 'open', last_checked_at: w.clock.toISOString() });
      expect(new URL(String(j.original_url)).hostname).toBe('jobicy.com');
      expect(j.apply_url).toBe(j.original_url);
    }
    expect(w.calls.status).toBe(2); // one status request per page of new listings, before the insert
    expect(w.runs[0]).toMatchObject({ status: 'ok', scope: 'discover', fetched: 10, upserted: 10, duplicates: 0, closed: 0, error_class: null });
  });

  it('is insert-only: every write to jobs asks to ignore duplicates; no PATCH, no DELETE, no other table', async () => {
    const w = new World();
    await discover(w);
    expect(w.jobPosts.length).toBeGreaterThan(0);
    expect(w.jobPosts.every((p) => p.ignoreDuplicates)).toBe(true);
    expect(w.requests.filter((r) => r.method === 'PATCH' && r.table === 'jobs')).toEqual([]);
    expect(w.requests.filter((r) => r.method === 'DELETE')).toEqual([]);
    expect(new Set(w.requests.map((r) => r.table))).toEqual(new Set(['sync_runs', 'jobs']));
  });

  it('does not touch a stored job, even when the feed carries different (or empty) data for it', async () => {
    const w = new World();
    const rich = { ...storedJob('154956'), company: 'Juniper Square', title: 'Account Executive, Private Equity', description: 'A long, reviewed description.', salary_min: 120000, last_checked_at: '2026-10-09T00:00:00.000Z' };
    w.jobs.set('jobicy:154956', rich);
    const before = JSON.stringify(rich);
    const o = await discover(w);
    expect(o).toMatchObject({ status: 'ok', summary: { upserted: 9, alreadyKnown: 1 } });
    expect(JSON.stringify(stored(w, '154956'))).toBe(before);
    expect(w.runs[0]).toMatchObject({ upserted: 9, duplicates: 1 }); // "duplicates" counts what was ignored because it was already there
  });

  it('never re-opens a closed job: a closed id that is still in the feed stays closed and is not asked about', async () => {
    const w = new World();
    w.jobs.set('jobicy:154950', { ...storedJob('154950', 'closed') });
    await discover(w);
    expect(stored(w, '154950')?.status).toBe('closed');
    expect(w.jobs.size).toBe(10);
  });

  it('imports nothing the source does not confirm active (closed, unknown or no answer) and says so; the next pass asks again', async () => {
    const w = new World();
    w.statuses['154956'] = 'closed'; w.statuses['154950'] = 'unknown'; w.statusSilent.add('154943');
    const o = await discover(w);
    expect(o).toMatchObject({ status: 'ok', summary: { fetched: 10, upserted: 7, inactive: 3 } });
    for (const id of ['154956', '154950', '154943']) expect(stored(w, id)).toBeUndefined();
    w.statuses['154950'] = 'active'; w.statusSilent.clear();
    nextCycle(w);
    const again = await discover(w);
    expect(again).toMatchObject({ status: 'ok', summary: { upserted: 2, alreadyKnown: 7, inactive: 1 } }); // 154956 is still closed
    expect(stored(w, '154950')).toBeDefined();
    expect(stored(w, '154956')).toBeUndefined();
  });

  it('is idempotent: the next pass finds everything known and writes nothing; the stored rows are byte-identical', async () => {
    const w = new World();
    await discover(w);
    const first = snapshot(w);
    nextCycle(w);
    const postsBefore = w.jobPosts.length;
    const o = await discover(w);
    expect(o).toMatchObject({ status: 'ok', summary: { upserted: 0, alreadyKnown: 10, inactive: 0 } });
    expect(snapshot(w)).toBe(first);
    expect(w.jobPosts.length).toBe(postsBefore); // no insert request at all
    expect(w.runs.map((r) => r.status)).toEqual(['ok', 'ok']);
  });

  it('does not import a duplicate listing of a LIVE stored job (same company, title and country under another id) but does after the old one closed', async () => {
    const dup = () => ({ ...storedJob('900001'), fingerprint: 'juniper square|account executive private equity|US|' });
    const live = new World();
    live.jobs.set('jobicy:900001', dup());
    const a = await discover(live);
    expect(a).toMatchObject({ status: 'ok', summary: { upserted: 9, duplicates: 1 } });
    expect(stored(live, '154956')).toBeUndefined();

    const closed = new World();
    closed.jobs.set('jobicy:900001', { ...dup(), status: 'closed' });
    const b = await discover(closed);
    expect(b).toMatchObject({ status: 'ok', summary: { upserted: 10, duplicates: 0 } });
    expect(stored(closed, '154956')).toBeDefined();
  });

  it('rejects malformed records without stopping the pass and counts them', async () => {
    const w = new World();
    w.feedPages = [[...FEED_JOBS.slice(0, 3), { id: 'x', jobTitle: 'no valid id' }, { id: 5, jobTitle: 'bad url', url: 'https://evil.example/5' }, 42 as never], FEED_JOBS.slice(3)];
    const o = await discover(w);
    expect(o).toMatchObject({ status: 'ok', summary: { rejected: 3, upserted: 10 } });
    expect(w.jobs.size).toBe(10);
  });
});

describe('SYNC_MODE=discover: limits', () => {
  it('SYNC_MAX_NEW_JOBS caps the pass; the rest waits for the next one', async () => {
    const w = new World();
    const o = await discover(w, { SYNC_MAX_NEW_JOBS: '4' });
    expect(o).toMatchObject({ status: 'ok', summary: { upserted: 4, skippedNew: 6 } });
    expect(w.jobs.size).toBe(4);
    nextCycle(w);
    const o2 = await discover(w, { SYNC_MAX_NEW_JOBS: '4' });
    expect(o2).toMatchObject({ summary: { upserted: 4, alreadyKnown: 4, skippedNew: 2 } });
    expect(w.jobs.size).toBe(8);
  });

  it('without SYNC_MAX_NEW_JOBS the pass is capped anyway (a safe default), and the other modes stay uncapped', () => {
    expect(loadConfig({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_' + 'A'.repeat(30), SYNC_MODE: 'discover' }).maxNewJobs).toBe(DISCOVER_DEFAULT_CAP);
    expect(loadConfig({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_' + 'A'.repeat(30), SYNC_MODE: 'discover', SYNC_MAX_NEW_JOBS: '7' }).maxNewJobs).toBe(7);
    expect(loadConfig({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_' + 'A'.repeat(30), SYNC_MODE: 'full' }).maxNewJobs).toBeUndefined();
    expect(() => loadConfig({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_' + 'A'.repeat(30), SYNC_MODE: 'import' })).toThrow(/discover/);
  });

  it('a second pass within the hour is adjourned by the lease; the source is not asked', async () => {
    const w = new World();
    await discover(w);
    const feedCalls = w.calls.feed;
    const o = await discover(w);
    expect(o).toEqual({ status: 'skipped', reason: 'too_soon' });
    expect(w.calls.feed).toBe(feedCalls);
  });

  it('two discoveries at once: one runs, the other is skipped; the feed is read once', async () => {
    const w = new World();
    const [a, b] = await Promise.all([discover(w), discover(w)]);
    expect([a.status, b.status].sort()).toEqual(['ok', 'skipped']);
    expect(w.calls.feed).toBe(2); // the two pages of the single winner
    expect(w.jobs.size).toBe(10);
  });

  it('shares the one-pass-per-hour lease with the revalidation, in both directions', async () => {
    const w = new World();
    await discover(w);
    const r = await runScheduledSync(w.env({ SYNC_MODE: 'revalidate' }), w.deps());
    expect(r).toEqual({ status: 'skipped', reason: 'too_soon' });
    nextCycle(w, 3);
    const r2 = await runScheduledSync(w.env({ SYNC_MODE: 'revalidate' }), w.deps());
    expect(r2.status).toBe('ok');
    nextCycle(w, 0.5);
    expect(await discover(w)).toEqual({ status: 'skipped', reason: 'too_soon' });
  });
});

describe('SYNC_MODE=discover: failures leave the catalogue as it was', () => {
  it('the feed answering HTTP 500 on the first page: failed, nothing written', async () => {
    const w = new World();
    w.jobicyFault = () => new Response('{}', { status: 500 });
    const o = await discover(w);
    expect(o).toMatchObject({ status: 'failed', summary: { upserted: 0, error_class: 'http_500', runRecorded: true } });
    expect(w.jobs.size).toBe(0);
    expect(w.jobPosts).toEqual([]);
  });

  it('the feed failing on the second page: partial, the first page stays, nothing is closed or updated', async () => {
    const w = new World();
    w.jobicyFault = (n) => (n >= 1 ? new Response('{}', { status: 503 }) : null);
    const o = await discover(w);
    expect(o).toMatchObject({ status: 'partial', summary: { upserted: 5, error_class: 'http_503' } });
    expect(w.jobs.size).toBe(5);
  });

  it('an expired cursor (HTTP 400) restarts the traversal once; ids already inserted are simply known', async () => {
    const w = new World();
    w.jobicyFault = (n, cursor) => (cursor && n === 1 ? new Response('{}', { status: 400 }) : null);
    const o = await discover(w);
    expect(o).toMatchObject({ status: 'ok', summary: { restarted: true, upserted: 10 } });
    expect(w.jobs.size).toBe(10);
  });

  it('a malformed or unsuccessful response imports nothing', async () => {
    const w = new World();
    w.jobicyFault = () => new Response(JSON.stringify({ success: false, error: 'rate limited' }), { status: 200 });
    expect(await discover(w)).toMatchObject({ status: 'failed', summary: { upserted: 0 } });
    const w2 = new World();
    w2.jobicyFault = () => new Response('<html>not json</html>', { status: 200 });
    expect(await discover(w2)).toMatchObject({ status: 'failed', summary: { upserted: 0 } });
    expect(w.jobs.size + w2.jobs.size).toBe(0);
  });

  it('the status endpoint failing: the candidates of that page are NOT imported (never import without the confirmation)', async () => {
    const w = new World();
    w.statusFault = () => new Response('{}', { status: 503 });
    const o = await discover(w);
    expect(o).toMatchObject({ status: 'failed', summary: { upserted: 0, error_class: 'http_503' } });
    expect(w.jobs.size).toBe(0);
  });

  it('a timeout is classified as such, not as success', async () => {
    const w = new World();
    w.jobicyFault = () => Object.assign(new Error('timed out'), { name: 'TimeoutError' });
    expect(await discover(w)).toMatchObject({ status: 'failed', summary: { error_class: 'timeout' } });
  });

  it('cannot list what is stored: adds nothing (it could not tell new from known)', async () => {
    const w = new World();
    const real = w.fetch;
    w.fetch = async (input, init) => (String(input).includes('select=external_id,fingerprint') ? new Response('{}', { status: 500 }) : real(input, init));
    const o = await runScheduledSync(w.env({ SYNC_MODE: 'discover' }), { ...w.deps(), fetch: w.fetch });
    expect(o).toMatchObject({ status: 'failed', summary: { upserted: 0, error_class: 'http_500' } });
    expect(w.jobs.size).toBe(0);
    expect(w.calls.feed).toBe(0);
  });

  it('a writer that inserts the same id between the listing and the insert is not overwritten; the pass counts it as already known', async () => {
    const w = new World();
    const racer = { ...storedJob('154956'), description: 'written by someone else first' };
    w.statusFault = (n) => { if (n === 0) w.jobs.set('jobicy:154956', racer); return null; };
    const o = await discover(w);
    expect(o).toMatchObject({ status: 'ok', summary: { upserted: 9, alreadyKnown: 1 } });
    expect(stored(w, '154956')?.description).toBe('written by someone else first');
  });

  it('stops by itself at the deadline and says partial', async () => {
    const w = new World();
    w.feedTakes = 60_000;
    const o = await runScheduledSync(w.env({ SYNC_MODE: 'discover' }), { ...w.deps(), budgetMs: 30_000 });
    expect(o.status === 'partial' || o.status === 'failed').toBe(true);
    if (o.status !== 'skipped') expect(o.summary.error_class).toBe('deadline');
  });

  it('a wrong key stops at the lease: the source is not asked and nothing is written', async () => {
    const w = new World();
    await expect(runScheduledSync(w.env({ SYNC_MODE: 'discover', SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_WRONGKEYWRONGKEYWRONGKEY' }), w.deps())).rejects.toThrow(/auth/);
    expect(w.calls.feed).toBe(0);
    expect(w.calls.status).toBe(0);
  });

  it('logs counts and error classes, never the key or a job description', async () => {
    const w = new World();
    await discover(w);
    const logs = w.allLogs();
    expect(logs).toContain('sync_ok');
    expect(logs).toMatch(/"alreadyKnown":0/);
    expect(logs).not.toContain('sb_secret_');
    expect(logs).not.toMatch(/jobDescription|description/);
  });
});

describe('SYNC_MODE=discover: the free-database guard (catalogue ceiling)', () => {
  it('stops adding at the ceiling, ends PARTIAL with a class that names the cause, and keeps what it added before reaching it', async () => {
    const w = new World();
    w.jobs.set('jobicy:900001', storedJob('900001')); w.jobs.set('jobicy:900002', storedJob('900002'));
    const o = await discover(w, { SYNC_MAX_CATALOGUE: '5' });
    expect(o).toMatchObject({ status: 'partial', summary: { upserted: 3, skippedNew: 7, error_class: 'catalogue_full' } });
    expect(w.jobs.size).toBe(5);
    expect(w.runs[0]).toMatchObject({ status: 'partial', error_class: 'catalogue_full', upserted: 3 });
    expect(w.requests.filter((r) => r.method === 'PATCH' && r.table === 'jobs')).toEqual([]);
  });

  it('a ceiling already reached imports nothing and does not ask the status endpoint', async () => {
    const w = new World();
    for (const id of ['1', '2', '3']) w.jobs.set(`jobicy:${id}`, storedJob(id));
    const o = await discover(w, { SYNC_MAX_CATALOGUE: '3' });
    expect(o).toMatchObject({ status: 'partial', summary: { upserted: 0, error_class: 'catalogue_full' } });
    expect(w.calls.status).toBe(0);
    expect(w.jobs.size).toBe(3);
  });

  it('below the ceiling nothing changes (ok), and the default ceiling is the documented 4000', () => {
    expect(loadConfig({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_' + 'A'.repeat(30), SYNC_MODE: 'discover' }).maxCatalogue).toBe(DISCOVER_DEFAULT_CATALOGUE);
    expect(loadConfig({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_' + 'A'.repeat(30), SYNC_MODE: 'revalidate' }).maxCatalogue).toBeUndefined();
    expect(() => loadConfig({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_' + 'A'.repeat(30), SYNC_MODE: 'discover', SYNC_MAX_CATALOGUE: '0' })).toThrow(/SYNC_MAX_CATALOGUE/);
  });
});

describe('SYNC_MODE=discover: the ceiling counts FULL jobs only (compacted closed jobs cost ~1/10 and do not count)', () => {
  const compacted = (id: string) => ({ ...storedJob(id, 'closed'), description: '' });
  const full = (id: string) => ({ ...storedJob(id, 'closed'), description: 'still has a body' });

  it('many compacted closed jobs do not block the import: only the open and still-heavy ones count', async () => {
    const w = new World();
    for (let i = 0; i < 20; i++) w.jobs.set(`jobicy:c${i}`, compacted(`c${i}`));
    w.jobs.set('jobicy:o1', storedJob('o1')); w.jobs.set('jobicy:f1', full('f1'));
    const o = await discover(w, { SYNC_MAX_CATALOGUE: '5' }); // 2 full stored (open + heavy closed) -> room for 3, whatever the 20 compacted ones are
    expect(o).toMatchObject({ status: 'partial', summary: { upserted: 3, error_class: 'catalogue_full' } });
    expect(w.jobs.size).toBe(22 + 3);
  });

  it('closed jobs that still carry a description DO count, so the ceiling cannot be dodged before compaction', async () => {
    const w = new World();
    for (let i = 0; i < 5; i++) w.jobs.set(`jobicy:f${i}`, full(`f${i}`));
    const o = await discover(w, { SYNC_MAX_CATALOGUE: '5' });
    expect(o).toMatchObject({ status: 'partial', summary: { upserted: 0, error_class: 'catalogue_full' } });
  });

  it('a store that cannot count falls back to counting every stored job (the safe side)', async () => {
    const w = new World();
    for (let i = 0; i < 6; i++) w.jobs.set(`jobicy:c${i}`, compacted(`c${i}`));
    const real = w.fetch;
    w.fetch = async (input, init) => (String(input).includes('count') ? new Response('{}', { status: 400 }) : real(input, init));
    const o = await runScheduledSync(w.env({ SYNC_MODE: 'discover', SYNC_MAX_CATALOGUE: '5' }), { ...w.deps(), fetch: w.fetch });
    expect(o.status === 'failed' || o.status === 'partial').toBe(true); // a failing count stops the pass instead of guessing
    expect(w.jobs.size).toBe(6);
  });
});
