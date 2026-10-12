import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';

/**
 * Migration 20261017000000: retention for EVERY source, and the expiry of jobs a feed-based source no longer lists. Real schema in PGlite
 * with every migration applied. Nothing here touches a hosted project.
 */
const file = (p: string) => readFileSync(new URL(`../../${p}`, import.meta.url), 'utf8');
const ENABLE = file('scripts/supabase/ops/enable_sources_maintenance_cron.sql');
const DISABLE = file('scripts/supabase/ops/disable_sources_maintenance_cron.sql');
const DOWN = file('supabase/rollback/20261017000000_sources_maintenance.down.sql');
const SWITCH = "set orbijob.enable_sources_maintenance = 'EU-AUTORIZO-A-EXPIRACAO-AUTOMATICA';";
const PHRASE = 'EU-AUTORIZO-A-EXPIRACAO';
const RET = 'EU-AUTORIZO-A-RETENCAO';
let db: PGlite;

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
  await db.exec(CRON_STUB + STORAGE_STUB);
  const dir = new URL('../../supabase/migrations/', import.meta.url);
  for (const f of readdirSync(dir).sort()) {
    await db.exec(readFileSync(new URL(f, dir), 'utf8'));
    if (f.startsWith('20261008')) await db.exec('grant select, insert, update, delete on all tables in schema public to anon, authenticated;');
  }
  await db.exec(`insert into public.job_sources (id, status, attribution, can_redistribute) values
    ('jobicy','CONDITIONAL','Remote jobs via Jobicy (https://jobicy.com)',true),
    ('arbeitnow','CONDITIONAL','Jobs via Arbeitnow (https://www.arbeitnow.com)',true),
    ('remoteok','CONDITIONAL','Remote jobs via Remote OK (https://remoteok.com)',true)`);
});

let seq = 0;
/** A job whose last verification was `ageDays` days ago. */
async function job(o: { source: string; status?: string; ageDays: number; body?: string; publishedDaysAgo?: number }) {
  const ext = String(++seq + 5000);
  await db.query(
    `insert into public.jobs (source_id, external_id, company, title, description, requirements, skills, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status, published_at)
     values ($1,$2,'Acme','Role '||$2,$3,'{"x"}','{"y"}','remote', now() - ($4 || ' days')::interval,'https://example.com/jobs/'||$2,'https://example.com/jobs/'||$2,'fp-'||$1||$2,$5, now() - ($6 || ' days')::interval)`,
    [o.source, ext, o.body ?? 'a long description', String(o.ageDays), o.status ?? 'open', String(o.publishedDaysAgo ?? o.ageDays + 1)]);
  return ext;
}
const row = async (ext: string) => (await db.query<Record<string, unknown>>('select * from public.jobs where external_id = $1', [ext])).rows[0];
const count = async (sql: string) => Number((await db.query<{ n: string }>(`select count(*) n from (${sql}) t`)).rows[0]!.n);
/** An ok pass of `source`; for Arbeitnow (read as a window) it also saw one job published `floorDays` ago: the oldest point its window reached. */
const okRun = async (source: string, hoursAgo = 1, status = 'ok', floorDays = 60) => {
  if (source === 'arbeitnow' && status === 'ok') await job({ source, ageDays: 0, publishedDaysAgo: floorDays });
  return okRunOnly(source, hoursAgo, status);
};
const okRunOnly = (source: string, hoursAgo = 1, status = 'ok') => db.query(
  "insert into public.sync_runs (source_id, scope, status, started_at, finished_at) values ($1,'discover',$2, now() - ($3 || ' hours')::interval, now() - ($3 || ' hours')::interval)", [source, status, String(hoursAgo)]);
const expire = async (extra = '') => (await db.query<{ r: string }>(`select ops.expire_unseen_jobs('${PHRASE}'${extra}) r`)).rows[0]!.r;
const retention = async (extra = '') => (await db.query<{ r: string }>(`select ops.jobicy_retention_apply('${RET}'${extra}) r`)).rows[0]!.r;

