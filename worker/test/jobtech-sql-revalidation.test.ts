import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';

/**
 * Migration 20261020000000: the Platsbanken is revalidated INSIDE the database (pg_cron + pg_net), and 'unknown' jobs keep their text for 30 days.
 * Real schema in PGlite with every migration applied; `net` and `cron` are stand-ins and the tests play the part of the Platsbanken by writing
 * the answers into `net._http_response`. Nothing here touches a hosted project.
 */
const file = (p: string) => readFileSync(new URL(`../../${p}`, import.meta.url), 'utf8');
const ENABLE = file('scripts/supabase/ops/enable_jobtech_revalidation_cron.sql');
const DISABLE = file('scripts/supabase/ops/disable_jobtech_revalidation_cron.sql');
const DOWN = file('supabase/rollback/20261020000000_jobtech_revalidation.down.sql');
const SWITCH = "set orbijob.enable_jobtech_revalidation = 'EU-AUTORIZO-A-REVALIDACAO-AUTOMATICA';";
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
const STORAGE_STUB = `
  create schema storage;
  create table storage.buckets (id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets(id), name text, owner uuid);
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[] language sql as $$ select string_to_array(name, '/') $$;
  grant usage on schema storage to anon, authenticated, service_role;`;

beforeEach(async () => {
  db = new PGlite({ extensions: { pg_trgm } });
  await db.exec(`
    create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
    create schema auth; create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
    grant usage on schema auth to anon, authenticated; grant execute on function auth.uid() to anon, authenticated; grant usage on schema public to anon, authenticated, service_role;`);
  await db.exec(NET_STUB + CRON_STUB + STORAGE_STUB);
  const dir = new URL('../../supabase/migrations/', import.meta.url);
  for (const f of readdirSync(dir).sort()) {
    await db.exec(readFileSync(new URL(f, dir), 'utf8'));
    if (f.startsWith('20261008')) await db.exec('grant select, insert, update, delete on all tables in schema public to anon, authenticated;');
  }
  await db.exec(`insert into public.job_sources (id, status, attribution, can_redistribute) values
    ('jobtech','CONDITIONAL','Jobs via Platsbanken (https://arbetsformedlingen.se)',true),
    ('arbeitnow','CONDITIONAL','Jobs via Arbeitnow (https://www.arbeitnow.com)',true),
    ('jobicy','CONDITIONAL','Remote jobs via Jobicy (https://jobicy.com)',true)`);
});

const one = async <T = Record<string, unknown>>(sql: string, p: unknown[] = []) => (await db.query<T>(sql, p)).rows[0]!;
const all = async <T = Record<string, unknown>>(sql: string, p: unknown[] = []) => (await db.query<T>(sql, p)).rows;
const OLD = '2026-10-01T00:00:00Z';
async function seed(n: number, o: { source?: string; status?: string; start?: number; stamp?: string; desc?: string } = {}) {
  const src = o.source ?? 'jobtech';
  for (let i = 0; i < n; i++) {
    const ext = String((o.start ?? 1000) + i);
    await db.query(
      `insert into public.jobs (source_id, external_id, company, title, description, requirements, skills, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status, published_at)
       values ($1,$2,'c','t '||$2,$3,'{"x"}','{"y"}','onsite',$4,'https://arbetsformedlingen.se/platsbanken/annonser/'||$2,'https://arbetsformedlingen.se/platsbanken/annonser/'||$2,'fp'||$1||$2,$5, now() - interval '5 days')`,
      [src, ext, o.desc ?? 'a long description', o.stamp ?? OLD, o.status ?? 'open']);
  }
}
const start = async () => (await one<{ r: string }>('select ops.jobtech_revalidate_start() as r')).r;
const collect = async () => (await one<{ r: string }>('select ops.jobtech_revalidate_collect() as r')).r;
const job = (ext: string) => one<{ status: string; ms: number; description: string }>("select status, (extract(epoch from last_checked_at) * 1000)::float8 as ms, description from public.jobs where source_id='jobtech' and external_id=$1", [ext]);
const run = () => one<Record<string, unknown>>("select status, scope, closed, http_errors, error_class, finished_at is not null as finished from public.sync_runs where source_id='jobtech' and scope='revalidate' order by started_at desc limit 1");
/** Plays the Platsbanken for the request that asked about `ext`. */
async function answer(ext: string, o: { status?: number; body?: unknown; timedOut?: boolean; raw?: string } = {}) {
  const req = await one<{ id: string }>('select id from net._requests where url like $1 order by id desc limit 1', [`%/ad/${ext}`]);
  await db.query('insert into net._http_response (id, status_code, content, timed_out) values ($1,$2,$3,$4)', [req.id, o.status ?? 200, o.raw ?? (o.body === undefined ? null : JSON.stringify(o.body)), o.timedOut ?? false]);
}
const live = (id: string, over: Record<string, unknown> = {}) => ({ id, removed: false, last_publication_date: '2999-01-01T23:59:59', ...over });

