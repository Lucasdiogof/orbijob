import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';

/**
 * Migration 20261016000000 (retention of closed Jobicy jobs), run against the REAL schema in PGlite with every migration applied.
 * Policy: open jobs are never touched; closed > 14 days are compacted; closed > 90 days and referenced by nothing are deleted (tombstone).
 * Nothing here touches a hosted project.
 */
const file = (p: string) => readFileSync(new URL(`../../${p}`, import.meta.url), 'utf8');
const ENABLE = file('scripts/supabase/ops/enable_retention_cron.sql');
const DISABLE = file('scripts/supabase/ops/disable_retention_cron.sql');
const DOWN = file('supabase/rollback/20261016000000_jobicy_retention.down.sql');
const PHRASE = 'EU-AUTORIZO-A-RETENCAO';
const SWITCH = "set orbijob.enable_retention_cron = 'EU-AUTORIZO-A-RETENCAO-AUTOMATICA';";
let db: PGlite;

const NET_STUB = `
  create schema net;
  create unlogged table net._http_response (id bigint, status_code int, content_type text, headers jsonb, content text, timed_out boolean, error_msg text, created timestamptz not null default now());
  create function net.http_get(url text, params jsonb default '{}', headers jsonb default '{}', timeout_milliseconds int default 2000) returns bigint language sql as $$ select 1::bigint $$;`;
const STORAGE_STUB = `
  create schema storage;
  create table storage.buckets (id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets(id), name text, owner uuid);
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[] language sql as $$ select string_to_array(name, '/') $$;
  grant usage on schema storage to anon, authenticated, service_role;`;
const CRON_STUB = `
  create schema cron;
  create table cron.job (jobid serial primary key, jobname text unique, schedule text, command text);
  create function cron.schedule(job_name text, schedule text, command text) returns bigint language sql as $$
    insert into cron.job (jobname, schedule, command) values (job_name, schedule, command)
    on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command returning jobid::bigint $$;
  create function cron.unschedule(job_name text) returns boolean language sql as $$ with d as (delete from cron.job where jobname = job_name returning 1) select count(*) > 0 from d $$;`;

beforeEach(async () => {
  db = new PGlite({ extensions: { pg_trgm } });
  await db.exec(`
    create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
    create schema auth; create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
    grant usage on schema auth to anon, authenticated; grant execute on function auth.uid() to anon, authenticated; grant usage on schema public to anon, authenticated, service_role;`);
  await db.exec(NET_STUB + CRON_STUB);
  await db.exec(STORAGE_STUB);
  const dir = new URL('../../supabase/migrations/', import.meta.url);
  for (const f of readdirSync(dir).sort()) {
    await db.exec(readFileSync(new URL(f, dir), 'utf8'));
    if (f.startsWith('20261008')) await db.exec('grant select, insert, update, delete on all tables in schema public to anon, authenticated;');
  }
  await db.exec("insert into public.job_sources (id, status, attribution, can_redistribute) values ('jobicy','CONDITIONAL','Remote jobs via Jobicy (https://jobicy.com)',true), ('other','READY','x',true)");
});

let seq = 0;
/** A job `ageDays` days past its closing (last_checked_at), with a heavy body. */
async function job(o: { status?: string; ageDays: number; source?: string; id?: string }) {
  const ext = o.id ?? String(++seq + 1000);
  await db.query(
    `insert into public.jobs (source_id, external_id, company, title, description, requirements, skills, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status, salary_min, salary_currency, salary_period)
     values ($1,$2,'Acme','Role '||$2,'a long description about the role','{"x"}','{"y"}','remote', now() - ($3 || ' days')::interval,'https://jobicy.com/jobs/'||$2,'https://jobicy.com/jobs/'||$2,'fp-'||$1||$2,$4,100000,'USD','year')`,
    [o.source ?? 'jobicy', ext, String(o.ageDays), o.status ?? 'closed']);
  return ext;
}
const row = async (ext: string, source = 'jobicy') => (await db.query<Record<string, unknown>>('select * from public.jobs where source_id = $1 and external_id = $2', [source, ext])).rows[0];
const count = async (sql: string) => Number((await db.query<{ n: string }>(`select count(*) n from (${sql}) t`)).rows[0]!.n);
const apply = async (extra = '') => (await db.query<{ r: string }>(`select ops.jobicy_retention_apply('${PHRASE}'${extra}) r`)).rows[0]!.r;
const plan = async () => Object.fromEntries((await db.query<{ layer: string; jobs: string }>('select * from ops.jobicy_retention_plan()')).rows.map((r) => [r.layer, Number(r.jobs)]));

