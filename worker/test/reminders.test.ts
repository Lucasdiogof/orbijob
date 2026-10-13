import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';

/**
 * Migration 20261025000000 (interview and follow-up reminders as notifications; push_claim returns the kind), against the REAL schema in
 * PGlite with every migration applied. Nothing here touches a hosted project.
 */
const A = '00000000-0000-4000-8000-00000000000a';
const B = '00000000-0000-4000-8000-00000000000b';
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
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema auth to anon, authenticated; grant execute on function auth.uid() to anon, authenticated; grant usage on schema public to anon, authenticated, service_role;
    insert into auth.users values ('${A}'), ('${B}');`);
  await db.exec(NET_STUB + CRON_STUB + STORAGE_STUB);
  const dir = new URL('../../supabase/migrations/', import.meta.url);
  for (const f of readdirSync(dir).sort()) {
    await db.exec(readFileSync(new URL(f, dir), 'utf8'));
    if (f.startsWith('20261008')) await db.exec('grant select, insert, update, delete on all tables in schema public to anon, authenticated;');
  }
  await db.exec(`insert into public.job_sources (id, status, attribution, can_redistribute) values
    ('s1','CONDITIONAL','a',true), ('s2','CONDITIONAL','b',true), ('closedsrc','RESEARCH','c',false), ('unlicensed','CONDITIONAL','d',false)`);
});

async function as<T>(role: 'anon' | 'authenticated', uid: string | null, fn: () => Promise<T>): Promise<T> {
  await db.exec(`set role ${role}; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false);`);
  try { return await fn(); } finally { await db.exec('reset role'); }
}

async function app(uid: string, o: { stage?: string; interviewInHours?: number | null; followUpInHours?: number | null; title?: string } = {}): Promise<string> {
  const r = await db.query<{ id: string }>(
    `insert into public.applications (user_id, job_snapshot, stage, interview_at, follow_up_at)
     values ($1, $2::jsonb, $3,
             case when $4::float8 is null then null else now() + ($4 || ' hours')::interval end,
             case when $5::float8 is null then null else now() + ($5 || ' hours')::interval end) returning id`,
    [uid, JSON.stringify({ title: o.title ?? 'Fisioterapeuta', company: 'Clínica', originalUrl: 'https://x.test/job' }), o.stage ?? 'interview',
     o.interviewInHours === undefined || o.interviewInHours === null ? null : String(o.interviewInHours),
     o.followUpInHours === undefined || o.followUpInHours === null ? null : String(o.followUpInHours)]);
  return r.rows[0]!.id;
}
const run = async (at = 'now()') => (await db.query<{ r: string }>(`select ops.reminders_run(${at}) r`)).rows[0]!.r;
const rem = async (uid = A) => (await db.query<{ kind: string; title: string; company: string; original_url: string; job_id: string | null; application_id: string }>(
  `select kind, title, company, original_url, job_id, application_id from public.notifications where user_id = $1 and kind <> 'new_job' order by kind, title`, [uid])).rows;

describe('ops.reminders_run', () => {
  it('reminds an interview in the next 24 hours and a follow-up due today, once each, with the person\'s own job text', async () => {
    const i = await app(A, { interviewInHours: 20, title: 'Interview job' });
    const f = await app(A, { followUpInHours: -1, title: 'Follow job' });
    expect(await run()).toBe('ok:interview=1,follow_up=1');
    expect(await rem()).toEqual([
      { kind: 'follow_up', title: 'Follow job', company: 'Clínica', original_url: 'https://x.test/job', job_id: null, application_id: f },
      { kind: 'interview', title: 'Interview job', company: 'Clínica', original_url: 'https://x.test/job', job_id: null, application_id: i },
    ]);
    expect(await run()).toBe('ok:interview=0,follow_up=0');
  });

  it('nothing for interviews further away or already past, follow-ups in the future or too old, or closed processes', async () => {
    await app(A, { interviewInHours: 30 });
    await app(A, { interviewInHours: -2 });
    await app(A, { followUpInHours: 72 });
    await app(A, { followUpInHours: -24 * 5 });
    for (const stage of ['hired', 'rejected', 'withdrawn', 'closed']) await app(A, { stage, interviewInHours: 3, followUpInHours: -1 });
    expect(await run()).toBe('ok:interview=0,follow_up=0');
  });

  it('a moved interview date is reminded again for the new date; the old one is not repeated', async () => {
    const id = await app(A, { interviewInHours: 10 });
    await run();
    await db.query(`update public.applications set interview_at = now() + interval '20 hours' + interval '1 day' where id = $1`, [id]);
    expect(await run()).toBe('ok:interview=0,follow_up=0');
    expect(await run("now() + interval '1 day'")).toBe('ok:interview=1,follow_up=0');
    expect((await rem()).filter((r) => r.kind === 'interview')).toHaveLength(2);
  });

  it('respects the notifications switch and never mixes accounts', async () => {
    await db.query(`insert into public.user_preferences (user_id, settings) values ($1, '{"notifications":{"enabled":false}}')`, [B]);
    await app(A, { interviewInHours: 5, title: 'A job' });
    await app(B, { interviewInHours: 5, title: 'B job' });
    expect(await run()).toBe('ok:interview=1,follow_up=0');
    expect((await rem(A)).map((r) => r.title)).toEqual(['A job']);
    expect(await rem(B)).toEqual([]);
    const seen = await as('authenticated', B, () => db.query('select 1 from public.notifications'));
    expect(seen.rows).toEqual([]);
  });

  it('deleting the application removes its reminders; job alerts keep their own uniqueness', async () => {
    const id = await app(A, { interviewInHours: 5 });
    await run();
    await db.query('delete from public.applications where id = $1', [id]);
    expect(await rem()).toEqual([]);
    await expect(db.query(`insert into public.notifications (user_id, kind, title) values ($1, 'bogus', 't')`, [A])).rejects.toThrow(/check constraint/);
  });

  it('no API role can run it; the client still cannot create notifications', async () => {
    for (const role of ['anon', 'authenticated'] as const) {
      await expect(as(role, A, () => db.query('select ops.reminders_run()'))).rejects.toThrow(/permission denied/);
    }
    await expect(as('authenticated', A, () => db.query(`insert into public.notifications (user_id, kind, title) values ($1, 'interview', 't')`, [A]))).rejects.toThrow(/permission denied/);
  });

  it('push_claim hands reminders to the sender with their kind and application', async () => {
    await as('authenticated', A, () => db.query(`insert into public.push_devices (user_id, token, platform) values ($1, $2, 'android')`, [A, `tok-${'x'.repeat(30)}`]));
    const id = await app(A, { interviewInHours: 5 });
    await run();
    const rows = (await db.query<{ kind: string; application_id: string; job_id: string | null }>('select kind, application_id, job_id from ops.push_claim(10)')).rows;
    expect(rows).toEqual([{ kind: 'interview', application_id: id, job_id: null }]);
  });

  it('the schedule script refuses without the owner phrase and schedules reminders-run at minute 50 with it', async () => {
    const ENABLE = readFileSync(new URL('../../scripts/supabase/ops/enable_reminders_cron.sql', import.meta.url), 'utf8');
    const DISABLE = readFileSync(new URL('../../scripts/supabase/ops/disable_reminders_cron.sql', import.meta.url), 'utf8');
    await expect(db.exec(ENABLE)).rejects.toThrow(/autorizacao explicita/);
    await db.exec(`set orbijob.enable_reminders_cron = 'EU-AUTORIZO-OS-LEMBRETES-AUTOMATICOS';` + ENABLE);
    expect((await db.query<{ schedule: string; command: string }>(`select schedule, command from cron.job where jobname = 'reminders-run'`)).rows)
      .toEqual([{ schedule: '50 * * * *', command: 'select ops.reminders_run()' }]);
    await db.exec(DISABLE);
    expect((await db.query(`select 1 from cron.job where jobname = 'reminders-run'`)).rows).toHaveLength(0);
  });

  it('applying twice changes nothing, and the rollback restores migration 17', async () => {
    await app(A, { interviewInHours: 5 });
    await run();
    await db.exec(readFileSync(new URL('../../supabase/migrations/20261025000000_application_reminders.sql', import.meta.url), 'utf8'));
    expect(await rem()).toHaveLength(1);
    await db.exec(readFileSync(new URL('../../supabase/rollback/20261025000000_application_reminders.down.sql', import.meta.url), 'utf8'));
    expect((await db.query(`select to_regprocedure('ops.reminders_run(timestamptz)') f`)).rows[0]).toEqual({ f: null });
    await expect(db.query('select * from ops.push_claim(1)')).resolves.toBeDefined();
  });
});
