import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';
import { EXPIRE_MS, FRESH_MS, verificationState } from '../src/freshness';
import { runScheduledSync } from '../src/scheduled';
import { FEED_JOBS, World, storedJob } from './helpers/world';

// Keeping the catalogue honest after publication: new jobs arrive, closed ones close, and a job nobody can vouch for stops
// being presented as open. The real SupabaseJobStore, lease and runSync run against an in-memory Supabase + Jobicy.

const OLD = '2026-10-01T00:00:00.000Z';
const seed = (w: World, ids: string[], lastChecked = OLD) => {
  for (const id of ids) w.jobs.set(`jobicy:${id}`, { ...storedJob(id), last_checked_at: lastChecked });
};
const run = (w: World, extra: Record<string, unknown> = {}, env = w.env()) => runScheduledSync(env, w.deps(extra));
const row = (w: World, id: string) => w.jobs.get(`jobicy:${id}`) as { status: string; last_checked_at: string };
const nextCycle = (w: World, hours = 6) => { w.clock = new Date(w.clock.getTime() + hours * 3_600_000); };
const neverDeletes = (w: World) => expect(w.requests.filter((r) => r.method === 'DELETE')).toEqual([]);

describe('revalidation: jobs that left the 7-day feed are asked about, never guessed', () => {
  it('a new job in the feed is stored open and stamped', async () => {
    const w = new World();
    await run(w);
    expect(w.openIds()).toHaveLength(10);
    expect(row(w, String(FEED_JOBS[0]!.id)).last_checked_at).not.toBe(OLD);
    neverDeletes(w);
  });

  it('a job repeated inside the feed is stored once and counted as a duplicate', async () => {
    const w = new World();
    w.feedPages = [[FEED_JOBS[0]!, FEED_JOBS[0]!, FEED_JOBS[1]!], [FEED_JOBS[1]!]];
    const o = await run(w);
    expect(o).toMatchObject({ status: 'ok', summary: { upserted: 2, duplicates: 2 } });
    expect(w.jobs.size).toBe(2);
  });

  it('confirmed closed: closed and stamped; the row is kept (no delete)', async () => {
    const w = new World(); seed(w, ['111']); w.statuses['111'] = 'closed';
    const o = await run(w);
    expect(o).toMatchObject({ status: 'ok', summary: { closed: 1, confirmed: 0 } });
    expect(row(w, '111').status).toBe('closed');
    expect(w.jobs.has('jobicy:111')).toBe(true);
    neverDeletes(w);
  });

  it('confirmed ACTIVE although it left the feed: stays open and its verification date moves to now', async () => {
    const w = new World(); seed(w, ['222']); w.statuses['222'] = 'active';
    const o = await run(w);
    expect(o).toMatchObject({ status: 'ok', summary: { closed: 0, confirmed: 1, unverified: 0 } });
    expect(row(w, '222').status).toBe('open');
    expect(Date.parse(row(w, '222').last_checked_at)).toBeGreaterThan(Date.parse(OLD));
    expect(w.allLogs()).toContain('"confirmed":1');
  });

  it('"unknown", and an id the source does not answer for, stay exactly as they were (no closure, no new stamp)', async () => {
    const w = new World(); seed(w, ['333', '444']); w.statuses['333'] = 'unknown'; w.statusSilent.add('444');
    const o = await run(w);
    expect(o).toMatchObject({ status: 'ok', summary: { closed: 0, confirmed: 0, unverified: 2 } });
    expect(['333', '444'].map((id) => row(w, id))).toEqual([
      expect.objectContaining({ status: 'open', last_checked_at: OLD }),
      expect.objectContaining({ status: 'open', last_checked_at: OLD }),
    ]);
  });

  it('status endpoint answers HTTP 500: nothing closed, nothing stamped, pass is partial, run recorded', async () => {
    const w = new World(); seed(w, ['111', '222']); w.statuses['111'] = 'closed';
    w.statusFault = () => new Response('{}', { status: 500 });
    const o = await run(w);
    expect(o).toMatchObject({ status: 'partial', summary: { closed: 0, confirmed: 0, error_class: 'http_500', runRecorded: true } });
    expect(['111', '222'].map((id) => row(w, id).status)).toEqual(['open', 'open']);
    expect(row(w, '222').last_checked_at).toBe(OLD);
    expect(w.runs[0]).toMatchObject({ status: 'partial', error_class: 'http_500' });
  });

  it('status endpoint times out: same, and a timeout is classified as such', async () => {
    const w = new World(); seed(w, ['111']); w.statuses['111'] = 'closed';
    w.statusFault = () => Object.assign(new Error('The operation timed out'), { name: 'TimeoutError' });
    const o = await run(w);
    expect(o).toMatchObject({ status: 'partial', summary: { closed: 0, error_class: 'timeout' } });
    expect(row(w, '111').status).toBe('open');
  });

  it('a failure in a LATER status batch keeps what the earlier batch proved', async () => {
    const w = new World(); const ids = Array.from({ length: 150 }, (_, i) => String(1000 + i));
    seed(w, ids); for (const id of ids) w.statuses[id] = 'closed';
    w.statusFault = (n) => (n >= 1 ? new Response('{}', { status: 500 }) : null);
    const o = await run(w);
    expect(o.status).toBe('partial');
    expect(ids.filter((id) => row(w, id).status === 'closed')).toHaveLength(100); // batch 1 stored, batch 2 untouched
    expect(ids.filter((id) => row(w, id).status === 'open')).toHaveLength(50);
  });

  it('incomplete pagination (page cap): partial, and the status check does not run on an unfinished traversal', async () => {
    const w = new World(); seed(w, ['111']); w.statuses['111'] = 'closed';
    const o = await run(w, {}, w.env({ SYNC_MAX_PAGES: '1' }));
    expect(o).toMatchObject({ status: 'partial', summary: { error_class: 'max_pages', closed: 0 } });
    expect(w.calls.status).toBe(0);
    expect(row(w, '111').status).toBe('open');
  });

  it('feed failure on the second page: partial, no closure, no stamp on the old job', async () => {
    const w = new World(); seed(w, ['111']); w.statuses['111'] = 'closed';
    w.jobicyFault = (_n, cursor) => (cursor ? new Response('{}', { status: 500 }) : null);
    const o = await run(w);
    expect(o.status).toBe('partial');
    expect(row(w, '111')).toMatchObject({ status: 'open', last_checked_at: OLD });
  });

  it('two instances at once: one runs, the other is skipped; the source is asked once', async () => {
    const w = new World(); seed(w, ['111']); w.statuses['111'] = 'closed';
    const [a, b] = await Promise.all([run(w), run(w)]);
    expect([a.status, b.status].sort()).toEqual(['ok', 'skipped']);
    expect(w.calls.feed).toBe(2);
    expect(w.calls.status).toBe(1);
    expect(w.runs.filter((r) => r.status === 'ok')).toHaveLength(1);
  });

  it('reprocessing is safe: the next cycle gives the same catalogue, a closed job stays closed, confirmations repeat', async () => {
    const w = new World(); seed(w, ['111', '222']); w.statuses['111'] = 'closed'; w.statuses['222'] = 'active';
    await run(w);
    const snapshot = () => JSON.stringify([...w.jobs.entries()].map(([k, v]) => [k, { ...v, last_checked_at: undefined }]).sort());
    const first = snapshot();
    nextCycle(w);
    const o = await run(w);
    expect(o.status).toBe('ok');
    expect(snapshot()).toBe(first);
    expect(row(w, '111').status).toBe('closed');
    expect(w.runs.map((r) => r.status)).toEqual(['ok', 'ok']);
    neverDeletes(w);
  });

  it('a closed job that reappears in the feed is reopened', async () => {
    const w = new World();
    w.jobs.set(`jobicy:${FEED_JOBS[0]!.id}`, { ...storedJob(String(FEED_JOBS[0]!.id), 'closed'), last_checked_at: OLD });
    await run(w);
    expect(row(w, String(FEED_JOBS[0]!.id)).status).toBe('open');
  });

  it('the pass never touches users: only the jobs, job_sources and sync_runs tables are used, and never with DELETE', async () => {
    const w = new World(); seed(w, ['111', '222']); w.statuses['111'] = 'closed';
    await run(w);
    expect(new Set(w.requests.map((r) => r.table))).toEqual(new Set(['sync_runs', 'jobs']));
    expect(new Set(w.requests.map((r) => r.method))).toEqual(new Set(['GET', 'POST', 'PATCH']));
  });
});

