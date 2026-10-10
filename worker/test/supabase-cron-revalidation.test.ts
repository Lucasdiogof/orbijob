import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';
import { slotRunId } from '../src/lease';
import statusFixture from './fixtures/jobicy-status.json';

/**
 * The in-database revalidation (migration 20261015000000: pg_cron + pg_net), run against the REAL schema in PGlite.
 * pg_net and pg_cron themselves are not available here: `net` and `cron` are small stand-ins that record what would be sent and
 * scheduled, and the tests play the part of Jobicy by writing the answers into `net._http_response`.
 * Nothing here touches a hosted project.
 */
const file = (p: string) => readFileSync(new URL(`../../${p}`, import.meta.url), 'utf8');
const migration = (f: string) => file(`supabase/migrations/${f}`);
const ENABLE = file('scripts/supabase/ops/enable_revalidation_cron.sql');
const DISABLE = file('scripts/supabase/ops/disable_revalidation_cron.sql');
const SWITCH = "set orbijob.enable_revalidation_cron = 'EU-AUTORIZO-A-REVALIDACAO-AUTOMATICA';";
let db: PGlite;

const NET_STUB = `
  create schema net;
  create unlogged table net._http_response (id bigint, status_code int, content_type text, headers jsonb, content text, timed_out boolean, error_msg text, created timestamptz not null default now());
  create table net._requests (id bigserial primary key, url text, headers jsonb, timeout int);
  create function net.http_get(url text, params jsonb default '{}', headers jsonb default '{}', timeout_milliseconds int default 2000) returns bigint
    language sql as $$ insert into net._requests (url, headers, timeout) values (url, headers, timeout_milliseconds) returning id $$;`;
const CRON_STUB = `
  create schema cron;
  create table cron.job (jobid serial primary key, jobname text unique, schedule text, command text);
  create function cron.schedule(job_name text, schedule text, command text) returns bigint language sql as $$
    insert into cron.job (jobname, schedule, command) values (job_name, schedule, command)
    on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command returning jobid::bigint $$;
  create function cron.unschedule(job_name text) returns boolean language sql as $$ with d as (delete from cron.job where jobname = job_name returning 1) select count(*) > 0 from d $$;`;

async function fresh(opts: { withNet?: boolean; withCron?: boolean } = {}) {
  db = new PGlite({ extensions: { pg_trgm } });
  await db.exec(`
    create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
    create schema auth; create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
    grant usage on schema auth to anon, authenticated; grant execute on function auth.uid() to anon, authenticated; grant usage on schema public to anon, authenticated, service_role;`);
  if (opts.withNet !== false) await db.exec(NET_STUB);
  if (opts.withCron) await db.exec(CRON_STUB);
  await db.exec(migration('20261008000000_init.sql'));
  await db.exec('grant select, insert, update, delete on all tables in schema public to anon, authenticated;');
  for (const f of ['20261009000000_rls_hardening.sql', '20261013000000_service_role_grants.sql', '20261014000000_service_role_least_privilege.sql', '20261015000000_supabase_cron_revalidation.sql']) {
    await db.exec(migration(f));
  }
  await db.exec("insert into public.job_sources (id, status, attribution, can_redistribute) values ('jobicy','CONDITIONAL','Remote jobs via Jobicy (https://jobicy.com)',true), ('other','READY','x',true)");
}