describe('retention: what it changes', () => {
  it('never touches an open job or a recently closed one, whatever its age field says', async () => {
    const open = await job({ status: 'open', ageDays: 400 });
    const recent = await job({ ageDays: 3 });
    const edge = await job({ ageDays: 13 });
    const before = [await row(open), await row(recent), await row(edge)];
    expect(await apply()).toBe('ok:compacted=0,deleted=0');
    expect([await row(open), await row(recent), await row(edge)]).toEqual(before);
  });

  it('compacts a job closed for more than 14 days: heavy fields emptied, identity, link, salary and dates intact, search follows', async () => {
    const id = await job({ ageDays: 30 });
    const before = await row(id);
    expect(await apply()).toBe('ok:compacted=1,deleted=0');
    const after = await row(id);
    expect(after).toMatchObject({ description: '', requirements: [], skills: [], status: 'closed', title: before!.title, company: 'Acme', original_url: before!.original_url, canonical_url: before!.canonical_url, fingerprint: before!.fingerprint, salary_min: '100000', salary_currency: 'USD' });
    expect(after!.last_checked_at).toEqual(before!.last_checked_at); // the age that decides the next layer is not reset
    expect(await count("select 1 from public.jobs where external_id = '" + id + "' and search @@ to_tsquery('simple', 'long')")).toBe(0);
    expect(await count("select 1 from public.jobs where external_id = '" + id + "' and search @@ to_tsquery('simple', 'acme')")).toBe(1);
    expect(await apply()).toBe('ok:compacted=0,deleted=0'); // idempotent
  });

  it('deletes a job closed for more than 90 days that nothing references, leaving a tombstone; the same run does not compact what it deletes', async () => {
    const id = await job({ ageDays: 120 });
    expect(await apply()).toBe('ok:compacted=0,deleted=1');
    expect(await row(id)).toBeUndefined();
    expect((await db.query('select source_id, external_id from ops.job_tombstones')).rows).toEqual([{ source_id: 'jobicy', external_id: id }]);
  });

  it.each([
    ['a favourite (saved_jobs.job_id)', (j: string, u: string) => `insert into public.saved_jobs (user_id, job_id, job_key, snapshot) select '${u}', id, 'jobicy:${j}', '{"x":1}' from public.jobs where external_id = '${j}'`],
    ['a viewed job', (j: string, u: string) => `insert into public.viewed_jobs (user_id, job_id) select '${u}', id from public.jobs where external_id = '${j}'`],
    ['an application', (j: string, u: string) => `insert into public.applications (user_id, job_id, job_snapshot) select '${u}', id, '{"title":"t"}'::jsonb from public.jobs where external_id = '${j}'`],
    ['a cluster', (j: string) => `insert into public.job_clusters (canonical_job_id) select id from public.jobs where external_id = '${j}'`],
  ])('a job referenced by %s is never deleted, only compacted', async (_n, ref) => {
    const u = '00000000-0000-4000-8000-000000000001';
    await db.exec(`insert into auth.users (id) values ('${u}')`);
    const id = await job({ ageDays: 200 });
    await db.exec(ref(id, u));
    expect(await plan()).toMatchObject({ closed_kept_referenced: 1, closed_to_delete: 0, closed_to_compact: 1 });
    expect(await apply()).toBe('ok:compacted=1,deleted=0');
    expect(await row(id)).toMatchObject({ description: '', status: 'closed' });
    expect(await count('select 1 from ops.job_tombstones')).toBe(0);
    expect(await apply()).toBe('ok:compacted=0,deleted=0');
  });

  it('deleting a job cannot take a user row with it: the references that exist were checked first', async () => {
    const u = '00000000-0000-4000-8000-000000000002';
    await db.exec(`insert into auth.users (id) values ('${u}')`);
    const id = await job({ ageDays: 200 });
    await db.exec(`insert into public.saved_jobs (user_id, job_id, job_key, snapshot) select '${u}', id, 'jobicy:${id}', '{"x":1}' from public.jobs where external_id = '${id}'`);
    await apply();
    expect(await count('select 1 from public.saved_jobs')).toBe(1);
  });

  it('touches only the jobicy source', async () => {
    const other = await job({ ageDays: 500, source: 'other' });
    const before = await row(other, 'other');
    await apply();
    expect(await row(other, 'other')).toEqual(before);
  });

  it('acts on at most p_batch jobs of each kind per call and finishes over several calls', async () => {
    for (let i = 0; i < 6; i++) await job({ ageDays: 40 });
    for (let i = 0; i < 6; i++) await job({ ageDays: 400 });
    for (let i = 0; i < 40; i++) await job({ status: 'open', ageDays: 1 }); // keeps the 20 % guard out of the way
    const batch = ", interval '14 days', interval '90 days', 4";
    expect(await apply(batch)).toBe('ok:compacted=4,deleted=4'); // never more than 4 of each kind in one call
    let calls = 1;
    while ((await apply(batch)) !== 'ok:compacted=0,deleted=0') calls++;
    expect(calls).toBeLessThanOrEqual(4);
    expect(await count('select 1 from ops.job_tombstones')).toBe(6);
    expect(await count("select 1 from public.jobs where status = 'closed'")).toBe(6);
    expect(await count("select 1 from public.jobs where status = 'closed' and description = ''")).toBe(6);
    expect(await count("select 1 from public.jobs where status = 'open' and description <> ''")).toBe(40);
  });

  it('shows the layers in the plan without changing anything', async () => {
    await job({ status: 'open', ageDays: 1 }); await job({ ageDays: 2 }); await job({ ageDays: 20 }); await job({ ageDays: 100 });
    const snap = JSON.stringify((await db.query('select * from public.jobs order by external_id')).rows);
    expect(await plan()).toEqual({ open: 1, closed_recent: 1, closed_to_compact: 2, closed_compacted: 0, closed_to_delete: 1, closed_kept_referenced: 0 });
    expect(JSON.stringify((await db.query('select * from public.jobs order by external_id')).rows)).toBe(snap);
  });
});

