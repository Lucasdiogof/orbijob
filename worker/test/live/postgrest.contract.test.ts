import { createHmac } from 'node:crypto';
import { env } from 'node:process';
import { describe, expect, it } from 'vitest';
import { JOBICY_SOURCE, jobicyConnector } from '../../src/connectors/jobicy';
import { HttpError } from '../../src/http';
import { SupabaseJobStore } from '../../src/store/supabase';
import { runSync, toJobRow } from '../../src/sync';
import { slotRunId } from '../../src/lease';
import { runScheduledSync } from '../../src/scheduled';
import feed from '../fixtures/jobicy-feed.sanitized.json';

/**
 * The WRITE side of the ingestion against a REAL PostgREST on the REAL migrated schema (CI job `worker-postgrest`):
 * SupabaseJobStore + runSync + the service_role grants of migration 6, with a real HS256 JWT. Nothing here touches a
 * Supabase project: the database is a throw-away container. Skipped unless the CI provides the server:
 *   POSTGREST_URL=http://localhost:3000 POSTGREST_JWT_SECRET=... npx vitest run test/live/postgrest.contract.test.ts
 */
const URL_ = env.POSTGREST_URL;
const SECRET = env.POSTGREST_JWT_SECRET;

const b64 = (o: unknown) => Buffer.from(JSON.stringify(o)).toString('base64url');
const sign = (role: string) => {
  const h = b64({ alg: 'HS256', typ: 'JWT' });
  const p = b64({ role, exp: Math.floor(Date.now() / 1000) + 3600 });
  return `${h}.${p}.${createHmac('sha256', SECRET ?? '').update(`${h}.${p}`).digest('base64url')}`;
};

const NOW = new Date('2026-10-10T12:00:00.000Z');
const jobs = feed.jobs as Record<string, unknown>[];
const STALE = { closed: '999001', unknown: '999002' };

/** PostgREST serves at the root; Supabase's gateway adds /rest/v1. The store speaks the Supabase form, so strip it. */
const direct: typeof fetch = (input, init) => fetch(String(input).replace('/rest/v1/', '/'), init);

/** The Jobicy API, served locally from the sanitized real fixture. */
function jobicyApi(statuses: Record<string, string>) {
  return (async (u: string) => {
    const url = new URL(u);
    if (url.pathname.endsWith('/status')) {
      const ids = url.searchParams.get('ids')!.split(',');
      return Response.json({ success: true, jobs: ids.map((id) => ({ id: Number(id), status: statuses[id] ?? 'active' })) });
    }
    const cursor = url.searchParams.get('cursor');
    const page = cursor === 'C1' ? jobs.slice(5) : jobs.slice(0, 5);
    return Response.json({ success: true, jobs: page, nextCursor: cursor === 'C1' ? null : 'C1', hasMore: cursor !== 'C1' });
  }) as unknown as typeof fetch;
}