describe('retention now covers every source (same policy, same guards)', () => {
  it('compacts and deletes closed jobs of any source; open jobs of any source are never touched', async () => {
    const open = await job({ source: 'arbeitnow', ageDays: 400 });
    const compact = await job({ source: 'arbeitnow', status: 'closed', ageDays: 30 });
    const del = await job({ source: 'remoteok', status: 'closed', ageDays: 120 });
    const keepJobicy = await job({ source: 'jobicy', status: 'closed', ageDays: 3 });
    for (let i = 0; i < 20; i++) await job({ source: 'arbeitnow', ageDays: 1 }); // keeps the 20 % brake out of the way
    expect(await retention()).toBe('ok:compacted=1,deleted=1');
    expect((await row(open))!.description).toBe('a long description');
    expect(await row(compact)).toMatchObject({ description: '', status: 'closed', source_id: 'arbeitnow' });
    expect(await row(del)).toBeUndefined();
    expect((await row(keepJobicy))!.description).toBe('a long description');
    expect((await db.query('select source_id, external_id from ops.job_tombstones')).rows).toEqual([{ source_id: 'remoteok', external_id: del }]);
  });

  it('the plan counts every source, and export/restore round-trip a job of another source', async () => {
    await job({ source: 'arbeitnow', ageDays: 2 });
    const id = await job({ source: 'arbeitnow', status: 'closed', ageDays: 200 });
    const plan = Object.fromEntries((await db.query<{ layer: string; jobs: string }>('select * from ops.jobicy_retention_plan()')).rows.map((r) => [r.layer, Number(r.jobs)]));
    expect(plan).toMatchObject({ open: 1, closed_to_delete: 1 });
    const exported = (await db.query<{ e: unknown[] }>('select ops.jobicy_retention_export() e')).rows[0]!.e;
    expect(exported).toHaveLength(1);
    expect(await retention()).toBe('ok:compacted=0,deleted=1');
    expect(await row(id)).toBeUndefined();
    expect((await db.query<{ r: string }>('select ops.jobicy_retention_restore($1, $2::jsonb) r', ['EU-AUTORIZO-A-RESTAURACAO', JSON.stringify(exported)])).rows[0]!.r).toBe('ok:reinserted=1,restored=0');
    expect(await row(id)).toMatchObject({ source_id: 'arbeitnow', description: 'a long description', status: 'closed' });
  });
});

describe('ops.expire_unseen_jobs', () => {
  it('Arbeitnow (a window of the newest pages): a job older than what the last ok pass reached is never closed, a newer unseen one is', async () => {
    await okRun('arbeitnow', 1, 'ok', 5); // the window reached jobs published 5 days ago
    const beyond = await job({ source: 'arbeitnow', ageDays: 9, publishedDaysAgo: 12 }); // older than the window: not seen, not judged
    const gone = await job({ source: 'arbeitnow', ageDays: 9, publishedDaysAgo: 3 }); // inside the window and not listed: gone from the feed
    expect(await expire()).toBe('ok:expired=1,skipped=remoteok/remotive');
    expect((await row(beyond))!.status).toBe('open');
    expect((await row(gone))!.status).toBe('closed');
  });

  it('Arbeitnow with an ok pass that saw nothing (no floor) is skipped, never judged', async () => {
    await okRunOnly('arbeitnow');
    const old = await job({ source: 'arbeitnow', ageDays: 30 });
    expect(await expire()).toBe('ok:expired=0,skipped=arbeitnow/remoteok/remotive');
    expect((await row(old))!.status).toBe('open');
  });

  it('a source read whole (Remote OK) has no floor: an old unseen job is closed', async () => {
    await okRunOnly('remoteok');
    const old = await job({ source: 'remoteok', ageDays: 9, publishedDaysAgo: 80 });
    expect(await expire()).toBe('ok:expired=1,skipped=arbeitnow/remotive');
    expect((await row(old))!.status).toBe('closed');
  });

  it('closes the open jobs a feed-based source has not listed for more than 7 days, and only those', async () => {
    await okRun('arbeitnow');
    const stale = await job({ source: 'arbeitnow', ageDays: 9 });
    const fresh = await job({ source: 'arbeitnow', ageDays: 2 });
    const edge = await job({ source: 'arbeitnow', ageDays: 6.9 as unknown as number });
    const alreadyClosed = await job({ source: 'arbeitnow', status: 'closed', ageDays: 20 });
    const before = await row(alreadyClosed);
    expect(await expire()).toBe('ok:expired=1,skipped=remoteok/remotive');
    expect(await row(stale)).toMatchObject({ status: 'closed' });
    expect((await row(stale))!.description).toBe('a long description'); // compaction is the retention's job, 14 days later
    expect(Date.now() - new Date(String((await row(stale))!.last_checked_at)).getTime()).toBeLessThan(60_000); // dated at the closure
    expect((await row(fresh))!.status).toBe('open');
    expect((await row(edge))!.status).toBe('open');
    expect(await row(alreadyClosed)).toEqual(before);
    expect(await expire()).toBe('ok:expired=0,skipped=remoteok/remotive'); // idempotent
  });

  it('never judges a source whose feed was not read successfully in the last 36 hours (absence would prove nothing)', async () => {
    const old = await job({ source: 'arbeitnow', ageDays: 30 });
    expect(await expire()).toBe('ok:expired=0,skipped=arbeitnow/remoteok/remotive');
    await okRun('arbeitnow', 40); // too old
    await okRun('arbeitnow', 1, 'failed');
    await okRun('arbeitnow', 1, 'partial');
    expect(await expire()).toContain('skipped=arbeitnow');
    expect((await row(old))!.status).toBe('open');
    await okRun('arbeitnow', 2);
    expect(await expire()).toBe('ok:expired=1,skipped=remoteok/remotive');
  });

  it('never touches Jobicy (it has a status endpoint) and refuses to be asked to', async () => {
    await okRun('jobicy');
    const j = await job({ source: 'jobicy', ageDays: 60 });
    await expect(db.query(`select ops.expire_unseen_jobs('${PHRASE}', interval '7 days', array['jobicy'])`)).rejects.toThrow(/jobicy tem endpoint/);
    await expire();
    expect((await row(j))!.status).toBe('open');
  });

  it('refuses without the owner phrase, with a window under 4 days, and with a silly batch; nothing changes', async () => {
    await okRun('arbeitnow');
    const j = await job({ source: 'arbeitnow', ageDays: 30 });
    await expect(db.query('select ops.expire_unseen_jobs(null)')).rejects.toThrow(/frase de autorizacao/);
    await expect(db.query("select ops.expire_unseen_jobs('sim')")).rejects.toThrow(/frase de autorizacao/);
    await expect(expire(", interval '1 day'")).rejects.toThrow(/minimo e 4 dias/);
    await expect(expire(", interval '7 days', array['arbeitnow'], 0")).rejects.toThrow(/batch entre/);
    expect((await row(j))!.status).toBe('open');
  });

  it('acts on at most p_batch jobs per source per call', async () => {
    await okRun('arbeitnow');
    for (let i = 0; i < 5; i++) await job({ source: 'arbeitnow', ageDays: 20 });
    expect(await expire(", interval '7 days', array['arbeitnow'], 2")).toBe('ok:expired=2');
    expect(await expire(", interval '7 days', array['arbeitnow'], 2")).toBe('ok:expired=2');
    expect(await expire(", interval '7 days', array['arbeitnow'], 2")).toBe('ok:expired=1');
    expect(await count("select 1 from public.jobs where status = 'open'")).toBe(1); // only the job the pass just saw
  });

  it('logs in ops.retention_runs, never in sync_runs (so no lease is affected), and leaves user data alone', async () => {
    await okRun('arbeitnow');
    await job({ source: 'arbeitnow', ageDays: 20 });
    const runs = await count('select 1 from public.sync_runs');
    await expire();
    expect((await db.query<{ outcome: string }>('select outcome from ops.retention_runs')).rows[0]!.outcome).toMatch(/^expire:ok:expired=1/);
    expect(await count('select 1 from public.sync_runs')).toBe(runs);
  });

  it('is closed to the API roles', async () => {
    for (const role of ['anon', 'authenticated', 'service_role']) {
      await db.exec(`set role ${role}`);
      await expect(db.query(`select ops.expire_unseen_jobs('${PHRASE}')`)).rejects.toThrow(/permission denied/);
      await db.exec('reset role');
    }
  });
});