describe('retention: guards', () => {
  it('refuses without the owner phrase, with a wrong one, and with a nonsensical policy; nothing changes', async () => {
    const id = await job({ ageDays: 400 });
    await expect(db.query('select ops.jobicy_retention_apply(null)')).rejects.toThrow(/frase de autorizacao/);
    await expect(db.query("select ops.jobicy_retention_apply('yes')")).rejects.toThrow(/frase de autorizacao/);
    await expect(apply(", interval '1 day'")).rejects.toThrow(/compact_after minimo/);
    await expect(apply(", interval '14 days', interval '20 days'")).rejects.toThrow(/delete_after minimo/);
    await expect(apply(", interval '60 days', interval '70 days'")).rejects.toThrow(/delete_after minimo/);
    await expect(apply(", interval '14 days', interval '90 days', 0")).rejects.toThrow(/batch entre/);
    await expect(apply(", interval '14 days', interval '90 days', 501")).rejects.toThrow(/batch entre/);
    expect(await row(id)).toBeDefined();
  });

  it('refuses when it would touch more than 20 % of the closed jobs (and more than 50), unless explicitly allowed', async () => {
    for (let i = 0; i < 60; i++) await job({ ageDays: 40 });
    for (let i = 0; i < 20; i++) await job({ ageDays: 1 });
    expect(await apply()).toBe('refused:too_many_candidates(60 of 80 closed)');
    expect(await count("select 1 from public.jobs where description <> ''")).toBe(80);
    expect(await apply(", interval '14 days', interval '90 days', 200, true")).toBe('ok:compacted=60,deleted=0');
  });

  it('logs every call in ops.retention_runs and never in sync_runs (so it cannot make a revalidation stand down)', async () => {
    await job({ ageDays: 40 });
    const runsBefore = await count('select 1 from public.sync_runs');
    await apply();
    expect((await db.query<{ outcome: string }>('select outcome from ops.retention_runs')).rows.map((r) => r.outcome)).toEqual(['ok:compacted=1,deleted=0']);
    expect(await count('select 1 from public.sync_runs')).toBe(runsBefore);
  });
});