describe('ops.jobtech_revalidate_start()', () => {
  it('queues one GET /ad/{id} per stored open or unknown job, oldest verification first, 600 at most; never closed jobs or other sources', async () => {
    await seed(700, { stamp: '2026-10-05T00:00:00Z' });
    await seed(1, { start: 9000, stamp: '2026-09-01T00:00:00Z' });          // the oldest: first
    await seed(1, { start: 9100, status: 'unknown', stamp: '2026-09-02T00:00:00Z' }); // unknown ones are asked about too (they can come back)
    await seed(20, { start: 7000, status: 'closed' });
    await seed(30, { source: 'arbeitnow', start: 8000 });
    expect(await start()).toBe('started:600 jobs in 600 request(s)');
    const reqs = await all<{ url: string; headers: Record<string, string>; timeout: number }>('select url, headers, timeout from net._requests order by id');
    expect(reqs).toHaveLength(600);
    expect(reqs[0]!.url).toBe('https://jobsearch.api.jobtechdev.se/ad/9000');
    expect(reqs[1]!.url).toBe('https://jobsearch.api.jobtechdev.se/ad/9100');
    expect(new Set(reqs.map((r) => r.url)).size).toBe(600);
    for (const r of reqs) {
      expect(r.url).toMatch(/^https:\/\/jobsearch\.api\.jobtechdev\.se\/ad\/[1-9][0-9]*$/);
      expect(r.headers['User-Agent']).toMatch(/^OrbiJob-revalidate/);
      expect(r.timeout).toBe(20000);
    }
    expect(reqs.some((r) => /\/ad\/(7\d{3}|8\d{3})$/.test(r.url) && Number(r.url.split('/').pop()) >= 7000 && Number(r.url.split('/').pop()) < 7020)).toBe(false);
    const r = await run();
    expect(r).toMatchObject({ status: 'running', scope: 'revalidate' });
  });

  it('only plain numeric ids ever reach a URL', async () => {
    await seed(2);
    await db.query(`insert into public.jobs (source_id, external_id, company, title, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status)
      values ('jobtech','../x?y=1','c','t','onsite', now(),'https://arbetsformedlingen.se/a','https://arbetsformedlingen.se/a','fp-bad','open')`);
    expect(await start()).toBe('started:2 jobs in 2 request(s)');
  });

  it('stands down for the lease: a run in progress, a pass in the last hour (any scope), and a second start in the same hour', async () => {
    await seed(3);
    expect(await start()).toMatch(/^started:/);
    expect(await start()).toBe('skipped:running');
    for (const id of ['1000', '1001', '1002']) await answer(id, { body: live(id) });
    await collect();
    expect(await start()).toBe('skipped:too_soon');
  });

  it('does nothing when there is nothing to ask', async () => {
    expect(await start()).toBe('ok:nothing_to_revalidate');
    expect(await run()).toMatchObject({ status: 'ok', finished: true });
  });

  it('is closed to the API roles', async () => {
    for (const role of ['anon', 'authenticated', 'service_role']) {
      await db.exec(`set role ${role}`);
      await expect(db.query('select ops.jobtech_revalidate_start()')).rejects.toThrow();
      await expect(db.query('select ops.jobtech_revalidate_collect()')).rejects.toThrow();
      await db.exec('reset role');
    }
  });
});