const OLD = '2026-10-01T00:00:00Z';
async function seedJobs(n: number, o: { source?: string; status?: string; start?: number; stamp?: string } = {}) {
  const src = o.source ?? 'jobicy';
  for (let i = 0; i < n; i++) {
    const ext = String((o.start ?? 1000) + i);
    await db.query(
      `insert into public.jobs (source_id, external_id, company, title, description, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status, salary_min, salary_currency, salary_period, geo_restrictions)
       values ($1,$2,'c','t','d','remote',$3,'https://jobicy.com/jobs/'||$2,'https://jobicy.com/jobs/'||$2,'fp'||$1||$2,$4,100000,'USD','year','{US}')`,
      [src, ext, o.stamp ?? OLD, o.status ?? 'open']);
  }
}
const one = async <T = Record<string, unknown>>(sql: string, p: unknown[] = []) => (await db.query<T>(sql, p)).rows[0]!;
const all = async <T = Record<string, unknown>>(sql: string, p: unknown[] = []) => (await db.query<T>(sql, p)).rows;
const start = async () => (await one<{ r: string }>('select ops.jobicy_revalidate_start() as r')).r;
const collect = async () => (await one<{ r: string }>('select ops.jobicy_revalidate_collect() as r')).r;
const statusBody = (m: Record<string, string>) => JSON.stringify({ apiVersion: 'v2', success: true, statusCode: 200, checkedAt: '2026-10-10T20:00:00+00:00', count: Object.keys(m).length, jobs: Object.entries(m).map(([id, status]) => ({ id: Number(id), status })) });
/** Plays Jobicy: answers the queued request number `n` (0-based, in the order they were queued). */
async function answer(n: number, o: { status?: number; body?: string; timedOut?: boolean } = {}) {
  const req = (await all<{ id: string }>('select id from net._requests order by id'))[n]!;
  await db.query('insert into net._http_response (id, status_code, content, timed_out) values ($1,$2,$3,$4)', [req.id, o.status ?? 200, o.body ?? null, o.timedOut ?? false]);
}
const job = (ext: string) => one<{ status: string; last_checked_at: string; ms: number }>("select status, last_checked_at::text, (extract(epoch from last_checked_at) * 1000)::float8 as ms from public.jobs where source_id='jobicy' and external_id=$1", [ext]);
const run = () => one<Record<string, unknown>>("select status, scope, fetched, upserted, duplicates, closed, http_errors, error_class, finished_at is not null as finished from public.sync_runs where scope='revalidate' order by started_at desc limit 1");
const snapshot = async () => JSON.stringify(await all("select source_id, external_id, status, description, salary_min, geo_restrictions, original_url, canonical_url, fingerprint from public.jobs order by source_id, external_id"));
const asRole = async (role: string, fn: () => Promise<void>) => { await db.exec(`set role ${role}`); try { await fn(); } finally { await db.exec('reset role'); } };

beforeEach(() => fresh());

describe('the lease id is the Worker\'s', () => {
  it('ops.slot_run_id equals slotRunId (TypeScript) for the same source, hour and slot length', async () => {
    for (const iso of ['2026-10-10T12:00:00.000Z', '2026-10-10T12:59:59.999Z', '2026-10-10T13:00:00.000Z', '2026-12-31T23:59:59.000Z', '2027-02-03T04:05:06.000Z']) {
      for (const source of ['jobicy', 'stress-atomic']) {
        const sql = (await one<{ id: string }>('select ops.slot_run_id($1, $2::timestamptz) as id', [source, iso])).id;
        expect(sql, `${source} ${iso}`).toBe(await slotRunId(source, Date.parse(iso), 3_600_000));
      }
    }
  });
});

