import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeAll, describe, expect, it } from 'vitest';
import { JOBICY_SOURCE, normalizeJobicy } from '../src/connectors/jobicy';
import { toJobRow, type JobRow } from '../src/sync';
import feed from './fixtures/jobicy-feed.sanitized.json';

/**
 * The rows the Worker would write, executed against the REAL schema (migrations 1, 2, 6 and 7, in PGlite): CHECK constraints,
 * column types, the unique (source_id, external_id) upsert, the service_role grants and the client-side read policy.
 * Nothing here touches a hosted Supabase project.
 */
let db: PGlite;
const NOW = '2026-10-09T23:30:00.000Z';
const rows: JobRow[] = (feed.jobs as unknown[]).map((raw) => {
  const r = normalizeJobicy(raw, NOW);
  if (!r.ok) throw new Error(r.reason);
  return toJobRow(r.job);
});

const COLS = Object.keys(rows[0]!) as (keyof JobRow)[];
const UPSERT = `
  insert into public.jobs (${COLS.join(', ')})
  select ${COLS.join(', ')} from json_populate_recordset(null::public.jobs, $1::json)
  on conflict (source_id, external_id) do update set ${COLS.filter((c) => c !== 'source_id' && c !== 'external_id').map((c) => `${c} = excluded.${c}`).join(', ')}`;

async function as(role: string, fn: () => Promise<void>) {
  await db.exec(`set role ${role}`);
  try { await fn(); } finally { await db.exec('reset role'); }
}

beforeAll(async () => {
  db = new PGlite({ extensions: { pg_trgm } });
  await db.exec(`
    create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
    create schema auth; create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
    grant usage on schema auth to anon, authenticated; grant execute on function auth.uid() to anon, authenticated;
    grant usage on schema public to anon, authenticated, service_role;
  `);
  const migration = (f: string) => readFileSync(new URL(`../../supabase/migrations/${f}`, import.meta.url), 'utf8');
  await db.exec(migration('20261008000000_init.sql'));
  await db.exec('grant select, insert, update, delete on all tables in schema public to anon, authenticated;');
  await db.exec(migration('20261009000000_rls_hardening.sql'));
  await db.exec(migration('20261013000000_service_role_grants.sql'));
  await db.exec(migration('20261014000000_service_role_least_privilege.sql'));
});