describe('ops.jobtech_revalidate_collect()', () => {
  it('404 and 410 close; removed=true and an ended publication window close; a published ad is confirmed; nothing else is touched', async () => {
    await seed(6);
    await start();
    await answer('1000', { status: 404, raw: '{"message":"Ad not found"}' });
    await answer('1001', { status: 410 });
    await answer('1002', { body: live('1002', { removed: true }) });
    await answer('1003', { body: live('1003', { last_publication_date: '2020-01-01T23:59:59' }) });
    await answer('1004', { body: live('1004') });
    await answer('1005', { body: live('1005', { last_publication_date: new Date(Date.now() + 86_400_000).toISOString().slice(0, 19) }) });
    const out = await collect();
    expect(out).toMatch(/:ok;$/);
    for (const id of ['1000', '1001', '1002', '1003']) expect((await job(id)).status, id).toBe('closed');
    for (const id of ['1004', '1005']) {
      const j = await job(id);
      expect(j.status).toBe('open');
      expect(Date.now() - j.ms).toBeLessThan(60_000); // stamped now
    }
    expect(await run()).toMatchObject({ status: 'ok', closed: 4, http_errors: 0, finished: true });
    expect((await job('1000')).description).toBe('a long description'); // closing never compacts
  });

  it('403, 429, 5xx, a timeout, an unreadable answer and no answer change NOTHING: no closure, no confirmation; the run says so', async () => {
    await seed(7);
    await start();
    await answer('1000', { status: 403, raw: '{}' });
    await answer('1001', { status: 429, raw: '{}' });
    await answer('1002', { status: 503, raw: 'boom' });
    await answer('1003', { timedOut: true, status: 0 });
    await answer('1004', { raw: '<html>not json</html>' });
    await answer('1005', { raw: '{"removed": false}' }); // 200 without an id
    // 1006: never answered
    await db.exec("update public.sync_runs set started_at = now() - interval '31 minutes' where scope = 'revalidate'");
    const before = await all("select external_id, status, last_checked_at from public.jobs order by external_id");
    await collect();
    expect(await all("select external_id, status, last_checked_at from public.jobs order by external_id")).toEqual(before);
    expect(await run()).toMatchObject({ status: 'failed', closed: 0, http_errors: 7, finished: true });
  });

  it('a mixed run is partial: what the answers proved is applied, what failed is left alone', async () => {
    await seed(4);
    await start();
    await answer('1000', { status: 404 });
    await answer('1001', { body: live('1001') });
    await answer('1002', { status: 500, raw: 'x' });
    await answer('1003', { body: live('1003') });
    await collect();
    expect((await job('1000')).status).toBe('closed');
    expect((await job('1001')).status).toBe('open');
    expect((await job('1002')).ms).toBe(Date.parse(OLD));
    expect(await run()).toMatchObject({ status: 'partial', closed: 1, http_errors: 1 });
  });

  it('waits for pending answers (up to 30 minutes) and is idempotent once the run is closed', async () => {
    await seed(2);
    await start();
    await answer('1000', { body: live('1000') });
    expect(await collect()).toMatch(/waiting\(1\)/);
    expect((await run()).status).toBe('running');
    await answer('1001', { body: live('1001') });
    expect(await collect()).toMatch(/:ok;$/);
    expect(await collect()).toBe('nothing_to_collect');
  });

  it('an unknown job that is still published comes BACK to open with its text; one that is gone is closed', async () => {
    await seed(2, { status: 'unknown' });
    await start();
    await answer('1000', { body: live('1000') });
    await answer('1001', { status: 404 });
    await collect();
    expect(await job('1000')).toMatchObject({ status: 'open', description: 'a long description' });
    expect((await job('1001')).status).toBe('closed');
  });

  it('never reopens a CLOSED job, even if the source answers 200 for it', async () => {
    await seed(1, { status: 'closed', stamp: OLD });
    // a closed job is not even asked about
    expect(await start()).toBe('ok:nothing_to_revalidate');
    expect((await job('1000')).status).toBe('closed');
  });

  it('a pass that finds a job closed meanwhile (by another writer) does not touch it', async () => {
    await seed(1);
    await start();
    await db.exec("update public.jobs set status = 'closed' where external_id = '1000'");
    await answer('1000', { body: live('1000') });
    await collect();
    expect((await job('1000')).status).toBe('closed');
  });

  it('thousands of ads: 600 per run, every run starts with the least recently verified, and the next run reaches the rest', async () => {
    await seed(1500);
    await start();
    const firstBatch = new Set((await all<{ url: string }>('select url from net._requests')).map((r) => r.url.split('/').pop()!));
    for (const id of firstBatch) await answer(id, Number(id) % 50 === 0 ? { status: 404 } : { body: live(id) });
    await collect();
    expect(await one<{ n: string }>("select count(*)::int as n from public.jobs where source_id='jobtech' and status='closed'")).toMatchObject({ n: 12 });
    expect(await one<{ n: string }>("select count(*)::int as n from public.jobs where source_id='jobtech' and status='open' and last_checked_at > now() - interval '1 minute'")).toMatchObject({ n: 588 });
    await db.exec("delete from public.sync_runs where scope = 'revalidate'"); // (a later hour has another lease id in real life)
    await db.exec('delete from net._requests');
    await start();
    const second = new Set((await all<{ url: string }>('select url from net._requests')).map((r) => r.url.split('/').pop()!));
    expect(second.size).toBe(600);
    expect([...second].every((id) => !firstBatch.has(id))).toBe(true); // the never-verified ones go first
  });

  it('leaves other sources, users and the source row alone', async () => {
    await seed(2);
    await seed(2, { source: 'arbeitnow', start: 5000 });
    const others = JSON.stringify(await all("select * from public.jobs where source_id <> 'jobtech' order by external_id"));
    const src = JSON.stringify(await all('select * from public.job_sources order by id'));
    await start();
    await answer('1000', { status: 404 });
    await answer('1001', { body: live('1001') });
    await collect();
    expect(JSON.stringify(await all("select * from public.jobs where source_id <> 'jobtech' order by external_id"))).toBe(others);
    expect(JSON.stringify(await all('select * from public.job_sources order by id'))).toBe(src);
  });
});