describe('scheduling and rollback', () => {
  it('the migration schedules nothing; the enable script needs the phrase and schedules one daily job; disable removes it', async () => {
    expect(await count('select 1 from cron.job')).toBe(0);
    await expect(db.exec(ENABLE)).rejects.toThrow(/autorizacao explicita/);
    await expect(db.exec("set orbijob.enable_sources_maintenance = 'sim'; " + ENABLE)).rejects.toThrow(/autorizacao explicita/);
    await db.exec(SWITCH + ENABLE);
    expect((await db.query('select jobname, schedule, command from cron.job')).rows).toEqual([
      { jobname: 'sources-expire-unseen', schedule: '12 4 * * *', command: "select ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO')" },
    ]);
    await db.exec(DISABLE);
    await db.exec(DISABLE);
    expect(await count('select 1 from cron.job')).toBe(0);
  });

  it('the scheduled command runs as written', async () => {
    await okRun('arbeitnow');
    const j = await job({ source: 'arbeitnow', ageDays: 20 });
    await db.exec(SWITCH + ENABLE);
    const cmd = (await db.query<{ command: string }>('select command from cron.job')).rows[0]!.command;
    expect((await db.query(cmd)).rows).toHaveLength(1);
    expect((await row(j))!.status).toBe('closed');
  });

  it('the rollback drops the expiry and the schedule, puts the Jobicy-only retention back, and leaves every job as it is', async () => {
    await db.exec(SWITCH + ENABLE);
    await okRun('arbeitnow');
    const other = await job({ source: 'arbeitnow', status: 'closed', ageDays: 500 });
    const expired = await job({ source: 'arbeitnow', ageDays: 30 });
    await expire();
    await db.exec(DOWN);
    expect(await count('select 1 from cron.job')).toBe(0);
    expect(await count("select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'ops' and p.proname = 'expire_unseen_jobs'")).toBe(0);
    expect((await row(expired))!.status).toBe('closed'); // not reopened
    expect(await retention()).toBe('ok:compacted=0,deleted=0'); // the policy is Jobicy-only again
    expect(await row(other)).toBeDefined();
    await db.exec(DOWN); // idempotent
  });
});