describe('phase 1: ops.jobicy_revalidate_start()', () => {
  it('takes the lease and queues the status requests: oldest verification first, 100 ids per request, only stored OPEN jobs of jobicy', async () => {
    await seedJobs(250, { stamp: '2026-10-05T00:00:00Z' });
    await seedJobs(1, { start: 5000, stamp: '2026-09-01T00:00:00Z' });                 // the oldest verification: goes first
    await seedJobs(20, { start: 6000, status: 'closed' });                              // closed: never asked about
    await seedJobs(30, { source: 'other', start: 7000 });                               // another source: never asked about
    const before = await snapshot();
    expect(await start()).toBe('started:251 jobs in 3 request(s)');
    const reqs = await all<{ url: string; headers: { Accept: string; 'User-Agent': string }; timeout: number }>('select url, headers, timeout from net._requests order by id');
    expect(reqs).toHaveLength(3);
    const ids = reqs.map((r) => new URL(r.url).searchParams.get('ids')!.split(','));
    expect(ids.map((x) => x.length)).toEqual([100, 100, 51]);
    expect(ids[0]![0]).toBe('5000');                                                    // oldest verification first
    expect(new Set(ids.flat()).size).toBe(251);
    expect(ids.flat().some((id) => Number(id) >= 6000)).toBe(false);
    for (const r of reqs) {
      expect(r.url).toMatch(/^https:\/\/jobicy\.com\/api\/v2\/remote-jobs\/status\?ids=[0-9,]+$/);
      expect(r.headers.Accept).toBe('application/json');
      expect(r.headers['User-Agent']).toMatch(/^OrbiJob-revalidate/);
      expect(r.timeout).toBe(20000);
    }
    expect(await run()).toMatchObject({ status: 'running', scope: 'revalidate', finished: false });
    expect((await one<{ id: string }>("select id from public.sync_runs where scope='revalidate'")).id).toBe((await one<{ id: string }>('select ops.slot_run_id($1, now()) as id', ['jobicy'])).id);
    expect(await all('select batch, array_length(external_ids,1) n from ops.revalidation_batches order by batch')).toEqual([{ batch: 0, n: 100 }, { batch: 1, n: 100 }, { batch: 2, n: 51 }]);
    expect(await snapshot()).toBe(before);                                              // asking changes no job
  });

  it('never puts a malformed id in a URL, and caps one pass at 10 requests (1000 jobs)', async () => {
    await seedJobs(1010, { start: 100000 });
    await db.query("insert into public.jobs (source_id, external_id, company, title, description, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status) values ('jobicy','12,34&x=1','c','t','d','remote',$1,'https://jobicy.com/x','https://jobicy.com/x','fpbad','open')", ['2026-01-01T00:00:00Z']);
    expect(await start()).toBe('started:1000 jobs in 10 request(s)');
    const urls = (await all<{ url: string }>('select url from net._requests')).map((r) => r.url);
    expect(urls.every((u) => /^https:\/\/jobicy\.com\/api\/v2\/remote-jobs\/status\?ids=[0-9,]+$/.test(u))).toBe(true);
  });

  it('a second start in the same hour stands down: running, then too_soon once it finished', async () => {
    await seedJobs(5);
    expect(await start()).toMatch(/^started/);
    expect(await start()).toBe('skipped:running');
    await answer(0, { body: statusBody({ 1000: 'active' }) });
    await collect();
    expect((await run()).status).toBe('ok');
    expect(await start()).toBe('skipped:too_soon');
    expect(await one<{ n: number }>('select count(*)::int n from net._requests')).toEqual({ n: 1 });
  });

  it('the lease is shared with the Worker: a run the Worker/GitHub Actions already holds makes it stand down', async () => {
    await seedJobs(5);
    await db.query("insert into public.sync_runs (id, source_id, scope, started_at, status) values (ops.slot_run_id('jobicy', now()), 'jobicy', 'revalidate', now(), 'running')");
    expect(await start()).toBe('skipped:running');
    expect(await one<{ n: number }>('select count(*)::int n from net._requests')).toEqual({ n: 0 });
  });

  it('a crashed run (running for 20+ minutes) is closed as stale_lock and does not block; a lost race is reported', async () => {
    await seedJobs(5);
    await db.query("insert into public.sync_runs (source_id, scope, started_at, status) values ('jobicy','revalidate', now() - interval '25 minutes','running')");
    expect(await start()).toMatch(/^started/);
    expect(await one("select status, error_class from public.sync_runs where error_class = 'stale_lock'")).toEqual({ status: 'failed', error_class: 'stale_lock' });
    // same slot id already used by a lease-class row: the primary key refuses, nobody runs twice
    await fresh();
    await seedJobs(5);
    await db.query("insert into public.sync_runs (id, source_id, scope, started_at, finished_at, status, error_class) values (ops.slot_run_id('jobicy', now()), 'jobicy', 'revalidate', now() - interval '3 minutes', now(), 'failed', 'stale_lock')");
    expect(await start()).toBe('skipped:lost_race');
  });

  it('nothing stored to revalidate: the run closes ok at once and no request is made', async () => {
    expect(await start()).toBe('ok:nothing_to_revalidate');
    expect(await run()).toMatchObject({ status: 'ok', finished: true });
    expect(await one<{ n: number }>('select count(*)::int n from net._requests')).toEqual({ n: 0 });
  });

  it('a failure while queueing rolls everything back: no stuck lease, nothing recorded', async () => {
    await seedJobs(5);
    await db.exec('drop function net.http_get(text, jsonb, jsonb, int); create function net.http_get(url text, params jsonb default \'{}\', headers jsonb default \'{}\', timeout_milliseconds int default 2000) returns bigint language plpgsql as $$ begin raise exception \'pg_net unavailable\'; end $$;');
    await expect(start()).rejects.toThrow(/pg_net unavailable/);
    expect(await one<{ n: number }>("select count(*)::int n from public.sync_runs where scope='revalidate'")).toEqual({ n: 0 });
  });
});

