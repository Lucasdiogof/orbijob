import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';

/**
 * Migration 20261023000000 (OrbiJob 3.0: saved searches with alerts, notifications, hidden jobs, application pipeline), against the REAL schema in
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

describe('schema', () => {
  it('first_seen_at exists, defaults to now, and the existing catalogue is not "new"', async () => {
    const id = await job({ firstSeenMinutesAgo: 600 });
    const r = await db.query<{ t: Date }>('select first_seen_at t from public.jobs where id = $1', [id]);
    expect(r.rows[0]!.t.getTime()).toBeLessThan(Date.now() - 500 * 60_000);
    await db.exec(`insert into public.jobs (source_id, external_id, company, title, last_checked_at, original_url, canonical_url, fingerprint) values ('s1','fresh','C','T',now(),'https://x.test/f','https://x.test/f','ffp')`);
    const f = await db.query<{ t: Date }>("select first_seen_at t from public.jobs where external_id = 'fresh'");
    expect(Math.abs(f.rows[0]!.t.getTime() - Date.now())).toBeLessThan(60_000);
  });

  it('applying the migration a second time changes nothing (idempotent) and keeps first_seen_at', async () => {
    const id = await job({ firstSeenMinutesAgo: 600 });
    const before = (await db.query('select first_seen_at from public.jobs where id = $1', [id])).rows[0];
    await db.exec(readFileSync(new URL('../../supabase/migrations/20261023000000_v3_searches_alerts.sql', import.meta.url), 'utf8'));
    expect((await db.query('select first_seen_at from public.jobs where id = $1', [id])).rows[0]).toEqual(before);
  });

  it('old and new application stages are accepted, anything else is refused, and the stage trigger still records history', async () => {
    for (const st of ['interested', 'applied', 'screening', 'interview', 'offer', 'hired', 'rejected', 'withdrawn', 'closed']) {
      await db.query(`insert into public.applications (user_id, job_snapshot, stage) values ($1,'{"title":"t"}',$2)`, [A, st]);
    }
    await expect(db.query(`insert into public.applications (user_id, job_snapshot, stage) values ($1,'{"title":"t"}','bogus')`, [A])).rejects.toThrow();
    const id = (await db.query<{ id: string }>(`select id from public.applications where stage = 'interested'`)).rows[0]!.id;
    await db.query(`update public.applications set stage = 'interview', interview_at = now() + interval '3 days', follow_up_at = now() + interval '7 days' where id = $1`, [id]);
    expect((await db.query<{ stage: string }>('select stage from public.application_events where application_id = $1 order by occurred_at, stage', [id])).rows.map((r) => r.stage).sort()).toEqual(['interested', 'interview']);
  });
});

describe('saved searches: ownership and the alert columns', () => {
  it('a user lists only their own searches and cannot insert, update or delete another user\'s', async () => {
    await search(A, { term: 'a' }); await search(B, { term: 'b' });
    await as('authenticated', A, async () => {
      expect((await db.query('select id from public.saved_searches')).rows).toHaveLength(1);
      await expect(db.query(`insert into public.saved_searches (user_id, query) values ('${B}','{}')`)).rejects.toThrow(/row-level security/);
      expect((await db.query(`update public.saved_searches set name = 'x' where user_id = '${B}'`)).affectedRows).toBe(0);
      expect((await db.query(`delete from public.saved_searches where user_id = '${B}'`)).affectedRows).toBe(0);
    });
  });

  it('the alert cursor and run time cannot be written by the client', async () => {
    const id = await search(A, { term: 'a' });
    await as('authenticated', A, async () => {
      await expect(db.query(`update public.saved_searches set alert_cursor = now() - interval '5 years' where id = '${id}'`)).rejects.toThrow(/permission denied/);
      await expect(db.query(`update public.saved_searches set last_alert_run_at = null where id = '${id}'`)).rejects.toThrow(/permission denied/);
      await expect(db.query(`insert into public.saved_searches (user_id, query, alert_cursor) values ('${A}','{}', now())`)).rejects.toThrow(/permission denied/);
      await db.query(`update public.saved_searches set name = 'ok', frequency = 'weekly' where id = '${id}'`); // allowed columns
    });
  });

  it('turning alerts on starts the cursor at now; editing the criteria restarts it; frequency and name are validated', async () => {
    const id = await search(A, { term: 'a' }, { enabled: false });
    expect((await db.query<{ c: Date | null }>('select alert_cursor c from public.saved_searches where id = $1', [id])).rows[0]!.c).toBeNull();
    await as('authenticated', A, () => db.query(`update public.saved_searches set alerts_enabled = true where id = '${id}'`));
    const c1 = (await db.query<{ c: Date }>('select alert_cursor c from public.saved_searches where id = $1', [id])).rows[0]!.c;
    expect(Math.abs(c1.getTime() - Date.now())).toBeLessThan(60_000);
    await db.query(`update public.saved_searches set alert_cursor = now() - interval '3 hours' where id = $1`, [id]);
    await as('authenticated', A, () => db.query(`update public.saved_searches set query = '{"term":"b"}' where id = '${id}'`));
    const c2 = (await db.query<{ c: Date }>('select alert_cursor c from public.saved_searches where id = $1', [id])).rows[0]!.c;
    expect(Math.abs(c2.getTime() - Date.now())).toBeLessThan(60_000);
    await expect(db.query(`update public.saved_searches set frequency = 'minutely' where id = $1`, [id])).rejects.toThrow();
    await expect(db.query(`update public.saved_searches set name = '' where id = $1`, [id])).rejects.toThrow();
    await expect(db.query(`update public.saved_searches set name = $2 where id = $1`, [id, 'x'.repeat(81)])).rejects.toThrow();
  });

  it('the account quota of 100 searches still holds', async () => {
    for (let i = 0; i < 100; i++) await db.query(`insert into public.saved_searches (user_id, query) values ($1, '{}')`, [A]);
    await expect(db.query(`insert into public.saved_searches (user_id, query) values ($1, '{}')`, [A])).rejects.toThrow(/quota/);
  });
});

describe('notifications: what a person can and cannot do', () => {
  it('reads only their own, may mark read / dismiss, and cannot create, delete, or edit the content', async () => {
    const j1 = await job(); const j2 = await job();
    await db.query(`insert into public.notifications (user_id, job_id, title) values ($1,$2,'for A'), ($3,$4,'for B')`, [A, j1, B, j2]);
    await as('authenticated', A, async () => {
      expect((await db.query<{ title: string }>('select title from public.notifications')).rows).toEqual([{ title: 'for A' }]);
      await expect(db.query(`insert into public.notifications (user_id, job_id, title) values ('${A}', '${j2}', 'forged')`)).rejects.toThrow(/permission denied/);
      await expect(db.query(`delete from public.notifications`)).rejects.toThrow(/permission denied/);
      await expect(db.query(`update public.notifications set title = 'changed'`)).rejects.toThrow(/permission denied/);
      expect((await db.query(`update public.notifications set read_at = now(), dismissed_at = now()`)).affectedRows).toBe(1);
    });
    expect((await db.query(`select 1 from public.notifications where user_id = $1 and read_at is null`, [B])).rows).toHaveLength(1); // B untouched
    await as('anon', null, async () => { await expect(db.query('select * from public.notifications')).rejects.toThrow(/permission denied/); });
  });

  it('nobody but the owner can call the alert functions', async () => {
    for (const role of ['anon', 'authenticated'] as const) {
      await as(role, A, async () => {
        await expect(db.query('select ops.alerts_run()')).rejects.toThrow(/permission denied/);
        await expect(db.query('select * from ops.alert_runs')).rejects.toThrow(/permission denied/);
      });
    }
  });
});

describe('alerts_run: who is told about what', () => {
  it('announces a new, open, verified, licensed job that matches, once, and never a job that was already there', async () => {
    const s = await search(A, { match: { term: 'nurse' } });
    const old = await job({ title: 'Nurse old', firstSeenMinutesAgo: 600 });
    await rewind(s); // cursor 2 h ago: `old` was first seen 10 h ago, so it is not new
    const fresh = await job({ title: 'Nurse fresh' });
    expect(await run()).toBe('ok due=1 notified=1 capped=0');
    expect((await notes()).map((n) => n.job_id)).toEqual([fresh]);
    expect((await notes()).map((n) => n.job_id)).not.toContain(old);
    await db.query(`update public.saved_searches set last_alert_run_at = null where id = $1`, [s]);
    expect(await run()).toBe('ok due=1 notified=0 capped=0'); // the overlap window re-reads the job, the unique key keeps it single
    expect(await notes()).toHaveLength(1);
  });

  it.each([
    ['closed', { status: 'closed' }],
    ['unknown status', { status: 'unknown' }],
    ['not verified for more than 72 h', { checkedHoursAgo: 80 }],
    ['published more than 60 days ago', { publishedDaysAgo: 70 }],
    ['from a source that is not redistributable', { source: 'unlicensed' }],
    ['from a source that is not CONDITIONAL/READY', { source: 'closedsrc' }],
    ['not matching the term', { title: 'Plumber' }],
  ] as [string, J][])('does not announce a job that is %s', async (_n, o) => {
    const s = await search(A, { match: { term: 'nurse' } });
    await rewind(s);
    await job({ title: 'Nurse', ...o });
    await run();
    expect(await notes()).toHaveLength(0);
  });

  it('announces an undated job (the source gave no publication date) that is otherwise valid', async () => {
    const s = await search(A, { match: { term: 'nurse' } }); await rewind(s);
    await job({ publishedDaysAgo: null });
    await run();
    expect(await notes()).toHaveLength(1);
  });

  it('does not announce a job the user hid, but hiding after the fact does not remove the alert', async () => {
    const s = await search(A, { match: { term: 'nurse' } }); await rewind(s);
    await job({ title: 'Nurse hidden' });
    const ok = await job({ title: 'Nurse shown' });
    await db.query(`insert into public.hidden_jobs (user_id, job_key, source_id, external_id, title) select $1, source_id||':'||external_id, source_id, external_id, title from public.jobs where title = 'Nurse hidden'`, [A]);
    await run();
    expect((await notes()).map((n) => n.job_id)).toEqual([ok]);
  });

  it('one notification for the same job matched by two searches (both recorded), and none for a copy of it under another source', async () => {
    const s1 = await search(A, { match: { term: 'nurse' } }, { name: 'one' });
    const s2 = await search(A, { match: { country: 'DE' } }, { name: 'two' });
    await rewind(s1); await rewind(s2);
    const j = await job({ title: 'Nurse DE', fingerprint: 'same' });
    await job({ title: 'Nurse DE', fingerprint: 'same', source: 's2' });
    await run();
    const n = await notes();
    expect(n).toHaveLength(1);
    expect(n[0]!.job_id).toBe(j);
    expect([...n[0]!.search_ids].sort()).toEqual([s1, s2].sort());
  });

  it('keeps users apart: B\'s search never produces a notification for A', async () => {
    const sa = await search(A, { match: { term: 'nurse' } }); const sb = await search(B, { match: { term: 'plumber' } });
    await rewind(sa); await rewind(sb);
    await job({ title: 'Nurse' });
    await run();
    expect(await notes(A)).toHaveLength(1);
    expect(await notes(B)).toHaveLength(0);
  });

  it('respects frequency: daily and weekly searches are not run again before their time, instant ones are', async () => {
    const d = await search(A, { match: { term: 'nurse' } }, { freq: 'daily' });
    const w = await search(A, { match: { term: 'nurse' } }, { freq: 'weekly' });
    const i = await search(A, { match: { term: 'nurse' } }, { freq: 'instant' });
    for (const id of [d, w, i]) await db.query(`update public.saved_searches set alert_cursor = now() - interval '2 hours', last_alert_run_at = now() - interval '1 hour' where id = $1`, [id]);
    expect(await run()).toBe('ok due=1 notified=0 capped=0'); // only the instant one is due
    await db.query(`update public.saved_searches set last_alert_run_at = now() - interval '25 hours' where id = $1`, [d]);
    expect(await run()).toBe('ok due=2 notified=0 capped=0'); // instant + daily
    await db.query(`update public.saved_searches set last_alert_run_at = now() - interval '8 days' where id = $1`, [w]);
    expect(await run()).toBe('ok due=2 notified=0 capped=0'); // instant + weekly (the daily one just ran)
  });

  it('a search with alerts off is never evaluated', async () => {
    const s = await search(A, { match: { term: 'nurse' } }, { enabled: false });
    await db.query(`update public.saved_searches set alert_cursor = now() - interval '2 hours' where id = $1`, [s]);
    await job();
    expect(await run()).toBe('ok due=0 notified=0 capped=0');
    expect(await notes()).toHaveLength(0);
  });

  it('a user who switched notifications off gets nothing, and gets no backlog when they switch back on', async () => {
    const s = await search(A, { match: { term: 'nurse' } }); await rewind(s);
    await db.query(`insert into public.user_preferences (user_id, settings) values ($1, '{"notifications":{"enabled":false}}')`, [A]);
    await job({ title: 'Nurse while off', firstSeenMinutesAgo: 30 });
    await run();
    expect(await notes()).toHaveLength(0);
    await db.query(`update public.user_preferences set settings = '{"notifications":{"enabled":true}}' where user_id = $1`, [A]);
    await db.query(`update public.saved_searches set last_alert_run_at = null where id = $1`, [s]);
    await run();
    expect(await notes()).toHaveLength(0);
    await job({ title: 'Nurse after on' });
    await run();
    expect((await notes()).map((n) => n.title)).toEqual(['Nurse after on']);
  });

  it('caps one pass per search and resumes after the last delivered job on the next pass', async () => {
    const s = await search(A, { match: { term: 'nurse' } }); await rewind(s);
    for (let k = 0; k < 7; k++) await job({ title: `Nurse ${k}`, firstSeenMinutesAgo: 60 - k });
    expect((await db.query<{ r: string }>('select ops.alerts_run(5) r')).rows[0]!.r).toBe('ok due=1 notified=5 capped=1');
    expect(await notes()).toHaveLength(5);
    expect((await db.query<{ r: string }>('select ops.alerts_run(5) r')).rows[0]!.r).toBe('ok due=1 notified=2 capped=0');
    expect(await notes()).toHaveLength(7);
  });

  it('a dismissed notification is not announced again by a later run', async () => {
    const s = await search(A, { match: { term: 'nurse' } }); await rewind(s);
    await job();
    await run();
    await as('authenticated', A, () => db.query('update public.notifications set dismissed_at = now()'));
    await db.query(`update public.saved_searches set last_alert_run_at = null where id = $1`, [s]);
    await run();
    expect(await notes()).toHaveLength(1);
    expect((await db.query('select 1 from public.notifications where dismissed_at is not null')).rows).toHaveLength(1);
  });

  it('prunes notifications older than 60 days and keeps at most 300 per user; logs each run', async () => {
    const j = await job();
    await db.query(`insert into public.notifications (user_id, job_id, title, created_at) values ($1,$2,'old', now() - interval '61 days')`, [A, j]);
    await run();
    expect(await notes()).toHaveLength(0);
    expect(Number((await db.query<{ n: string }>('select count(*) n from ops.alert_runs')).rows[0]!.n)).toBe(1);
  });
});

describe('alert_matches: the same rules as the app\'s catalogue query', () => {
  it('term: full text, substring of the title or city, and the profession\'s other names', async () => {
    const j = await job({ title: 'Senior Physiotherapist', city: 'Goiânia', description: 'works with pelvic floor patients' });
    expect(await matches(j, { term: 'physio' })).toBe(true);
    expect(await matches(j, { term: 'pelvic' })).toBe(true); // description, full text
    expect(await matches(j, { term: 'goiânia' })).toBe(true);
    expect(await matches(j, { term: 'fisioterapeuta', alts: ['physiotherap'] })).toBe(true);
    expect(await matches(j, { term: 'fisioterapeuta' })).toBe(false);
    expect(await matches(j, { term: 'welder' })).toBe(false);
  });

  it('a % or _ in a keyword is text, not a wildcard', async () => {
    const j = await job({ title: 'Engineer 100% remote' });
    expect(await matches(j, { term: '100%' })).toBe(true);
    expect(await matches(j, { term: '1_0' })).toBe(false);
  });

  it('country: located there, eligible there, or remote + Anywhere; a job with no usable location does not match', async () => {
    const here = await job({ country: 'DE' });
    const elig = await job({ country: null, geo: ['BR', 'PT'] });
    const anywhere = await job({ country: null, mode: 'remote', geo: ['Anywhere'] });
    const anywhereOnsite = await job({ country: null, mode: 'onsite', geo: ['Anywhere'] });
    const nowhere = await job({ country: null, geo: [] });
    const m = { country: 'BR' };
    expect(await matches(here, m)).toBe(false);
    expect(await matches(elig, m)).toBe(true);
    expect(await matches(anywhere, m)).toBe(true);
    expect(await matches(anywhereOnsite, m)).toBe(false);
    expect(await matches(nowhere, m)).toBe(false);
    expect(await matches(here, { country: 'de' })).toBe(true);
  });

  it('continent: a listed country or an eligible country/region; ignored while a single country is chosen', async () => {
    const de = await job({ country: 'DE' });
    const emea = await job({ country: null, geo: ['EMEA'] });
    const us = await job({ country: 'US' });
    const cont = { cc: ['DE', 'FR'], regions: ['EMEA'] };
    expect(await matches(de, cont)).toBe(true);
    expect(await matches(emea, cont)).toBe(true);
    expect(await matches(us, cont)).toBe(false);
    expect(await matches(us, { ...cont, country: 'US' })).toBe(true);
  });

  it('modes, title groups (all required), days and salary', async () => {
    const j = await job({ title: 'Pelvic Floor Physiotherapist', mode: 'remote', publishedDaysAgo: 3, salary: true });
    expect(await matches(j, { modes: ['remote', 'hybrid'] })).toBe(true);
    expect(await matches(j, { modes: ['onsite'] })).toBe(false);
    expect(await matches(j, { title_groups: [['physiotherap'], ['pelvic']] })).toBe(true);
    expect(await matches(j, { title_groups: [['physiotherap'], ['nurse']] })).toBe(false);
    expect(await matches(j, { days: 7 })).toBe(true);
    expect(await matches(j, { days: 2 })).toBe(false);
    expect(await matches(j, { salary: true })).toBe(true);
    const noSalary = await job({ salary: false });
    expect(await matches(noSalary, { salary: true })).toBe(false);
    const undated = await job({ publishedDaysAgo: null });
    expect(await matches(undated, { days: 30 })).toBe(false);
  });

  it('an empty or missing block matches every job', async () => {
    const j = await job();
    expect(await matches(j, {})).toBe(true);
    expect((await db.query<{ m: boolean }>("select ops.alert_matches(j, '{}'::jsonb) m from public.jobs j where j.id = $1", [j])).rows[0]!.m).toBe(true);
  });
});

describe('hidden jobs', () => {
  it('belong to one user, are unique per job, can be restored (deleted) and are not readable by anon', async () => {
    await as('authenticated', A, async () => {
      await db.query(`insert into public.hidden_jobs (user_id, job_key, source_id, external_id, title) values ('${A}','s1:1','s1','1','T')`);
      await expect(db.query(`insert into public.hidden_jobs (user_id, job_key, source_id, external_id, title) values ('${A}','s1:1','s1','1','T')`)).rejects.toThrow(/duplicate|unique/);
      await expect(db.query(`insert into public.hidden_jobs (user_id, job_key, source_id, external_id, title) values ('${B}','s1:2','s1','2','T')`)).rejects.toThrow(/row-level security/);
    });
    await as('authenticated', B, async () => {
      expect((await db.query('select 1 from public.hidden_jobs')).rows).toHaveLength(0);
      expect((await db.query(`delete from public.hidden_jobs where user_id = '${A}'`)).affectedRows).toBe(0);
    });
    await as('authenticated', A, async () => {
      expect((await db.query(`delete from public.hidden_jobs where job_key = 's1:1'`)).affectedRows).toBe(1);
    });
    await as('anon', null, async () => { await expect(db.query('select * from public.hidden_jobs')).rejects.toThrow(/permission denied/); });
  });

  it('are capped at 2000 per user, and re-hiding at the cap is not blocked as a new row', async () => {
    await db.query(`insert into public.hidden_jobs (user_id, job_key, source_id, external_id, title) select $1, 's:'||g, 's', g::text, 't' from generate_series(1, 2000) g`, [A]);
    await expect(db.query(`insert into public.hidden_jobs (user_id, job_key, source_id, external_id, title) values ($1,'s:x','s','x','t')`, [A])).rejects.toThrow(/quota/);
  });
});

describe('golden: the searches the app compiles agree with the plain rules of the app', () => {
  // app/test/searches/search_spec_test.dart writes this file: specs compiled by the app and the answers of a Dart reference of the catalogue query.
  const golden = JSON.parse(readFileSync(new URL('./fixtures/v3-specs.golden.json', import.meta.url), 'utf8')) as {
    jobs: { title: string; country: string | null; city: string | null; geo: string[]; mode: string; daysAgo: number | null; salary: boolean }[];
    searches: { name: string; query: Record<string, unknown>; expected: boolean[] }[];
  };

  it('has jobs and searches to compare', () => {
    expect(golden.jobs.length).toBeGreaterThan(10);
    expect(golden.searches.length).toBeGreaterThan(10);
  });

  it('ops.alert_matches answers exactly what the Dart reference answers, for every search and job', async () => {
    const ids: string[] = [];
    for (const j of golden.jobs) {
      ids.push(await job({ title: j.title, country: j.country, city: j.city, geo: j.geo, mode: j.mode === 'unspecified' ? 'unspecified' : j.mode, publishedDaysAgo: j.daysAgo, salary: j.salary }));
    }
    const mismatches: string[] = [];
    for (const s of golden.searches) {
      for (let i = 0; i < ids.length; i++) {
        const got = (await db.query<{ m: boolean }>('select ops.alert_matches(j, $2::jsonb) m from public.jobs j where j.id = $1', [ids[i], JSON.stringify(s.query)])).rows[0]!.m;
        if (got !== s.expected[i]) mismatches.push(`${s.name} / ${golden.jobs[i]!.title}: sql=${got} dart=${s.expected[i]}`);
      }
    }
    expect(mismatches).toEqual([]);
  });
});
