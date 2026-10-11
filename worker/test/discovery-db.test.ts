import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeAll, describe, expect, it } from 'vitest';

/**
 * What the database itself guarantees to the discovery (the Worker runs it with the privileges of migration 7, no more):
 * PostgREST's `resolution=ignore-duplicates` is `INSERT ... ON CONFLICT (source_id, external_id) DO NOTHING`; this runs that exact statement on the
 * real schema in PGlite under the real grants. Nothing here touches a hosted project.
 */
const migration = (f: string) => readFileSync(new URL(`../../supabase/migrations/${f}`, import.meta.url), 'utf8');
let db: PGlite;

const INSERT = `insert into public.jobs (source_id, external_id, company, title, description, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status)
  values ($1, $2, $3, 't', $4, 'remote', now(), 'https://jobicy.com/jobs/' || $2, 'https://jobicy.com/jobs/' || $2, 'fp-' || $2, 'open')
  on conflict (source_id, external_id) do nothing returning external_id`;
const as = async (role: string, fn: () => Promise<unknown>) => { await db.exec(`set role ${role}`); try { return await fn(); } finally { await db.exec('reset role'); } };

beforeAll(async () => {
  db = new PGlite({ extensions: { pg_trgm } });
  await db.exec(`
    create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
    create schema auth; create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
    grant usage on schema auth to anon, authenticated; grant execute on function auth.uid() to anon, authenticated; grant usage on schema public to anon, authenticated, service_role;`);
  await db.exec(migration('20261008000000_init.sql'));
  await db.exec('grant select, insert, update, delete on all tables in schema public to anon, authenticated;');
  for (const f of ['20261009000000_rls_hardening.sql', '20261013000000_service_role_grants.sql', '20261014000000_service_role_least_privilege.sql']) await db.exec(migration(f));
  await db.exec("insert into public.job_sources (id, status, attribution, can_redistribute) values ('jobicy','CONDITIONAL','Remote jobs via Jobicy (https://jobicy.com)',true)");
});

describe('discovery under the privileges of migration 7', () => {
  it('service_role inserts a new listing and gets its id back', async () => {
    const r = await as('service_role', () => db.query(INSERT, ['jobicy', '5001', 'Acme', 'first text']));
    expect((r as { rows: unknown[] }).rows).toEqual([{ external_id: '5001' }]);
  });

  it('an id that is already stored is left byte-identical and nothing is returned (never overwritten, blanked or re-opened)', async () => {
    await db.exec("update public.jobs set status = 'closed', description = 'reviewed text', company = 'Acme Inc' where external_id = '5001'");
    const before = await db.query("select * from public.jobs where external_id = '5001'");
    const r = await as('service_role', () => db.query(INSERT, ['jobicy', '5001', '', '']));
    expect((r as { rows: unknown[] }).rows).toEqual([]);
    const after = await db.query("select * from public.jobs where external_id = '5001'");
    expect(after.rows).toEqual(before.rows);
    expect((after.rows[0] as { status: string }).status).toBe('closed');
  });

  it('the role that runs it cannot delete jobs nor publish/rewrite the source (migration 7)', async () => {
    await expect(as('service_role', () => db.exec("delete from public.jobs where external_id = '5001'"))).rejects.toThrow(/permission denied/);
    await expect(as('service_role', () => db.exec("update public.job_sources set can_redistribute = false where id = 'jobicy'"))).rejects.toThrow(/permission denied/);
    await expect(as('service_role', () => db.exec("insert into public.job_sources (id, status) values ('new','READY')"))).rejects.toThrow(/permission denied/);
    await expect(as('service_role', () => db.exec("select * from public.resumes limit 1"))).rejects.toThrow(/permission denied/);
  });

  it('it cannot invent a source: a listing of an unknown source is refused by the foreign key', async () => {
    await expect(as('service_role', () => db.query(INSERT, ['nope', '1', 'c', 'd']))).rejects.toThrow(/foreign key|violates/);
  });

  it('app users cannot insert jobs at all (no write policy)', async () => {
    await expect(as('anon', () => db.query(INSERT, ['jobicy', '5002', 'c', 'd']))).rejects.toThrow(/row-level security|permission denied/);
    await expect(as('authenticated', () => db.query(INSERT, ['jobicy', '5003', 'c', 'd']))).rejects.toThrow(/row-level security|permission denied/);
  });

  it('what discovery stores is visible to the app only while the source is published; unpublishing hides it all at once', async () => {
    await as('service_role', () => db.query(INSERT, ['jobicy', '5004', 'Acme', 'x']));
    const visible = async () => ((await as('anon', () => db.query("select external_id from public.jobs where status = 'open' order by 1"))) as { rows: { external_id: string }[] }).rows.map((r) => r.external_id);
    expect(await visible()).toEqual(['5004']); // 5001 was closed above
    await db.exec("update public.job_sources set can_redistribute = false where id = 'jobicy'");
    expect(await visible()).toEqual([]);
    await db.exec("update public.job_sources set can_redistribute = true where id = 'jobicy'");
  });
});