describe('phase 2: ops.jobicy_revalidate_collect() applies only what Jobicy confirms', () => {
  it('closed -> closed; active -> stamped; unknown, unanswered, and ids that were not asked stay exactly as they were', async () => {
    await seedJobs(6);                                                                  // 1000..1005
    await seedJobs(1, { start: 9999, status: 'closed' });
    await seedJobs(1, { source: 'other', start: 1000 });                                // same external id, another source
    await start();
    const before = await snapshot();
    await answer(0, { body: statusBody({ 1000: 'closed', 1001: 'active', 1002: 'unknown', 1003: 'active', 1005: 'closed', 9999: 'active', 424242: 'closed' }) }); // 1004 not answered
    expect(await collect()).toMatch(/:ok;$/);
    expect((await job('1000')).status).toBe('closed');
    expect((await job('1005')).status).toBe('closed');
    expect(await job('1001')).toMatchObject({ status: 'open' });
    expect((await job('1001')).ms).toBeGreaterThan(Date.parse(OLD));
    expect((await job('1003')).ms).toBeGreaterThan(Date.parse(OLD));
    for (const id of ['1002', '1004']) expect(await job(id)).toMatchObject({ status: 'open', last_checked_at: '2026-10-01 00:00:00+00' });
    expect((await job('9999')).status).toBe('closed');                                   // asked about? no: it was closed, not in the batch; stays closed
    expect(await one("select status, last_checked_at::text from public.jobs where source_id='other' and external_id='1000'")).toMatchObject({ status: 'open' });
    expect(await run()).toMatchObject({ status: 'ok', fetched: 0, upserted: 0, duplicates: 0, closed: 2, http_errors: 0, error_class: null, finished: true });
    expect(await one('select closed, confirmed, unknown, outcome, http_status from ops.revalidation_batches')).toEqual({ closed: 2, confirmed: 2, unknown: 2, outcome: 'applied', http_status: 200 });
    // nothing but status/last_checked_at of the jobs changed; nothing was inserted or deleted
    const after = JSON.parse(await snapshot()) as Record<string, unknown>[];
    const was = JSON.parse(before) as Record<string, unknown>[];
    expect(after).toHaveLength(was.length);
    for (let i = 0; i < was.length; i++) expect({ ...after[i], status: null }).toEqual({ ...was[i], status: null });
  });

  it('a real Jobicy status payload (sanitized fixture) is understood', async () => {
    await seedJobs(2, { start: 154956 });                                              // ids of the fixture
    await start();
    const jobs = (statusFixture as { jobs: { id: number; status: string }[] }).jobs;
    expect(jobs.length).toBeGreaterThan(0);
    await answer(0, { body: JSON.stringify(statusFixture) });
    expect(await collect()).toMatch(/:ok;$/);
    const decided = await one<{ closed: number; confirmed: number }>('select closed, confirmed from ops.revalidation_batches');
    expect(decided.closed + decided.confirmed).toBeLessThanOrEqual(2);
  });

  it('answers still missing: it waits (the run stays running); after 30 minutes the missing ones are timeouts', async () => {
    await seedJobs(150);                                                               // 2 requests
    await start();
    await answer(0, { body: statusBody({ 1000: 'closed' }) });
    expect(await collect()).toMatch(/waiting\(1\)/);
    expect((await run()).status).toBe('running');
    expect((await job('1000')).status).toBe('open');                                    // nothing applied while waiting
    await db.query("update public.sync_runs set started_at = now() - interval '31 minutes' where scope='revalidate'");
    expect(await collect()).toMatch(/:partial;$/);
    expect(await run()).toMatchObject({ status: 'partial', closed: 1, http_errors: 1, error_class: 'timeout', finished: true });
    expect((await job('1000')).status).toBe('closed');                                  // the answered batch stays proven
    expect((await job('1100')).status).toBe('open');                                    // the unanswered one untouched
  });

  it.each([
    ['HTTP 500', { status: 500, body: '{}' }, 'http_error', 'http_500'],
    ['HTTP 429', { status: 429, body: '{}' }, 'http_error', 'http_429'],
    ['timed out', { timedOut: true, status: 0 }, 'timeout', 'timeout'],
    ['not JSON', { body: '<html>oops</html>' }, 'bad_response', 'network_or_parse'],
    ['success false', { body: JSON.stringify({ success: false, jobs: [{ id: 1000, status: 'closed' }] }) }, 'bad_response', 'network_or_parse'],
    ['no jobs array', { body: JSON.stringify({ success: true }) }, 'bad_response', 'network_or_parse'],
    ['null body', { body: 'null' }, 'bad_response', 'network_or_parse'],
  ])('%s: nothing is closed or stamped, the run is FAILED, never a silent success', async (_n, resp, outcome, errorClass) => {
    await seedJobs(3);
    await start();
    await answer(0, resp as { status?: number; body?: string; timedOut?: boolean });
    const before = await snapshot();
    expect(await collect()).toMatch(/:failed;$/);
    expect(await snapshot()).toBe(before);
    expect((await job('1000')).last_checked_at).toBe('2026-10-01 00:00:00+00');
    expect(await run()).toMatchObject({ status: 'failed', closed: 0, http_errors: 1, error_class: errorClass, finished: true });
    expect((await one<{ outcome: string }>('select outcome from ops.revalidation_batches')).outcome).toBe(outcome);
  });

  it('one batch fails, the other succeeds: partial, and only the successful batch is applied', async () => {
    await seedJobs(150);
    await start();
    await answer(0, { body: statusBody({ 1000: 'closed' }) });
    await answer(1, { status: 503, body: '{}' });
    expect(await collect()).toMatch(/:partial;$/);
    expect(await run()).toMatchObject({ status: 'partial', closed: 1, http_errors: 1, error_class: 'http_503' });
    expect((await job('1000')).status).toBe('closed');
    expect((await job('1120')).status).toBe('open');
  });

  it('running it again changes nothing (idempotent), and a closed job is never reopened or re-stamped by a later answer', async () => {
    await seedJobs(3);
    await start();
    await answer(0, { body: statusBody({ 1000: 'closed', 1001: 'active' }) });
    await collect();
    const done = await snapshot();
    const stamp = (await job('1001')).last_checked_at;
    expect(await collect()).toBe('nothing_to_collect');
    expect(await snapshot()).toBe(done);
    expect((await job('1001')).last_checked_at).toBe(stamp);
  });

  it('runs that this mechanism did not start (Worker / GitHub Actions rows) are left alone', async () => {
    await db.query("insert into public.sync_runs (source_id, scope, started_at, status) values ('jobicy','revalidate', now() - interval '2 minutes','running')");
    expect(await collect()).toBe('nothing_to_collect');
    expect((await run()).status).toBe('running');
  });

  it('nobody but the owner can run it or read its log: anon, authenticated and service_role are refused', async () => {
    await seedJobs(2);
    await start();
    for (const role of ['anon', 'authenticated', 'service_role']) {
      await asRole(role, async () => {
        await expect(db.query('select ops.jobicy_revalidate_start()')).rejects.toThrow(/permission denied/);
        await expect(db.query('select ops.jobicy_revalidate_collect()')).rejects.toThrow(/permission denied/);
        await expect(db.query('select * from ops.revalidation_batches')).rejects.toThrow(/permission denied/);
        await expect(db.query('select ops.slot_run_id($1, now())', ['jobicy'])).rejects.toThrow(/permission denied/);
      });
    }
  });

  it('never touches the source flag, user data or the other tables', async () => {
    await seedJobs(3);
    await db.exec("insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000aa')");
    await start();
    await answer(0, { body: statusBody({ 1000: 'closed', 1001: 'active' }) });
    await collect();
    expect(await all('select id, can_redistribute, status, attribution from public.job_sources order by id')).toEqual([
      { id: 'jobicy', can_redistribute: true, status: 'CONDITIONAL', attribution: 'Remote jobs via Jobicy (https://jobicy.com)' },
      { id: 'other', can_redistribute: true, status: 'READY', attribution: 'x' },
    ]);
    expect(await one<{ n: number }>('select count(*)::int n from public.jobs')).toEqual({ n: 3 });
    expect(await one<{ n: number }>('select count(*)::int n from auth.users')).toEqual({ n: 1 });
  });
});

