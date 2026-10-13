import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';

/**
 * Migration 20261026000000 (search alternatives with several parts; profession searches judged on the title), against the REAL schema in
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

let seq = 0;
type J = { source?: string; title?: string; company?: string; city?: string | null; country?: string | null; mode?: string; status?: string; checkedHoursAgo?: number; publishedDaysAgo?: number | null; firstSeenMinutesAgo?: number; fingerprint?: string; geo?: string[]; salary?: boolean; description?: string };
async function job(o: J = {}): Promise<string> {
  const n = ++seq;
  const r = await db.query<{ id: string }>(
    `insert into public.jobs (source_id, external_id, company, title, description, city, country, work_mode, status, last_checked_at, published_at, first_seen_at, original_url, canonical_url, fingerprint, geo_restrictions, salary_min, salary_currency, salary_period)
     values ($1,$2,$3,$4,$5,$6,$7,$8,$9, now() - ($10 || ' hours')::interval, case when $11::int is null then null else now() - ($11 || ' days')::interval end,
             now() - ($12 || ' minutes')::interval, 'https://x.test/'||$2, 'https://x.test/'||$2, $13, $14::text[], $15::numeric, $16, $17) returning id`,
    [o.source ?? 's1', `e${n}`, o.company ?? 'Acme', o.title ?? `Nurse ${n}`, o.description ?? '', o.city ?? null, o.country === undefined ? 'DE' : o.country, o.mode ?? 'onsite', o.status ?? 'open',
     String(o.checkedHoursAgo ?? 1), o.publishedDaysAgo === undefined ? '2' : o.publishedDaysAgo === null ? null : String(o.publishedDaysAgo), String(o.firstSeenMinutesAgo ?? 5),
     o.fingerprint ?? `fp${n}`, `{${(o.geo ?? []).join(',')}}`, o.salary ? '1000' : null, o.salary ? 'EUR' : null, o.salary ? 'month' : null]);
  return r.rows[0]!.id;
}
async function search(uid: string, q: Record<string, unknown>, o: { enabled?: boolean; freq?: string; name?: string } = {}): Promise<string> {
  const r = await db.query<{ id: string }>(
    `insert into public.saved_searches (user_id, name, query, alerts_enabled, frequency) values ($1,$2,$3::jsonb,$4,$5) returning id`,
    [uid, o.name ?? 'S', JSON.stringify(q), o.enabled ?? true, o.freq ?? 'instant']);
  return r.rows[0]!.id;
}
const run = async () => (await db.query<{ r: string }>('select ops.alerts_run() r')).rows[0]!.r;
const notes = async (uid = A) => (await db.query<{ job_id: string; search_ids: string[]; title: string }>('select job_id, search_ids, title from public.notifications where user_id = $1 order by created_at, title', [uid])).rows;
/** Backdates the cursor so the jobs created by `job()` (first seen 5 minutes ago) are "new" for this search. */
const rewind = (id: string) => db.query(`update public.saved_searches set alert_cursor = now() - interval '2 hours', last_alert_run_at = null where id = $1`, [id]);
const matches = async (id: string, q: Record<string, unknown>) =>
  (await db.query<{ m: boolean }>('select ops.alert_matches(j, $2::jsonb) m from public.jobs j where j.id = $1', [id, JSON.stringify({ match: q })])).rows[0]!.m;

describe('match.alts with several required parts (migration 20261026000000)', () => {
  it('an array alternative needs every part in the title; a string alternative works as before', async () => {
    const flutterDev = await job({ title: 'Senior Flutter-Entwickler (m/w/d)' });
    const javaDev = await job({ title: 'Java Entwickler (m/w/d)' });
    const flutterEng = await job({ title: 'Flutter Engineer' });
    const q = { term: 'desenvolvedor flutter', alts: [['flutter', 'entwickler'], ['flutter', 'developer'], 'flutter engineer'] };
    expect(await matches(flutterDev, q)).toBe(true);
    expect(await matches(javaDev, q)).toBe(false);
    expect(await matches(flutterEng, q)).toBe(true);
  });

  it('a profession search is judged on the title: a description that only mentions the word does not match', async () => {
    const mention = await job({ title: 'Office Manager', description: 'You will work closely with our civil engineer team.' });
    const real = await job({ title: 'Bauingenieur (m/w/d)' });
    const q = { term: 'engenheiro civil', alts: ['civil engineer', 'bauingenieur', 'ingeniero civil'] };
    expect(await matches(mention, q)).toBe(false);
    expect(await matches(real, q)).toBe(true);
  });

  it('a search without alternatives keeps the full-text match on the description', async () => {
    const id = await job({ title: 'Office Manager', description: 'Kubernetes and Terraform every day' });
    expect(await matches(id, { term: 'terraform' })).toBe(true);
    expect(await matches(id, { term: 'terraform', alts: [] })).toBe(true);
  });

  it('malformed alternatives are ignored, never crash, never match everything', async () => {
    const id = await job({ title: 'Nurse' });
    expect(await matches(id, { term: 'zzz', alts: [[], ['a', 'b', 'c', 'd', 'e', 'f', 'g'], 42, { x: 1 }] })).toBe(false);
    expect(await matches(id, { term: 'zzz', alts: 'nurse' })).toBe(false);
  });

  it('applying twice is harmless and the rollback restores the previous behaviour', async () => {
    const mention = await job({ title: 'Office Manager', description: 'with our civil engineer team' });
    const sql = (p: string) => readFileSync(new URL(`../../supabase/${p}`, import.meta.url), 'utf8');
    await db.exec(sql('migrations/20261026000000_search_alternatives.sql'));
    expect(await matches(mention, { term: 'civil engineer', alts: ['bauingenieur'] })).toBe(false);
    await db.exec(sql('rollback/20261026000000_search_alternatives.down.sql'));
    expect(await matches(mention, { term: 'civil engineer', alts: ['bauingenieur'] })).toBe(true);
  });
});
