import { describe, expect, it } from 'vitest';
import { ConfigError, type Env } from '../src/env';
import { LEASE_TTL_MS, MIN_INTERVAL_MS, RUN_BUDGET_MS, SyncFailure, runScheduledSync } from '../src/scheduled';
import { FEED_JOBS, SECRET_KEY, World, fakeKey, fakePublishable, storedJob, URL_SB } from './helpers/world';

// The real SupabaseJobStore, lease and runSync run against an in-memory Supabase + Jobicy (test/helpers/world.ts).
// No network, no real credentials; the only key in this file is a made-up one.

const run = (w: World, env: Env = w.env(), extra: Record<string, unknown> = {}) => runScheduledSync(env, w.deps(extra));
const LIVE_ID = '00000000-0000-4000-8000-0000000000a1';
const DEAD_ID = '00000000-0000-4000-8000-0000000000d1';
/** Everything except the "last checked" stamp, which is supposed to move on every pass. */
const stable = (w: World) => JSON.stringify([...w.jobs.entries()].map(([k, v]) => [k, { ...v, last_checked_at: undefined }]).sort());
const expectClean = (w: World) => {
  const all = w.allLogs();
  expect(all).not.toContain(SECRET_KEY);
  expect(all).not.toContain('TESTKEY'); // not even a fragment
  expect(all).not.toMatch(/jobicy\.com\/jobs|Juniper|Account Executive|https?:\/\//); // no job content, no URLs
};

describe('scheduled sync: a normal pass', () => {
  it('stores every listing, records ONE run row (the lease row, updated), and logs only counts', async () => {
    const w = new World();
    const o = await run(w);
    expect(o).toMatchObject({ status: 'ok', summary: { pages: 2, fetched: 10, upserted: 10, duplicates: 0, closed: 0, runRecorded: true } });
    expect(w.openIds()).toHaveLength(10);
    expect(w.runs).toHaveLength(1);
    expect(w.runs[0]).toMatchObject({ source_id: 'jobicy', status: 'ok', fetched: 10, upserted: 10, error_class: null, started_at: w.clock.toISOString() });
    expect(w.runs[0]!.finished_at).not.toBeNull();
    expect(w.allLogs()).toContain('"event":"sync_start"');
    expect(w.allLogs()).toContain('"event":"sync_ok"');
    expectClean(w);
  });

  it('asks Jobicy for exactly the pages of one pass, not more', async () => {
    const w = new World();
    await run(w);
    expect(w.calls.feed).toBe(2);
    expect(w.calls.status).toBe(0); // nothing stored before, so nothing to ask about
  });

  it('is idempotent: the next cycle, beyond the minimum interval, leaves the same jobs and adds a run row', async () => {
    const w = new World();
    await run(w);
    const before = stable(w);
    const stamp = (w.jobs.get('jobicy:154956') as { last_checked_at: string }).last_checked_at;
    w.clock = new Date(w.clock.getTime() + 6 * 3_600_000);
    const o = await run(w);
    expect(o.status).toBe('ok');
    expect(w.jobs.size).toBe(10);
    expect(stable(w)).toBe(before);
    expect((w.jobs.get('jobicy:154956') as { last_checked_at: string }).last_checked_at).not.toBe(stamp); // the stamp moves
    expect(w.runs).toHaveLength(2);
    expect(w.runs.map((r) => r.status)).toEqual(['ok', 'ok']);
  });
});

describe('scheduled sync: configuration and credentials', () => {
  it('missing configuration: fails loudly, names the variables, makes no request at all', async () => {
    const w = new World();
    await expect(run(w, {})).rejects.toBeInstanceOf(ConfigError);
    expect(w.calls).toEqual({ feed: 0, status: 0, supabase: 0 });
    const line = JSON.parse(w.logs[0]!);
    expect(line).toMatchObject({ level: 'error', event: 'config_invalid', problems: ['SUPABASE_URL is not set', 'SUPABASE_SERVICE_ROLE_KEY is not set'] });
  });

  it('a publishable key in the secret slot is refused before any request, and never printed', async () => {
    const w = new World();
    const key = fakePublishable('VERYSECRETLOOKING');
    await expect(run(w, w.env({ SUPABASE_SERVICE_ROLE_KEY: key }))).rejects.toBeInstanceOf(ConfigError);
    expect(w.calls.supabase).toBe(0);
    expect(w.allLogs()).not.toContain('VERYSECRETLOOKING');
  });

  it('an insecure Supabase URL is refused before any request', async () => {
    const w = new World();
    await expect(run(w, w.env({ SUPABASE_URL: 'http://example.supabase.co' }))).rejects.toBeInstanceOf(ConfigError);
    expect(w.calls.supabase).toBe(0);
  });

  it('a rejected credential (401): stops BEFORE touching Jobicy, reports auth, leaks nothing', async () => {
    const w = new World();
    w.expectedKey = fakeKey('OTHERKEY');
    await expect(run(w)).rejects.toMatchObject({ kind: 'auth' });
    expect(w.calls.feed).toBe(0);
    expect(w.calls.status).toBe(0);
    expect(w.logs.join('\n')).toContain('"event":"supabase_auth_failed"');
    expect(w.runs).toHaveLength(0);
    expectClean(w);
  });

  it('a forbidden credential (403: migration 6 not applied) is also an auth failure, and not retried', async () => {
    const w = new World();
    w.supabaseStatus = 403;
    await expect(run(w)).rejects.toMatchObject({ kind: 'auth' });
    expect(w.calls.supabase).toBe(1);
    expect(w.calls.feed).toBe(0);
    expectClean(w);
  });

  it('Supabase unreachable: retried, then reported as unreachable; Jobicy untouched', async () => {
    const w = new World();
    w.supabaseDown = true;
    await expect(run(w)).rejects.toMatchObject({ kind: 'unreachable' });
    expect(w.calls.supabase).toBe(2); // one try + one retry (deps.retry)
    expect(w.calls.feed).toBe(0);
    expect(w.logs.join('\n')).toContain('"event":"supabase_unreachable"');
    expectClean(w);
  });

  it('Supabase 5xx is treated as unreachable (retryable), not as bad credentials', async () => {
    const w = new World();
    w.supabaseStatus = 503;
    await expect(run(w)).rejects.toBeInstanceOf(SyncFailure);
    await expect(run(w)).rejects.toMatchObject({ kind: 'unreachable' });
  });

  it('sends a sb_secret_ key ONLY in apikey, and a service_role JWT in apikey and Authorization', async () => {
    const w = new World();
    await run(w);
    expect(w.supabaseHeaders.length).toBeGreaterThan(3);
    for (const h of w.supabaseHeaders) {
      expect(h.apikey).toBe(SECRET_KEY);
      expect(Object.keys(h).map((k) => k.toLowerCase())).not.toContain('authorization');
    }
    const w2 = new World();
    const jwt = `eyJhbGciOiJIUzI1NiJ9.${btoa('{"role":"service_role"}').replace(/=+$/, '')}.c2lnbmF0dXJl`;
    w2.expectedKey = jwt;
    const o = await run(w2, w2.env({ SUPABASE_SERVICE_ROLE_KEY: jwt }));
    expect(o.status).toBe('ok');
    expect(w2.supabaseHeaders.every((h) => h.Authorization === `Bearer ${jwt}`)).toBe(true);
    expect(w2.allLogs()).not.toContain(jwt);
  });
});

describe('scheduled sync: Jobicy problems', () => {
  it('HTTP 429 on every attempt: a total failure, recorded with its class, nothing closed', async () => {
    const w = new World();
    for (const id of ['5001', '5002']) w.jobs.set(`jobicy:${id}`, storedJob(id));
    w.jobicyFault = () => new Response('slow down', { status: 429, headers: { 'retry-after': '3' } });
    const o = await run(w);
    expect(o).toMatchObject({ status: 'failed', summary: { error_class: 'http_429', closed: 0, upserted: 0 } });
    expect(w.runs[0]).toMatchObject({ status: 'failed', error_class: 'http_429' });
    expect(w.status('5001')).toBe('open');
    expect(w.calls.status).toBe(0);
    expectClean(w);
  });

  it('a 429 that clears on the retry still completes the pass', async () => {
    const w = new World();
    w.jobicyFault = (call) => (call === 0 ? new Response('x', { status: 429 }) : null);
    expect((await run(w)).status).toBe('ok');
  });

  it('a timeout is classified as such and fails the run without closing anything', async () => {
    const w = new World();
    w.jobs.set('jobicy:5001', storedJob('5001'));
    w.jobicyFault = () => Object.assign(new Error('The operation timed out'), { name: 'TimeoutError' });
    const o = await run(w);
    expect(o).toMatchObject({ status: 'failed', summary: { error_class: 'timeout' } });
    expect(w.status('5001')).toBe('open');
  });

  it('a 500 on the second page is PARTIAL: what was fetched is kept, nothing is closed, the run says partial', async () => {
    const w = new World();
    w.jobs.set('jobicy:5001', storedJob('5001'));
    w.statuses['5001'] = 'closed'; // the source WOULD say closed, but a partial pass must not even ask
    w.jobicyFault = (_c, cursor) => (cursor ? new Response('boom', { status: 500 }) : null);
    const o = await run(w);
    expect(o).toMatchObject({ status: 'partial', summary: { pages: 1, upserted: 5, closed: 0, error_class: 'http_500' } });
    expect(w.openIds()).toHaveLength(6);
    expect(w.status('5001')).toBe('open');
    expect(w.calls.status).toBe(0);
    expect(w.runs[0]).toMatchObject({ status: 'partial', upserted: 5 });
    expectClean(w);
  });

  it('after a COMPLETE pass only what Jobicy reports closed is closed; active and unknown stay open', async () => {
    const w = new World();
    for (const id of ['5001', '5002', '5003']) w.jobs.set(`jobicy:${id}`, storedJob(id));
    w.statuses = { '5001': 'closed', '5002': 'unknown', '5003': 'active' };
    const o = await run(w);
    expect(o).toMatchObject({ status: 'ok', summary: { closed: 1 } });
    expect([w.status('5001'), w.status('5002'), w.status('5003')]).toEqual(['closed', 'open', 'open']);
  });

  it('a failing status check leaves everything open and marks the run partial', async () => {
    const w = new World();
    w.jobs.set('jobicy:5001', storedJob('5001'));
    const base = w.fetch;
    w.fetch = (async (i, n) => (String(i).includes('/status') ? new Response('x', { status: 500 }) : base(i, n))) as typeof fetch;
    const o = await run(w);
    expect(o).toMatchObject({ status: 'partial', summary: { closed: 0 } });
    expect(w.status('5001')).toBe('open');
  });

  it('garbage from the source (invalid links) is rejected per record and does not fail the pass', async () => {
    const w = new World();
    w.feedPages = [[{ id: 1, jobTitle: 'x', url: 'https://evil.example/1' }, FEED_JOBS[0]!]];
    const o = await run(w);
    expect(o).toMatchObject({ status: 'ok', summary: { rejected: 1, upserted: 1 } });
  });

  it('the pass stops by itself before the Worker wall-clock limit: partial, deadline, nothing closed', async () => {
    const w = new World();
    w.jobs.set('jobicy:5001', storedJob('5001'));
    w.feedPages = Array.from({ length: 10 }, (_, i) => [FEED_JOBS[i]!]);
    w.feedTakes = 5 * 60_000; // every page "takes" 5 minutes of the 12-minute budget
    const o = await run(w);
    expect(RUN_BUDGET_MS).toBe(12 * 60_000);
    expect(o).toMatchObject({ status: 'partial', summary: { error_class: 'deadline', closed: 0 } });
    expect((o as { summary: { pages: number } }).summary.pages).toBe(3);
    expect(w.status('5001')).toBe('open');
  });

  it('the page cap from the configuration ends the pass as partial', async () => {
    const w = new World();
    w.feedPages = Array.from({ length: 6 }, (_, i) => [FEED_JOBS[i]!]);
    const o = await run(w, w.env({ SYNC_MAX_PAGES: '2' }));
    expect(o).toMatchObject({ status: 'partial', summary: { pages: 2, error_class: 'max_pages', closed: 0 } });
  });
});

describe('scheduled sync: concurrency and repeated delivery', () => {
  it('three invocations at the same instant: ONE syncs; the others skip; Jobicy is asked once', async () => {
    const w = new World();
    const out = await Promise.all([run(w), run(w), run(w)]);
    expect(out.filter((o) => o.status === 'ok')).toHaveLength(1);
    expect(out.filter((o) => o.status === 'skipped')).toHaveLength(2);
    expect(w.calls.feed).toBe(2); // the two pages of ONE pass
    expect(w.openIds()).toHaveLength(10);
    // The two losers were refused by the primary key (or saw the winner running): they wrote NOTHING, so there is exactly one row.
    expect(w.runs).toHaveLength(1);
    expect(w.runs[0]).toMatchObject({ status: 'ok', upserted: 10 });
    expect(out.filter((o) => o.status === 'skipped').every((o) => o.status === 'skipped' && ['running', 'lost_race'].includes(o.reason))).toBe(true);
    expectClean(w);
  });

  it('a duplicate delivery of the cron shortly after a pass is skipped (the source allows one pass per hour)', async () => {
    const w = new World();
    await run(w);
    w.clock = new Date(w.clock.getTime() + 10 * 60_000);
    expect(await run(w)).toEqual({ status: 'skipped', reason: 'too_soon' });
    expect(w.calls.feed).toBe(2);
    w.clock = new Date(w.clock.getTime() + MIN_INTERVAL_MS);
    expect((await run(w)).status).toBe('ok');
  });

  it('while another run is alive, this one skips without touching the source', async () => {
    const w = new World();
    w.runs.push({ id: LIVE_ID, source_id: 'jobicy', scope: '', started_at: new Date(w.clock.getTime() - 3 * 60_000).toISOString(), finished_at: null, status: 'running', fetched: 0, upserted: 0, duplicates: 0, closed: 0, http_errors: 0, error_class: null });
    expect(await run(w)).toEqual({ status: 'skipped', reason: 'running' });
    expect(w.calls.feed).toBe(0);
  });

  it('a crashed run cannot block the source forever: after the TTL it is closed as stale and the pass proceeds', async () => {
    const w = new World();
    w.runs.push({ id: DEAD_ID, source_id: 'jobicy', scope: '', started_at: new Date(w.clock.getTime() - LEASE_TTL_MS - 60_000).toISOString(), finished_at: null, status: 'running', fetched: 0, upserted: 0, duplicates: 0, closed: 0, http_errors: 0, error_class: null });
    const o = await run(w);
    expect(o.status).toBe('ok');
    expect(w.runs.find((r) => r.id === DEAD_ID)).toMatchObject({ status: 'failed', error_class: 'stale_lock' });
  });

  it('a failed pass does not leave its lease stuck as "running"', async () => {
    const w = new World();
    w.jobicyFault = () => new Response('x', { status: 500 });
    await run(w);
    expect(w.runs.filter((r) => r.status === 'running')).toHaveLength(0);
  });

  it('the URL is never part of any log line', async () => {
    const w = new World();
    await run(w);
    expect(w.allLogs()).not.toContain(URL_SB);
  });
});