describe('Jobicy rows against the real schema', () => {
  it('the OWNER creates the source row with the attribution text; service_role can read it but never create or change it', async () => {
    // the owner (postgres) creates and publishes sources, never the sync
    await db.query('insert into public.job_sources (id, status, attribution, can_redistribute) values ($1,$2,$3,$4)',
      [JOBICY_SOURCE.id, JOBICY_SOURCE.status, JOBICY_SOURCE.attribution, true /* models the PUBLISHED state; the real row is born false */]);
    await as('service_role', async () => {
      expect((await db.query('select attribution from public.job_sources')).rows).toEqual([{ attribution: JOBICY_SOURCE.attribution }]);
      await expect(db.query("insert into public.job_sources (id, status, can_redistribute) values ('evil', 'READY', true)")).rejects.toThrow(/permission denied/);
      await expect(db.query("update public.job_sources set can_redistribute = false where id = 'jobicy'")).rejects.toThrow(/permission denied/);
      await expect(db.query("update public.job_sources set attribution = 'x' where id = 'jobicy'")).rejects.toThrow(/permission denied/);
    });
  });

  it('every normalized real listing satisfies the table constraints and upserts twice into the same rows', async () => {
    await as('service_role', async () => {
      await db.query(UPSERT, [JSON.stringify(rows)]);
      await db.query(UPSERT, [JSON.stringify(rows)]); // idempotent: same page again
    });
    const n = await db.query<{ n: number }>('select count(*)::int as n from public.jobs');
    expect(n.rows[0]!.n).toBe(rows.length);
  });

  it('stores values exactly as normalized (salary, region lists, source URL, canonical URL)', async () => {
    const r = (await db.query<Record<string, unknown>>("select * from public.jobs where external_id = '154956'")).rows[0]!;
    expect(r).toMatchObject({
      source_id: 'jobicy', company: 'Juniper Square', country: 'US', work_mode: 'remote', status: 'open',
      salary_min: '120000', salary_max: '145000', salary_currency: 'USD', salary_period: 'year',
      geo_restrictions: ['US'], original_url: 'https://jobicy.com/jobs/154956-account-executive-private-equity',
    });
    const multi = (await db.query<{ geo_restrictions: string[]; country: string | null }>("select geo_restrictions, country from public.jobs where external_id = '154925'")).rows[0]!;
    expect(multi).toEqual({ geo_restrictions: ['CA', 'IE', 'NL', 'PT', 'GB', 'US'], country: null });
    const noSalary = (await db.query<{ salary_min: string | null; salary_period: string | null }>("select salary_min, salary_period from public.jobs where external_id = '154943'")).rows[0]!;
    expect(noSalary).toEqual({ salary_min: null, salary_period: null });
  });

  it('full-text search finds a stored listing by title', async () => {
    const r = await db.query("select external_id from public.jobs where search @@ plainto_tsquery('simple', 'copywriter')");
    expect(r.rows).toEqual([{ external_id: '154950' }]);
  });

  it('service_role can close a job and log a run, with exactly the columns the Worker sends', async () => {
    await as('service_role', async () => {
      await db.query("update public.jobs set status = 'closed', last_checked_at = now() where source_id = 'jobicy' and external_id = any($1)", [['154956']]);
      await db.query(
        'insert into public.sync_runs (source_id, scope, started_at, finished_at, status, fetched, upserted, duplicates, closed, http_errors, error_class) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)',
        ['jobicy', '', NOW, NOW, 'ok', 10, 10, 0, 1, 0, null]);
    });
    expect((await db.query("select status from public.jobs where external_id = '154956'")).rows).toEqual([{ status: 'closed' }]);
  });

  it('a close followed by a re-appearance in the feed reopens the row', async () => {
    await as('service_role', async () => { await db.query(UPSERT, [JSON.stringify(rows)]); });
    expect((await db.query("select status from public.jobs where external_id = '154956'")).rows).toEqual([{ status: 'open' }]);
  });

  it('the exact statements of a revalidation-only run work under the FINAL grants (migrations 6 and 7)', async () => {
    await as('service_role', async () => {
      // preflight/lease: read the source, the open jobs, and the ledger
      expect((await db.query('select id, status, can_redistribute from public.job_sources where id = $1', ['jobicy'])).rows).toHaveLength(1);
      expect((await db.query("select external_id from public.jobs where source_id = 'jobicy' and status = 'open' order by external_id limit 1000")).rows.length).toBeGreaterThan(0);
      const id = '11111111-2222-5333-8444-555555555555'; // the lease's deterministic run id
      await db.query("insert into public.sync_runs (id, source_id, scope, started_at, status) values ($1, 'jobicy', 'revalidate', now(), 'running')", [id]);
      // the pass: confirm a job still open (stamp only), close a confirmed-closed one
      await db.query("update public.jobs set last_checked_at = now() where source_id = 'jobicy' and external_id in ('154950') and status = 'open'");
      await db.query("update public.jobs set status = 'closed', last_checked_at = now() where source_id = 'jobicy' and external_id in ('154943')");
      // the run record
      await db.query("update public.sync_runs set status = 'ok', finished_at = now(), fetched = 0, upserted = 0, closed = 1 where id = $1", [id]);
      expect((await db.query("select status, scope from public.sync_runs where id = $1", [id])).rows).toEqual([{ status: 'ok', scope: 'revalidate' }]);
    });
  });

  it('service_role can never DELETE a job (it would cascade into favourites) nor truncate the table', async () => {
    await as('service_role', async () => {
      await expect(db.query("delete from public.jobs where external_id = '154956'")).rejects.toThrow(/permission denied/);
      await expect(db.query('delete from public.job_clusters')).rejects.toThrow(/permission denied/);
      await expect(db.query('truncate public.jobs')).rejects.toThrow(/permission denied/);
    });
    expect((await db.query<{ n: number }>('select count(*)::int as n from public.jobs')).rows[0]!.n).toBe(rows.length);
  });

  it('service_role still cannot touch user data', async () => {
    await as('service_role', async () => {
      await expect(db.query('select * from public.saved_jobs')).rejects.toThrow(/permission denied/);
      await expect(db.query('delete from public.job_sources')).rejects.toThrow(/permission denied/);
      await expect(db.query('select * from public.resumes')).rejects.toThrow(/permission denied/);
    });
  });

  it('clients read the listings only while the source is marked redistributable', async () => {
    await as('anon', async () => {
      expect((await db.query<{ n: number }>('select count(*)::int as n from public.jobs')).rows[0]!.n).toBe(rows.length);
      await expect(db.query("update public.jobs set title = 'x'")).rejects.toThrow(/permission denied/); // read-only for clients
    });
    await db.query("update public.job_sources set can_redistribute = false where id = 'jobicy'"); // the emergency switch is the OWNER's
    await as('anon', async () => {
      expect((await db.query<{ n: number }>('select count(*)::int as n from public.jobs')).rows[0]!.n).toBe(0);
    });
  });

  it('the source row exposes the attribution text to clients', async () => {
    await as('anon', async () => {
      expect((await db.query('select attribution from public.job_sources where id = $1', ['jobicy'])).rows).toEqual([{ attribution: JOBICY_SOURCE.attribution }]);
    });
  });
});
