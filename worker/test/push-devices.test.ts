import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';

/**
 * Migration 20261024000000 (push devices and the two functions of the sender), against the REAL schema in
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

const TOK = (n: number | string) => `fcm-token-${n}-${'x'.repeat(30)}`;
const register = (uid: string, token: string, platform = 'android', locale: string | null = 'pt-BR') =>
  as('authenticated', uid, () => db.query('select public.push_register($1, $2, $3)', [token, platform, locale]));
const devices = async (uid?: string) =>
  (await db.query<{ user_id: string; token: string; platform: string }>(
    `select user_id, token, platform from public.push_devices ${uid ? 'where user_id = $1' : ''} order by token`, uid ? [uid] : [])).rows;
let jobSeq = 0;
async function note(uid: string, o: { minutesAgo?: number; read?: boolean; dismissed?: boolean; title?: string } = {}): Promise<string> {
  const n = ++jobSeq;
  const j = await db.query<{ id: string }>(
    `insert into public.jobs (source_id, external_id, company, title, last_checked_at, original_url, canonical_url, fingerprint)
     values ('s1', $1, 'Acme', 'Job', now(), 'https://x.test/'||$1, 'https://x.test/'||$1, 'fp'||$1) returning id`, [`p${n}`]);
  const r = await db.query<{ id: string }>(
    `insert into public.notifications (user_id, job_id, title, company, created_at, read_at, dismissed_at)
     values ($1, $2, $3, 'Acme', now() - ($4 || ' minutes')::interval, case when $5 then now() end, case when $6 then now() end) returning id`,
    [uid, j.rows[0]!.id, o.title ?? `Job ${n}`, String(o.minutesAgo ?? 5), o.read ?? false, o.dismissed ?? false]);
  return r.rows[0]!.id;
}
const claim = (limit = 200) =>
  db.query<{ notification_id: string; user_id: string; token: string; title: string; locale: string | null }>(
    'select * from public.push_claim($1) order by title, token', [limit]).then((r) => r.rows);

describe('push_devices: registration and ownership', () => {
  it('a signed-in person registers a device; re-registering the same token updates it instead of failing', async () => {
    await register(A, TOK(1));
    await register(A, TOK(1), 'ios', 'en');
    expect(await devices(A)).toEqual([{ user_id: A, token: TOK(1), platform: 'ios' }]);
  });

  it('anonymous registration and bad values are refused', async () => {
    await expect(register('', TOK(1))).rejects.toThrow();
    await expect(register(A, 'short')).rejects.toThrow(/invalid token/);
    await expect(register(A, TOK(2), 'windows')).rejects.toThrow(/invalid platform/);
  });

  it('a token used by another account on the same phone moves to the person signing in now', async () => {
    await register(A, TOK(1));
    await register(B, TOK(1));
    expect(await devices()).toEqual([{ user_id: B, token: TOK(1), platform: 'android' }]);
  });

  it('an 11th device makes room by dropping the least recently seen one (never fails)', async () => {
    for (let i = 0; i < 11; i++) {
      await register(A, TOK(i));
      await db.query(`update public.push_devices set last_seen_at = now() - ($2 || ' minutes')::interval where token = $1`, [TOK(i), String(100 - i)]);
    }
    const left = (await devices(A)).map((d) => d.token);
    expect(left).toHaveLength(10);
    expect(left).not.toContain(TOK(0));
  });

  it('each person sees and deletes only their own devices, and cannot insert or update directly', async () => {
    await register(A, TOK('a'));
    await register(B, TOK('b'));
    const seen = await as('authenticated', A, () => db.query<{ token: string }>('select token from public.push_devices'));
    expect(seen.rows.map((r) => r.token)).toEqual([TOK('a')]);
    await as('authenticated', A, () => db.query('delete from public.push_devices'));
    expect((await devices()).map((d) => d.token)).toEqual([TOK('b')]);
    await expect(as('authenticated', A, () => db.query(`insert into public.push_devices (user_id, token, platform) values ($1, $2, 'android')`, [A, TOK('z')]))).rejects.toThrow(/permission denied/);
    await expect(as('authenticated', B, () => db.query(`update public.push_devices set platform = 'ios'`))).rejects.toThrow(/permission denied/);
    await expect(as('anon', null, () => db.query('select * from public.push_devices'))).rejects.toThrow(/permission denied/);
  });
});

describe('push_claim / push_forget_tokens (the sender)', () => {
  it('returns each unsent, unread, recent notification once per device, and marks it so a second claim returns nothing', async () => {
    await register(A, TOK('a1'));
    await register(A, TOK('a2'), 'ios', 'en');
    await register(B, TOK('b1'));
    await note(A, { title: 'For A' });
    await note(B, { title: 'For B' });
    const first = await claim();
    expect(first.map((r) => [r.title, r.token])).toEqual([['For A', TOK('a1')], ['For A', TOK('a2')], ['For B', TOK('b1')]]);
    expect(await claim()).toEqual([]);
    expect(Number((await db.query<{ n: string }>('select count(*) n from public.notifications where pushed_at is not null')).rows[0]!.n)).toBe(2);
  });

  it('skips old, read and dismissed rows, and people who switched notifications off (their rows are still marked)', async () => {
    await register(A, TOK('a'));
    await register(B, TOK('b'));
    await note(A, { title: 'old', minutesAgo: 7 * 60 });
    await note(A, { title: 'read', read: true });
    await note(A, { title: 'dismissed', dismissed: true });
    await note(A, { title: 'fresh' });
    await db.query(`insert into public.user_preferences (user_id, settings) values ($1, '{"notifications":{"enabled":false}}')`, [B]);
    await note(B, { title: 'B muted' });
    expect((await claim()).map((r) => r.title)).toEqual(['fresh']);
    expect((await db.query<{ title: string }>('select title from public.notifications where pushed_at is null order by title')).rows.map((r) => r.title))
      .toEqual(['dismissed', 'old', 'read']);
  });

  it('a person without devices gets nothing sent and the row is not claimed again', async () => {
    await note(A, { title: 'no device' });
    expect(await claim()).toEqual([]);
    await register(A, TOK('late'));
    expect(await claim()).toEqual([]);
  });

  it('respects the limit and its bounds', async () => {
    await register(A, TOK('a'));
    for (let i = 0; i < 5; i++) await note(A);
    expect(await claim(2)).toHaveLength(2);
    expect(await claim()).toHaveLength(3);
    await expect(claim(0)).rejects.toThrow(/limit/);
    await expect(claim(1001)).rejects.toThrow(/limit/);
  });

  it('forgets the tokens FCM no longer knows', async () => {
    await register(A, TOK(1));
    await register(A, TOK(2));
    expect((await db.query<{ n: number }>('select public.push_forget_tokens($1) n', [[TOK(1), 'unknown']])).rows[0]!.n).toBe(1);
    expect((await devices(A)).map((d) => d.token)).toEqual([TOK(2)]);
  });

  it('only service_role may call the sender functions; the client cannot write pushed_at', async () => {
    await note(A);
    for (const role of ['anon', 'authenticated'] as const) {
      await expect(as(role, A, () => db.query('select * from public.push_claim(10)'))).rejects.toThrow(/permission denied/);
      await expect(as(role, A, () => db.query(`select public.push_forget_tokens('{}')`))).rejects.toThrow(/permission denied/);
    }
    await expect(as('authenticated', A, () => db.query('update public.notifications set pushed_at = now()'))).rejects.toThrow(/permission denied/);
    await db.exec('set role service_role');
    try {
      await expect(db.query('select * from public.push_claim(10)')).resolves.toBeDefined();
      await expect(db.query('select * from public.notifications')).rejects.toThrow(/permission denied/);
      await expect(db.query('select * from public.push_devices')).rejects.toThrow(/permission denied/);
    } finally {
      await db.exec('reset role');
    }
  });

  it('applying the migration twice changes nothing, and the rollback removes it cleanly', async () => {
    await register(A, TOK(1));
    await db.exec(readFileSync(new URL('../../supabase/migrations/20261024000000_push_devices.sql', import.meta.url), 'utf8'));
    expect(await devices(A)).toHaveLength(1);
    await db.exec(readFileSync(new URL('../../supabase/rollback/20261024000000_push_devices.down.sql', import.meta.url), 'utf8'));
    expect((await db.query(`select to_regclass('public.push_devices') t`)).rows[0]).toEqual({ t: null });
    await db.exec(readFileSync(new URL('../../supabase/migrations/20261024000000_push_devices.sql', import.meta.url), 'utf8'));
  });
});