describe('a catalogue nobody has been vouching for stops looking current', () => {
  const now = new Date('2026-10-10T12:00:00.000Z');
  const ago = (ms: number) => new Date(now.getTime() - ms).toISOString();
  it('fresh, aging, expired and unverified', () => {
    expect(verificationState(ago(0), now)).toBe('fresh');
    expect(verificationState(ago(FRESH_MS), now)).toBe('fresh');
    expect(verificationState(ago(FRESH_MS + 1), now)).toBe('aging');
    expect(verificationState(ago(EXPIRE_MS), now)).toBe('aging');
    expect(verificationState(ago(EXPIRE_MS + 1), now)).toBe('expired');
    for (const bad of [null, undefined, '', 'not a date']) expect(verificationState(bad, now)).toBe('unverified');
    expect(verificationState(new Date(now.getTime() + 60_000).toISOString(), now)).toBe('fresh'); // a clock slightly ahead
  });
  it('the first-ingestion stamp of the 299 published jobs expires on 2026-10-13 if no pass confirms them', () => {
    const stamp = '2026-10-10T04:58:16.630Z';
    expect(verificationState(stamp, new Date('2026-10-10T20:00:00Z'))).toBe('aging');
    expect(verificationState(stamp, new Date('2026-10-13T04:58:16Z'))).toBe('aging');
    expect(verificationState(stamp, new Date('2026-10-13T04:58:17Z'))).toBe('expired');
  });
});