describe('retention of unknown jobs (30 days, not 14)', () => {
  const ret = async () => (await one<{ r: string }>("select ops.jobicy_retention_apply('EU-AUTORIZO-A-RETENCAO', interval '14 days', interval '90 days', 200, true) as r")).r;
  it('closed: compacted after 14 days; unknown: kept with its text until 30 days; both deleted after 90 when unreferenced; open never touched', async () => {
    const age = (d: number) => new Date(Date.now() - d * 86_400_000).toISOString();
    await seed(1, { start: 100, status: 'closed', stamp: age(20) });
    await seed(1, { start: 200, status: 'unknown', stamp: age(20) });   // inside the 30 days: text kept
    await seed(1, { start: 300, status: 'unknown', stamp: age(40) });   // beyond: compacted
    await seed(1, { start: 400, status: 'unknown', stamp: age(120) });  // beyond 90: deleted
    await seed(1, { start: 500, status: 'open', stamp: age(200) });
    expect(await ret()).toBe('ok:compacted=2,deleted=1');
    expect((await job('100')).description).toBe('');
    expect((await job('200')).description).toBe('a long description');
    expect((await job('300')).description).toBe('');
    expect(await one("select count(*)::int as n from public.jobs where external_id = '400'")).toMatchObject({ n: 0 });
    expect((await job('500')).description).toBe('a long description');
  });

  it('an unknown job referenced by a favourite is never deleted', async () => {
    await db.exec("insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1')");
    await seed(1, { start: 400, status: 'unknown', stamp: new Date(Date.now() - 120 * 86_400_000).toISOString() });
    const id = (await one<{ id: string }>("select id from public.jobs where external_id = '400'")).id;
    await db.query("insert into public.saved_jobs (user_id, job_key, job_id, snapshot) values ('00000000-0000-0000-0000-0000000000a1', 'k', $1, '{}')", [id]);
    await ret();
    expect(await one("select count(*)::int as n from public.jobs where external_id = '400'")).toMatchObject({ n: 1 });
  });

  it('the plan counts unknown jobs by the same rule', async () => {
    const age = (d: number) => new Date(Date.now() - d * 86_400_000).toISOString();
    await seed(1, { start: 200, status: 'unknown', stamp: age(20) });
    await seed(1, { start: 300, status: 'unknown', stamp: age(40) });
    const plan = Object.fromEntries((await all<{ layer: string; jobs: string }>("select layer, jobs::int from ops.jobicy_retention_plan(interval '14 days', interval '90 days')")).map((x) => [x.layer, Number(x.jobs)]));
    expect(plan).toMatchObject({ closed_recent: 1, closed_to_compact: 1, open: 0 });
  });
});

describe('scheduling and rollback', () => {
  it('the migration schedules nothing; the enable script needs the phrase and schedules start + collect; disable removes them', async () => {
    expect(await all('select * from cron.job')).toHaveLength(0);
    await expect(db.exec(ENABLE)).rejects.toThrow(/autorizacao/);
    await db.exec(SWITCH + ENABLE);
    const jobs = await all<{ jobname: string; schedule: string; command: string }>('select jobname, schedule, command from cron.job order by jobname');
    expect(jobs.map((j) => j.jobname)).toEqual(['jobtech-revalidate-collect', 'jobtech-revalidate-start']);
    expect(jobs.find((j) => j.jobname === 'jobtech-revalidate-start')).toMatchObject({ schedule: '7 2,8,14,20 * * *', command: 'select ops.jobtech_revalidate_start()' });
    await db.exec(DISABLE);
    expect(await all('select * from cron.job')).toHaveLength(0);
  });

  it('the scheduled commands run as written', async () => {
    await seed(2);
    await db.exec(SWITCH + ENABLE);
    for (const j of await all<{ command: string }>('select command from cron.job order by jobname')) await db.exec(j.command);
  });

  it('the rollback drops the two functions and puts the 14/14 retention back; no job is touched', async () => {
    await seed(1, { start: 200, status: 'unknown', stamp: new Date(Date.now() - 20 * 86_400_000).toISOString() });
    await db.exec(DOWN);
    await expect(db.query('select ops.jobtech_revalidate_start()')).rejects.toThrow();
    expect((await job('200')).status).toBe('unknown');
    expect((await one<{ r: string }>("select ops.jobicy_retention_apply('EU-AUTORIZO-A-RETENCAO', interval '14 days', interval '90 days', 200, true) as r")).r).toBe('ok:compacted=1,deleted=0'); // migration 12's rule again
  });
});