describe('retention: access, scheduling, rollback', () => {
  it('the API roles cannot run it, read the log or the tombstones, or even see the schema', async () => {
    for (const role of ['anon', 'authenticated', 'service_role']) {
      await db.exec(`set role ${role}`);
      await expect(db.query(`select ops.jobicy_retention_apply('${PHRASE}')`)).rejects.toThrow(/permission denied/);
      await expect(db.query('select * from ops.jobicy_retention_plan()')).rejects.toThrow(/permission denied/);
      await expect(db.query('select * from ops.job_tombstones')).rejects.toThrow(/permission denied/);
      await expect(db.query('select * from ops.retention_runs')).rejects.toThrow(/permission denied/);
      await db.exec('reset role');
    }
  });

  it('the migration schedules nothing; the enable script refuses without the phrase, schedules one weekly job with it, and the disable script removes it', async () => {
    expect(await count('select 1 from cron.job')).toBe(0);
    await expect(db.exec(ENABLE)).rejects.toThrow(/autorizacao explicita/);
    await expect(db.exec("set orbijob.enable_retention_cron = 'sim'; " + ENABLE)).rejects.toThrow(/autorizacao explicita/);
    expect(await count('select 1 from cron.job')).toBe(0);
    await db.exec(SWITCH + ENABLE);
    expect((await db.query<{ jobname: string; schedule: string; command: string }>('select jobname, schedule, command from cron.job')).rows).toEqual([
      { jobname: 'jobicy-retention', schedule: '37 4 * * 0', command: "select ops.jobicy_retention_apply('EU-AUTORIZO-A-RETENCAO')" },
    ]);
    await db.exec(SWITCH + ENABLE); // idempotent
    expect(await count('select 1 from cron.job')).toBe(1);
    await db.exec(DISABLE);
    await db.exec(DISABLE);
    expect(await count('select 1 from cron.job')).toBe(0);
  });

  it('the scheduled command is exactly what the guard accepts, and it runs as written', async () => {
    await job({ ageDays: 40 });
    await db.exec(SWITCH + ENABLE);
    const cmd = (await db.query<{ command: string }>('select command from cron.job')).rows[0]!.command;
    expect((await db.query<{ ops: string }>(cmd.replace('select ops.jobicy_retention_apply(', 'select ops.jobicy_retention_apply(').replace(/;?$/, ''))).rows.length).toBe(1);
    expect(await count("select 1 from public.jobs where description = ''")).toBe(1);
  });

  it('the rollback removes the schedule, the functions and the tables, and leaves every job as it is', async () => {
    const id = await job({ ageDays: 40 });
    await db.exec(SWITCH + ENABLE);
    await apply();
    const keep = JSON.stringify(await row(id));
    await db.exec(DOWN);
    expect(await count('select 1 from cron.job')).toBe(0);
    expect(await count("select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'ops' and p.proname like 'jobicy_retention%'")).toBe(0);
    expect(await count("select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'ops' and c.relname in ('job_tombstones', 'retention_runs')")).toBe(0);
    expect(JSON.stringify(await row(id))).toBe(keep);
    await db.exec(DOWN); // idempotent
  });
});