async function rest(method: string, path: string, o: { token?: string; body?: unknown; prefer?: string } = {}) {
  const res = await fetch(`${URL_}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(o.token ? { Authorization: `Bearer ${o.token}` } : {}),
      ...(o.prefer ? { Prefer: o.prefer } : {}),
    },
    body: o.body === undefined ? undefined : JSON.stringify(o.body),
  });
  const text = await res.text();
  return { status: res.status, json: text ? (JSON.parse(text) as unknown) : null };
}

describe.skipIf(!URL_ || !SECRET)('ingestion against a real PostgREST', () => {
  const service = sign('service_role');
  const store = new SupabaseJobStore(URL_ ?? 'http://localhost:3000', service, direct);
  const statuses: Record<string, string> = {};
  const run = (logs: string[] = []) =>
    runSync({
      connector: jobicyConnector(jobicyApi(statuses), () => NOW),
      store, now: () => NOW, sleep: async () => {}, retry: { retries: 0, baseMs: 1, maxMs: 1 },
      log: (e, d) => logs.push(e + JSON.stringify(d)),
    });

  it('service_role can register the source (migration 6 grants insert/update on job_sources)', async () => {
    const r = await rest('POST', '/job_sources', {
      token: service, prefer: 'resolution=merge-duplicates,return=minimal',
      body: { id: JOBICY_SOURCE.id, status: JOBICY_SOURCE.status, attribution: JOBICY_SOURCE.attribution, can_redistribute: JOBICY_SOURCE.canRedistribute },
    });
    expect(r.status).toBe(201);
  });

  it('a full pass writes every listing and records the run', async () => {
    const logs: string[] = [];
    const s = await run(logs);
    expect(s).toMatchObject({ status: 'ok', pages: 2, upserted: 10, duplicates: 0, rejected: 0, closed: 0, runRecorded: true });
    expect(logs.join('\n')).not.toContain(service);
    const runs = await rest('GET', '/sync_runs?select=status,fetched,upserted,closed,error_class', { token: service });
    expect(runs.json).toEqual([{ status: 'ok', fetched: 10, upserted: 10, closed: 0, error_class: null }]);
  });

  it('clients (anon) read those rows with the stored attribution', async () => {
    const r = await rest('GET', '/jobs?select=external_id,work_mode,status,salary_min,geo_restrictions,job_sources(attribution,can_redistribute)&order=external_id');
    expect(r.status).toBe(200);
    const rows = r.json as { external_id: string; job_sources: { attribution: string; can_redistribute: boolean } }[];
    expect(rows).toHaveLength(10);
    for (const row of rows) expect(row.job_sources).toEqual({ attribution: JOBICY_SOURCE.attribution, can_redistribute: true });
    const first = rows.find((x) => x.external_id === '154956') as unknown as Record<string, unknown>;
    expect(first).toMatchObject({ work_mode: 'remote', status: 'open', salary_min: 120000, geo_restrictions: ['US'] });
  });

  it('the stored row equals what toJobRow produced (types and values survive the round trip)', async () => {
    const page = await jobicyConnector(jobicyApi({}), () => NOW).fetchPage(null, '');
    const expected = toJobRow(page.jobs[0]!);
    const r = await rest('GET', `/jobs?external_id=eq.${expected.external_id}&select=*`, { token: service });
    const row = (r.json as Record<string, unknown>[])[0]!;
    for (const k of ['source_id', 'company', 'title', 'description', 'country', 'work_mode', 'contract_type', 'original_url', 'apply_url', 'status', 'canonical_url', 'fingerprint', 'salary_currency', 'salary_period'] as const) {
      expect(row[k], k).toEqual(expected[k]);
    }
    expect(new Date(row.published_at as string).toISOString()).toBe(expected.published_at);
    expect(row.geo_restrictions).toEqual(expected.geo_restrictions);
  });

  it('running the same pass again is idempotent', async () => {
    const s = await run();
    expect(s).toMatchObject({ status: 'ok', upserted: 10 });
    const ids = (await rest('GET', '/jobs?select=external_id', { token: service })).json as unknown[];
    expect(ids).toHaveLength(10);
    const runs = (await rest('GET', '/sync_runs?select=id', { token: service })).json as unknown[];
    expect(runs).toHaveLength(2);
  });

  it('closes only what the source reports closed; "unknown" and "active" stay open (real PATCH)', async () => {
    const base = toJobRow((await jobicyConnector(jobicyApi({}), () => NOW).fetchPage(null, '')).jobs[0]!);
    await store.upsertJobs([
      { ...base, external_id: STALE.closed, original_url: 'https://jobicy.com/jobs/999001', canonical_url: 'https://jobicy.com/jobs/999001', fingerprint: 'stale-1' },
      { ...base, external_id: STALE.unknown, original_url: 'https://jobicy.com/jobs/999002', canonical_url: 'https://jobicy.com/jobs/999002', fingerprint: 'stale-2' },
    ]);
    statuses[STALE.closed] = 'closed';
    statuses[STALE.unknown] = 'unknown';
    const s = await run();
    expect(s).toMatchObject({ status: 'ok', closed: 1 });
    const r = await rest('GET', `/jobs?external_id=in.("${STALE.closed}","${STALE.unknown}","154956")&select=external_id,status&order=external_id`, { token: service });
    expect(r.json).toEqual([
      { external_id: '154956', status: 'open' },
      { external_id: STALE.closed, status: 'closed' },
      { external_id: STALE.unknown, status: 'open' },
    ]);
    // clients no longer see the closed one (their query asks for open jobs only)
    const anon = (await rest('GET', '/jobs?status=eq.open&select=external_id')).json as { external_id: string }[];
    expect(anon.map((x) => x.external_id)).not.toContain(STALE.closed);
  });

  it('a failed pass closes nothing (the feed is down)', async () => {
    const down = jobicyConnector((async () => new Response('x', { status: 503 })) as unknown as typeof fetch, () => NOW);
    const s = await runSync({ connector: down, store, now: () => NOW, sleep: async () => {}, retry: { retries: 0, baseMs: 1, maxMs: 1 } });
    expect(s).toMatchObject({ status: 'failed', error_class: 'http_503', closed: 0 });
    const open = (await rest('GET', '/jobs?status=eq.open&select=external_id', { token: service })).json as unknown[];
    expect(open).toHaveLength(10 + 1); // 10 listings + the "unknown" stale one
  });

  describe('least privilege', () => {
    it('sync_runs is invisible to clients', async () => {
      const r = await rest('GET', '/sync_runs');
      expect([401, 403]).toContain(r.status);
    });
    it('clients cannot write the catalogue', async () => {
      const r = await rest('POST', '/jobs', { body: [{ source_id: 'jobicy', external_id: 'evil', company: 'x', title: 'x', last_checked_at: NOW.toISOString(), original_url: 'https://x', fingerprint: 'x', canonical_url: 'https://x' }] });
      expect([401, 403]).toContain(r.status);
      const authed = await rest('POST', '/jobs', { token: sign('authenticated'), body: [{ source_id: 'jobicy', external_id: 'evil2' }] });
      expect([401, 403]).toContain(authed.status);
    });
    it('service_role cannot read user data or delete sources', async () => {
      expect([401, 403]).toContain((await rest('GET', '/saved_jobs', { token: service })).status);
      expect([401, 403]).toContain((await rest('GET', '/professional_profiles', { token: service })).status);
      expect([401, 403]).toContain((await rest('DELETE', '/job_sources?id=eq.jobicy', { token: service })).status);
      expect((await rest('GET', '/job_sources?select=id', { token: service })).json).toEqual([{ id: 'jobicy' }]);
    });
  });

  it('a wrong key is refused with the status only, and the key is not echoed anywhere', async () => {
    const bad = 'not-a-valid-jwt-token-for-tests';
    const s = new SupabaseJobStore(URL_ ?? 'http://localhost:3000', bad, direct);
    const err = await s.recordRun({ source_id: 'jobicy', scope: '', started_at: NOW.toISOString(), finished_at: NOW.toISOString(), status: 'ok', fetched: 0, upserted: 0, duplicates: 0, closed: 0, http_errors: 0, error_class: null }).catch((e) => e as HttpError);
    expect(err).toBeInstanceOf(HttpError);
    expect((err as HttpError).status).toBe(401);
    expect(String(err) + JSON.stringify(err)).not.toContain(bad);
  });
});

/**
 * The scheduled handler and its lease against the REAL database. Dates are far in the future so that nothing recorded by the
 * tests above (fixed clock) or by a real run can throttle them. The mutual exclusion between concurrent Workers is a PRIMARY
 * KEY on sync_runs.id derived from (source, hour): these tests are the proof that PostgreSQL, through PostgREST and over
 * separate connections, really refuses the duplicates. Nothing here is relaxed to "whichever way the losers lost".
 */
describe.skipIf(!URL_ || !SECRET)('scheduled handler on a real PostgREST', () => {
  const svc = sign('service_role');
  const day = (n: number, hour = 12, minute = 0) => new Date(Date.UTC(2030, 0, n, hour, minute));

  /** Supabase calls go straight to PostgREST (prefix stripped); everything else is the fake Jobicy. */
  function world(clock: { now: Date }, statuses: Record<string, string> = {}, fault?: (feedCall: number, cursor: string | null) => Response | null) {
    const counts = { feed: 0, supabase: 0 };
    const jobicy = jobicyApi(statuses);
    const f = (async (input: string, init?: RequestInit) => {
      const u = new URL(String(input));
      if (u.hostname === 'jobicy.com') {
        if (u.pathname.endsWith('/status')) return jobicy(String(input));
        const call = counts.feed++;
        return fault?.(call, u.searchParams.get('cursor')) ?? jobicy(String(input));
      }
      counts.supabase++;
      return fetch(String(input).replace('/rest/v1/', '/'), init);
    }) as unknown as typeof fetch;
    const logs: string[] = [];
    const sink = { log: (l: string) => logs.push(l), warn: (l: string) => logs.push(l), error: (l: string) => logs.push(l) };
    const deps = () => ({ fetch: f, now: () => clock.now, sink, sleep: async () => {}, retry: { retries: 0, baseMs: 1, maxMs: 1 } });
    return { counts, logs, deps };
  }
  const env = (key = svc) => ({ SUPABASE_URL: URL_ ?? 'http://localhost:3000', SUPABASE_SERVICE_ROLE_KEY: key });
  type RunRow = { status: string; error_class: string | null; upserted: number };
  const runsAt = async (t: Date) => (await rest('GET', `/sync_runs?select=status,error_class,upserted&source_id=eq.jobicy&started_at=eq.${encodeURIComponent(t.toISOString())}&order=status`, { token: svc })).json as RunRow[];
  const runsBetween = async (a: Date, b: Date) => (await rest('GET', `/sync_runs?select=status,error_class&source_id=eq.jobicy&started_at=gte.${encodeURIComponent(a.toISOString())}&started_at=lte.${encodeURIComponent(b.toISOString())}`, { token: svc })).json as RunRow[];
  const jobStatus = async (id: string) => ((await rest('GET', `/jobs?select=status&source_id=eq.jobicy&external_id=eq.${id}`, { token: svc })).json as { status: string }[])[0]?.status;

  it('a pass through the handler leaves ONE run row (the claim row, updated to its final state)', async () => {
    const clock = { now: day(1) };
    const w = world(clock);
    const o = await runScheduledSync(env(), w.deps());
    expect(o).toMatchObject({ status: 'ok', summary: { upserted: 10 } });
    expect(await runsAt(day(1))).toEqual([{ status: 'ok', error_class: null, upserted: 10 }]);
    const claimed = await slotRunId('jobicy', day(1).getTime(), 3_600_000);
    const row = (await rest('GET', `/sync_runs?id=eq.${claimed}&select=id,status`, { token: svc })).json as { id: string; status: string }[];
    expect(row).toEqual([{ id: claimed, status: 'ok' }]); // the id is the one every instance computes for this hour
    expect(w.logs.join('\n')).not.toContain(svc);
  });

  it('the primary key refuses a second claim of the same hour: PostgreSQL answers 409, over a plain INSERT', async () => {
    const id = await slotRunId('jobicy', day(25).getTime(), 3_600_000); // a day no other test uses
    const body = { id, source_id: 'jobicy', scope: '', status: 'running', started_at: day(25).toISOString() };
    const first = await rest('POST', '/sync_runs', { token: svc, body, prefer: 'return=minimal' });
    const second = await rest('POST', '/sync_runs', { token: svc, body, prefer: 'return=minimal' });
    expect(first.status).toBe(201);
    expect(second.status).toBe(409);
    expect((second.json as { code?: string }).code).toBe('23505'); // unique_violation
    await rest('PATCH', `/sync_runs?id=eq.${id}`, { token: svc, body: { status: 'failed', error_class: 'stale_lock' }, prefer: 'return=minimal' });
  });

  it.each([2, 3, 10])('%i simultaneous invocations against the real database: exactly ONE syncs, the others are refused and write nothing', async (n) => {
    const clock = { now: day(10 + n) };
    const w = world(clock);
    const out = await Promise.all(Array.from({ length: n }, () => runScheduledSync(env(), w.deps())));
    expect(out.filter((o) => o.status === 'ok')).toHaveLength(1);
    const skipped = out.filter((o) => o.status === 'skipped') as { status: 'skipped'; reason: string }[];
    expect(skipped).toHaveLength(n - 1);
    expect(skipped.every((o) => ['running', 'lost_race'].includes(o.reason))).toBe(true);
    expect(w.counts.feed).toBe(2); // the two pages of ONE pass: the source was asked once
    // STRICT: one row for the hour, finished ok. The losers left no trace and nothing is stuck "running".
    expect(await runsAt(clock.now)).toEqual([{ status: 'ok', error_class: null, upserted: 10 }]);
    expect(await runsBetween(day(10 + n, 0), day(10 + n, 23))).toEqual([{ status: 'ok', error_class: null }]);
  });

  it('a repeat delivery within the hour is skipped; after the hour it runs again and the catalogue is unchanged', async () => {
    const clock = { now: day(3) };
    const w = world(clock);
    expect((await runScheduledSync(env(), w.deps())).status).toBe('ok');
    clock.now = day(3, 12, 10);
    expect(await runScheduledSync(env(), w.deps())).toEqual({ status: 'skipped', reason: 'too_soon' });
    expect(w.counts.feed).toBe(2);
    clock.now = day(3, 13, 0); // exactly one hour later is a new slot
    expect((await runScheduledSync(env(), w.deps())).status).toBe('ok');
    const n = (await rest('GET', '/jobs?select=external_id&source_id=eq.jobicy', { token: svc })).json as unknown[];
    expect(n).toHaveLength(12); // 10 listings + the two stale rows planted above (one closed, one "unknown"); nothing duplicated
  });

  it('a crashed run left "running" past its lease is closed as stale and does not block the next hour', async () => {
    const stale = await rest('POST', '/sync_runs?select=id', { token: svc, prefer: 'return=representation', body: { source_id: 'jobicy', scope: '', status: 'running', started_at: day(4, 11, 20).toISOString() } });
    const id = (stale.json as { id: string }[])[0]!.id;
    const clock = { now: day(4) };
    expect((await runScheduledSync(env(), world(clock).deps())).status).toBe('ok');
    const row = (await rest('GET', `/sync_runs?id=eq.${id}&select=status,error_class`, { token: svc })).json as { status: string; error_class: string }[];
    expect(row).toEqual([{ status: 'failed', error_class: 'stale_lock' }]);
  });

  it('after a crash, a retry inside the SAME hour is refused by the key (the slot is used); the next hour proceeds', async () => {
    const id = await slotRunId('jobicy', day(8).getTime(), 3_600_000);
    await rest('POST', '/sync_runs', { token: svc, prefer: 'return=minimal', body: { id, source_id: 'jobicy', scope: '', status: 'running', started_at: day(8, 12, 5).toISOString() } });
    const clock = { now: day(8, 12, 40) }; // 35 minutes later: past the 20-minute lease
    const w = world(clock);
    expect(await runScheduledSync(env(), w.deps())).toEqual({ status: 'skipped', reason: 'lost_race' });
    expect(w.counts.feed).toBe(0);
    expect((await rest('GET', `/sync_runs?id=eq.${id}&select=status,error_class`, { token: svc })).json).toEqual([{ status: 'failed', error_class: 'stale_lock' }]);
    clock.now = day(8, 13, 0);
    expect((await runScheduledSync(env(), w.deps())).status).toBe('ok');
  });

  it('a live run in the database makes the handler skip without touching the source', async () => {
    await rest('POST', '/sync_runs', { token: svc, prefer: 'return=minimal', body: { source_id: 'jobicy', scope: '', status: 'running', started_at: day(5, 11, 55).toISOString() } });
    const w = world({ now: day(5) });
    expect(await runScheduledSync(env(), w.deps())).toEqual({ status: 'skipped', reason: 'running' });
    expect(w.counts.feed).toBe(0);
  });

  it('a credential signed with the wrong secret is refused by PostgREST: auth failure before any request to Jobicy', async () => {
    const h = b64({ alg: 'HS256', typ: 'JWT' });
    const p = b64({ role: 'service_role', exp: Math.floor(Date.now() / 1000) + 3600 });
    const forged = `${h}.${p}.${createHmac('sha256', 'a-completely-different-secret-0123456789').update(`${h}.${p}`).digest('base64url')}`;
    const w = world({ now: day(6) });
    await expect(runScheduledSync(env(forged), w.deps())).rejects.toMatchObject({ kind: 'auth' });
    expect(w.counts.feed).toBe(0);
    expect(w.logs.join('\n')).not.toContain(forged);
  });

  it('a failure during the pass is recorded on the SAME row, and the next hour recovers', async () => {
    const clock = { now: day(7) };
    const down = world(clock, {}, () => new Response('x', { status: 503 }));
    const o = await runScheduledSync(env(), down.deps());
    expect(o).toMatchObject({ status: 'failed', summary: { error_class: 'http_503' } });
    const rows = (await rest('GET', `/sync_runs?source_id=eq.jobicy&started_at=eq.${encodeURIComponent(day(7).toISOString())}&select=status,error_class,finished_at`, { token: svc })).json as { status: string; error_class: string; finished_at: string | null }[];
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ status: 'failed', error_class: 'http_503' });
    expect(rows[0]!.finished_at).not.toBeNull();
    clock.now = day(7, 12, 30); // within the hour: the failure still throttles (do not hammer a source that just failed us)
    expect(await runScheduledSync(env(), down.deps())).toEqual({ status: 'skipped', reason: 'too_soon' });
    clock.now = day(7, 13, 0);
    expect((await runScheduledSync(env(), world(clock).deps())).status).toBe('ok'); // recovery
  });

  it('a PARTIAL pass closes nothing even when the source would say "closed"; the next complete pass closes exactly that', async () => {
    const stale = '999002'; // planted open earlier in this file
    expect(await jobStatus(stale)).toBe('open');
    const clock = { now: day(9) };
    const partial = world(clock, { [stale]: 'closed' }, (_c, cursor) => (cursor ? new Response('boom', { status: 500 }) : null));
    const o = await runScheduledSync(env(), partial.deps());
    expect(o).toMatchObject({ status: 'partial', summary: { error_class: 'http_500', closed: 0 } });
    expect(await jobStatus(stale)).toBe('open'); // NOT closed by an incomplete pass
    clock.now = day(9, 13, 0);
    const full = world(clock, { [stale]: 'closed' });
    expect(await runScheduledSync(env(), full.deps())).toMatchObject({ status: 'ok', summary: { closed: 1 } });
    expect(await jobStatus(stale)).toBe('closed');
  });
});