describe('closing and expiring never harm what users saved', () => {
  const migration = (f: string) => readFileSync(new URL(`../../supabase/migrations/${f}`, import.meta.url), 'utf8');
  let db: PGlite;
  beforeEach(async () => {
    db = new PGlite({ extensions: { pg_trgm } });
    await db.exec(`create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
      create schema auth; create table auth.users (id uuid primary key);
      create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
      grant usage on schema auth to anon, authenticated; grant execute on function auth.uid() to anon, authenticated; grant usage on schema public to anon, authenticated, service_role;`);
    await db.exec(migration('20261008000000_init.sql'));
    await db.exec(migration('20261009000000_rls_hardening.sql'));
    await db.exec("insert into public.job_sources (id,status,attribution,can_redistribute) values ('jobicy','CONDITIONAL','x',true)");
    await db.exec("insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000aa')");
    await db.exec(`insert into public.jobs (id, source_id, external_id, company, title, description, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status)
      values ('11111111-1111-1111-1111-111111111111','jobicy','1','c','t','d','remote','2026-10-01T00:00:00Z','https://jobicy.com/jobs/1','https://jobicy.com/jobs/1','fp1','open')`);
    await db.exec(`insert into public.saved_jobs (user_id, job_id) values ('00000000-0000-0000-0000-0000000000aa','11111111-1111-1111-1111-111111111111')`);
    await db.exec(`insert into public.applications (user_id, job_id, job_snapshot, stage) values ('00000000-0000-0000-0000-0000000000aa','11111111-1111-1111-1111-111111111111','{"title":"t"}','applied')`);
  });
  const counts = async () => (await db.query<{ s: number; a: number; linked: number }>(
    `select (select count(*)::int from saved_jobs) s, (select count(*)::int from applications) a, (select count(*)::int from applications where job_id is not null) linked`)).rows[0]!;

  it('what the Worker does (status -> closed, stamp moved) leaves favourites and applications intact and linked', async () => {
    await db.exec("update public.jobs set status = 'closed', last_checked_at = now() where source_id = 'jobicy' and external_id in ('1')");
    expect(await counts()).toEqual({ s: 1, a: 1, linked: 1 });
  });
  it('why the Worker must never DELETE a job: it would cascade into favourites and unlink applications', async () => {
    await db.exec("delete from public.jobs where external_id = '1'");
    expect(await counts()).toEqual({ s: 0, a: 1, linked: 0 });
  });
});