describe('closing keeps what users saved', () => {
  it('a favourite and an application stay linked when their job is closed by the revalidation', async () => {
    await seedJobs(2);
    await db.exec("insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000aa')");
    const j = (await one<{ id: string }>("select id from public.jobs where external_id='1000'")).id;
    await db.query("insert into public.saved_jobs (user_id, job_id) values ('00000000-0000-0000-0000-0000000000aa', $1)", [j]);
    await db.query("insert into public.applications (user_id, job_id, job_snapshot, stage) values ('00000000-0000-0000-0000-0000000000aa', $1, '{\"title\":\"t\"}', 'applied')", [j]);
    await start();
    await answer(0, { body: statusBody({ 1000: 'closed', 1001: 'closed' }) });
    await collect();
    expect((await job('1000')).status).toBe('closed');
    expect(await one<{ s: number; a: number; linked: number }>('select (select count(*)::int from saved_jobs) s, (select count(*)::int from applications) a, (select count(*)::int from applications where job_id is not null) linked')).toEqual({ s: 1, a: 1, linked: 1 });
  });
});

describe('scheduling is a separate, guarded step', () => {
  it('the migration itself schedules NOTHING', async () => {
    await fresh({ withCron: false });
    await db.exec(CRON_STUB);
    expect(await all('select * from cron.job')).toEqual([]);
    expect(migration('20261015000000_supabase_cron_revalidation.sql')).not.toMatch(/cron\.schedule/);
  });

  it('enable refuses without the owner\'s switch, without pg_cron, without pg_net and without the migration; and schedules nothing then', async () => {
    await fresh({ withCron: true });
    await expect(db.exec(ENABLE)).rejects.toThrow(/autorizacao explicita/);
    await db.exec('rollback').catch(() => {});
    await expect(db.exec(`set orbijob.enable_revalidation_cron = 'sim'; ${ENABLE}`)).rejects.toThrow(/autorizacao explicita/);
    await db.exec('rollback').catch(() => {});
    expect(await all('select * from cron.job')).toEqual([]);
    await fresh({ withNet: false, withCron: true });
    await expect(db.exec(`${SWITCH} ${ENABLE}`)).rejects.toThrow(/pg_net/);
    await db.exec('rollback').catch(() => {});
    await fresh();                                                                      // no cron schema at all
    await expect(db.exec(`${SWITCH} ${ENABLE}`)).rejects.toThrow(/pg_cron/);
    await db.exec('rollback').catch(() => {});
  });

  it('enable schedules exactly the three jobs with the documented times (idempotent); disable removes them and nothing else', async () => {
    await fresh({ withCron: true });
    await db.exec(`${SWITCH} ${ENABLE}`);
    await db.exec(`${SWITCH} ${ENABLE}`);                                               // again: same three, no duplicates
    expect(await all('select jobname, schedule, command from cron.job order by jobname')).toEqual([
      { jobname: 'jobicy-revalidate-collect', schedule: '19,21,24,29,44 */6 * * *', command: 'select ops.jobicy_revalidate_collect()' },
      { jobname: 'jobicy-revalidate-start', schedule: '17 */6 * * *', command: 'select ops.jobicy_revalidate_start()' },
      { jobname: 'ops-cron-history-purge', schedule: '7 3 * * *', command: "delete from cron.job_run_details where end_time < now() - interval '14 days'" },
    ]);
    await db.exec("insert into cron.job (jobname, schedule, command) values ('someone-elses-job', '* * * * *', 'select 1')");
    await db.exec(DISABLE);
    await db.exec(DISABLE);                                                             // idempotent
    expect(await all('select jobname from cron.job')).toEqual([{ jobname: 'someone-elses-job' }]);
  });

  it('disable works where pg_cron does not exist (nothing to do, no error)', async () => {
    await fresh();
    await db.exec(DISABLE);
  });

  it('the rollback script removes the schema and the jobs but leaves jobs, sync_runs rows and the extensions alone', async () => {
    await fresh({ withCron: true });
    await seedJobs(2);
    await db.exec(`${SWITCH} ${ENABLE}`);
    await start();
    const down = file('supabase/rollback/20261015000000_supabase_cron_revalidation.down.sql');
    expect(down).not.toMatch(/drop extension|drop table public|delete from public|truncate/i);
    await db.exec(down);
    expect(await all('select * from cron.job')).toEqual([]);
    expect((await one<{ n: number }>("select count(*)::int n from pg_namespace where nspname = 'ops'")).n).toBe(0);
    expect(await one<{ n: number }>('select count(*)::int n from public.jobs')).toEqual({ n: 2 });
    expect(await one<{ n: number }>("select count(*)::int n from public.sync_runs where scope='revalidate'")).toEqual({ n: 1 });
  });
});
