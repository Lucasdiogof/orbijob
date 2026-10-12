import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';

/**
 * Migration 20261022000000: Jobs.co.nz (New Zealand) is revalidated INSIDE the database (pg_cron + pg_net).
 * Real schema in PGlite with every migration applied; `net` and `cron` are stand-ins and the tests play the part of the Platsbanken by writing
 * the answers into `net._http_response`. Nothing here touches a hosted project.
 */
const file = (p: string) => readFileSync(new URL(`../../${p}`, import.meta.url), 'utf8');
const ENABLE = file('scripts/supabase/ops/enable_jobsconz_revalidation_cron.sql');
const DISABLE = file('scripts/supabase/ops/disable_jobsconz_revalidation_cron.sql');
const DOWN = file('supabase/rollback/20261022000000_jobsconz_revalidation.down.sql');
const SWITCH = "set orbijob.enable_jobsconz_revalidation = 'EU-AUTORIZO-A-REVALIDACAO-AUTOMATICA';";
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
    ('jobsconz','CONDITIONAL','Jobs via Jobs.co.nz (https://jobs.co.nz)',true), ('jobtech','CONDITIONAL','Jobs via Platsbanken (https://arbetsformedlingen.se)',true),
    ('arbeitnow','CONDITIONAL','Jobs via Arbeitnow (https://www.arbeitnow.com)',true),
    ('jobicy','CONDITIONAL','Remote jobs via Jobicy (https://jobicy.com)',true)`);
});

const one = async <T = Record<string, unknown>>(sql: string, p: unknown[] = []) => (await db.query<T>(sql, p)).rows[0]!;
const all = async <T = Record<string, unknown>>(sql: string, p: unknown[] = []) => (await db.query<T>(sql, p)).rows;
const OLD = '2026-10-01T00:00:00Z';
async function seed(n: number, o: { source?: string; status?: string; start?: number; stamp?: string; desc?: string } = {}) {
  const src = o.source ?? 'jobsconz';
  for (let i = 0; i < n; i++) {
    const ext = String((o.start ?? 1000) + i);
    await db.query(
      `insert into public.jobs (source_id, external_id, company, title, description, requirements, skills, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status, published_at)
       values ($1,$2,'c','t '||$2,$3,'{"x"}','{"y"}','onsite',$4,'https://jobs.co.nz/jobs/'||$2||'/x','https://jobs.co.nz/jobs/'||$2||'/x','fp'||$1||$2,$5, now() - interval '5 days')`,
      [src, ext, o.desc ?? 'a long description', o.stamp ?? OLD, o.status ?? 'open']);
  }
}
const start = async () => (await one<{ r: string }>('select ops.jobsconz_revalidate_start() as r')).r;
const collect = async () => (await one<{ r: string }>('select ops.jobsconz_revalidate_collect() as r')).r;
const job = (ext: string) => one<{ status: string; ms: number; description: string }>("select status, (extract(epoch from last_checked_at) * 1000)::float8 as ms, description from public.jobs where source_id='jobsconz' and external_id=$1", [ext]);
const run = () => one<Record<string, unknown>>("select status, scope, closed, http_errors, error_class, finished_at is not null as finished from public.sync_runs where source_id='jobsconz' and scope='revalidate' order by started_at desc limit 1");
/** Plays the Platsbanken for the request that asked about `ext`. */
async function answer(ext: string, o: { status?: number; body?: unknown; timedOut?: boolean; raw?: string } = {}) {
  const req = await one<{ id: string }>('select id from net._requests where url like $1 order by id desc limit 1', [`%/api/v1/jobs/${ext}`]);
  await db.query('insert into net._http_response (id, status_code, content, timed_out) values ($1,$2,$3,$4)', [req.id, o.status ?? 200, o.raw ?? (o.body === undefined ? null : JSON.stringify(o.body)), o.timedOut ?? false]);
}



const live = (id: string, over: Record<string, unknown> = {}) => ({ data: { id: Number(id), expires_at: '2999-01-01T00:00:00', ...over } });

describe('ops.jobsconz_revalidate_start()', () => {
  it('queues one GET /api/v1/jobs/{id} per stored open or unknown job, oldest verification first, 100 at most; never closed jobs or other sources', async () => {
    await seed(150, { stamp: '2026-10-05T00:00:00Z' });
    await seed(1, { start: 9000, stamp: '2026-09-01T00:00:00Z' });
    await seed(1, { start: 9100, status: 'unknown', stamp: '2026-09-02T00:00:00Z' });
    await seed(20, { start: 7000, status: 'closed' });
    await seed(30, { source: 'arbeitnow', start: 8000 });
    expect(await start()).toBe('started:100 jobs in 100 request(s)');
    const reqs = await all<{ url: string; headers: Record<string, string>; timeout: number }>('select url, headers, timeout from net._requests order by id');
    expect(reqs).toHaveLength(100); // never above the 120 requests a minute the API allows without a key
    expect(reqs[0]!.url).toBe('https://jobs.co.nz/api/v1/jobs/9000');
    expect(reqs[1]!.url).toBe('https://jobs.co.nz/api/v1/jobs/9100');
    for (const r of reqs) {
      expect(r.url).toMatch(/^https:\/\/jobs\.co\.nz\/api\/v1\/jobs\/[1-9][0-9]*$/);
      expect(r.headers['User-Agent']).toMatch(/^OrbiJob-revalidate/);
      expect(r.timeout).toBe(20000);
    }
  });

  it('does nothing when there is nothing to ask, and stands down for a run in progress', async () => {
    expect(await start()).toBe('ok:nothing_to_revalidate');
    await seed(3);
    await db.exec('delete from public.sync_runs');
    expect(await start()).toMatch(/^started:/);
    expect(await start()).toBe('skipped:running');
  });

  it('is closed to the API roles', async () => {
    for (const role of ['anon', 'authenticated', 'service_role']) {
      await db.exec(`set role ${role}`);
      await expect(db.query('select ops.jobsconz_revalidate_start()')).rejects.toThrow();
      await expect(db.query('select ops.jobsconz_revalidate_collect()')).rejects.toThrow();
      await db.exec('reset role');
    }
  });
});

describe('ops.jobsconz_revalidate_collect()', () => {
  it('404 closes; an expired listing closes; a live one is confirmed and stamped; 403/429/5xx/timeout/garbage change nothing', async () => {
    await seed(8);
    await start();
    await answer('1000', { status: 404, raw: '{"error":{"code":"not_found"}}' });
    await answer('1001', { body: live('1001', { expires_at: '2020-01-01T00:00:00' }) });
    await answer('1002', { body: live('1002') });
    await answer('1003', { status: 403, raw: '{}' });
    await answer('1004', { status: 429, raw: '{}' });
    await answer('1005', { status: 503, raw: 'x' });
    await answer('1006', { timedOut: true, status: 0 });
    await answer('1007', { raw: '<html>not json</html>' });
    await collect();
    expect((await job('1000')).status).toBe('closed');
    expect((await job('1001')).status).toBe('closed');
    const confirmed = await job('1002');
    expect(confirmed.status).toBe('open');
    expect(Date.now() - confirmed.ms).toBeLessThan(60_000);
    for (const id of ['1003', '1004', '1005', '1006', '1007']) {
      const j = await job(id);
      expect(j.status, id).toBe('open');
      expect(j.ms, id).toBe(Date.parse(OLD));
    }
    expect(await run()).toMatchObject({ status: 'partial', closed: 2, http_errors: 5, finished: true });
  });

  it('an unknown listing that is still live comes back to open with its text; a closed one is never asked about', async () => {
    await seed(1, { status: 'unknown' });
    await seed(1, { start: 2000, status: 'closed' });
    expect(await start()).toBe('started:1 jobs in 1 request(s)');
    await answer('1000', { body: live('1000') });
    await collect();
    expect(await job('1000')).toMatchObject({ status: 'open', description: 'a long description' });
    expect((await job('2000')).status).toBe('closed');
  });

  it('leaves other sources alone', async () => {
    await seed(2);
    await seed(2, { source: 'arbeitnow', start: 5000 });
    const others = JSON.stringify(await all("select * from public.jobs where source_id <> 'jobsconz' order by external_id"));
    await start();
    await answer('1000', { status: 404 });
    await answer('1001', { body: live('1001') });
    await collect();
    expect(JSON.stringify(await all("select * from public.jobs where source_id <> 'jobsconz' order by external_id"))).toBe(others);
  });
});

describe('scheduling and rollback', () => {
  it('the migration schedules nothing; the enable script needs the phrase and schedules start + collect; disable removes them', async () => {
    expect(await all('select * from cron.job')).toHaveLength(0);
    await expect(db.exec(ENABLE)).rejects.toThrow(/autorizacao/);
    await db.exec(SWITCH + ENABLE);
    const jobs = await all<{ jobname: string; schedule: string; command: string }>('select jobname, schedule, command from cron.job order by jobname');
    expect(jobs.map((j) => j.jobname)).toEqual(['jobsconz-revalidate-collect', 'jobsconz-revalidate-start']);
    expect(jobs.find((j) => j.jobname === 'jobsconz-revalidate-start')).toMatchObject({ schedule: '37 1,4,7,10,13,16,19,22 * * *', command: 'select ops.jobsconz_revalidate_start()' });
    await db.exec(DISABLE);
    expect(await all('select * from cron.job')).toHaveLength(0);
  });

  it('the rollback drops the two functions and touches no job', async () => {
    await seed(1, { status: 'unknown' });
    await db.exec(DOWN);
    await expect(db.query('select ops.jobsconz_revalidate_start()')).rejects.toThrow();
    expect((await job('1000')).status).toBe('unknown');
  });
});
