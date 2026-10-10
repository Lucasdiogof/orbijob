import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';
import { buildPlan, renderReport, renderSql, type StoredRow } from '../src/quality-plan';

// The generated correction SQL is exercised against the real schema (PGlite), because its safety properties ARE the feature.
const migration = (f: string) => readFileSync(new URL(`../../supabase/migrations/${f}`, import.meta.url), 'utf8');
let db: PGlite;

async function reset() {
  db = new PGlite({ extensions: { pg_trgm } });
  await db.exec(`
    create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
    create schema auth; create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
    grant usage on schema auth to anon, authenticated; grant execute on function auth.uid() to anon, authenticated;
    grant usage on schema public to anon, authenticated, service_role;
  `);
  await db.exec(migration('20261008000000_init.sql'));
  await db.exec('grant select, insert, update, delete on all tables in schema public to anon, authenticated;');
  await db.exec(migration('20261009000000_rls_hardening.sql'));
  await db.exec("insert into public.job_sources (id, status, attribution, can_redistribute) values ('jobicy','CONDITIONAL','Remote jobs via Jobicy (https://jobicy.com)',false)");
}

const DIRTY = '**About us**\r\n\r\n* Remote\r\n\r\nApply: careers@example.com, ask jane.doe@example.com. R&amp;amp;D';
const CLEAN = 'About us\n\n- Remote\n\nApply: careers@example.com, ask [e-mail]. R&D';
interface Seed { ext: string; desc: string; geo?: string[]; country?: string | null; min?: number | null; max?: number | null; per?: string | null }
async function seed(rows: Seed[]) {
  for (const r of rows) {
    await db.query(
      `insert into public.jobs (source_id, external_id, company, title, description, last_checked_at, original_url, canonical_url, fingerprint,
                                geo_restrictions, country, salary_min, salary_max, salary_currency, salary_period, work_mode)
       values ('jobicy', $1, 'c', 't', $2, now(), 'https://jobicy.com/jobs/'||$1, 'https://jobicy.com/jobs/'||$1, 'fp'||$1, $3, $4, $5, $6, $7, $8, 'remote')`,
      [r.ext, r.desc, r.geo ?? [], r.country ?? null, r.min ?? null, r.max ?? null, r.per ? 'USD' : null, r.per ?? null]);
  }
}
async function stored(): Promise<StoredRow[]> {
  const r = await db.query<StoredRow>(`select external_id, description, md5(description) as description_md5, geo_restrictions, country,
    salary_min::float8 as salary_min, salary_max::float8 as salary_max, salary_currency, salary_period from public.jobs where source_id = 'jobicy' order by external_id`);
  return r.rows;
}
/** A failed script leaves the session inside the aborted transaction (as psql would, until the connection ends): roll it back, like the server does. */
const expectAborted = async (sql: string, msg: RegExp) => { await expect(db.exec(sql)).rejects.toThrow(msg); await db.exec('rollback'); };
const desc = async (ext: string) => (await db.query<{ d: string }>("select description as d from public.jobs where external_id = $1", [ext])).rows[0]!.d;

beforeEach(reset);

describe('buildPlan', () => {
  it('lists only rows whose description really changes; leaves clean text, null and untouched ones out', async () => {
    await seed([{ ext: '1', desc: DIRTY }, { ext: '2', desc: 'Already clean text.' }, { ext: '3', desc: '' }]);
    const plan = buildPlan(await stored());
    expect(plan.description.map((c) => c.externalId)).toEqual(['1']);
    expect(plan.description[0]).toMatchObject({ after: CLEAN, emailsMasked: 1 });
  });
  it('salaries are only LISTED (never corrected): 168-220 per year needs the source', async () => {
    await seed([{ ext: '152711', desc: '', min: 168, max: 220, per: 'year' }, { ext: '9', desc: '', min: 120000, max: 145000, per: 'year' }]);
    const plan = buildPlan(await stored());
    expect(plan.salaryNeedsSource).toEqual([expect.objectContaining({ externalId: '152711', min: 168, max: 220, verdict: 'suspicious' })]);
    expect(renderSql(plan)).not.toMatch(/salary/i);
  });
  it('an empty geo list is rewritten to Anywhere ONLY with source evidence; otherwise it stays unresolved', async () => {
    await seed([{ ext: '5', desc: '' }, { ext: '6', desc: '' }, { ext: '7', desc: '', geo: ['US'], country: 'US' }]);
    const none = buildPlan(await stored());
    expect(none.geo).toEqual([]);
    expect(none.geoUnresolved).toEqual(['5', '6']);
    const withEvidence = buildPlan(await stored(), { '5': 'Anywhere', '6': 'USA', '7': 'Anywhere' });
    expect(withEvidence.geo).toEqual([{ externalId: '5', to: ['Anywhere'] }]);
    expect(withEvidence.geoUnresolved).toEqual(['6']);
  });
  it('the report has counts and ids but no description text and no address', async () => {
    await seed([{ ext: '1', desc: DIRTY }]);
    const report = renderReport(buildPlan(await stored()));
    expect(report).toContain('descriptions that would change: 1');
    expect(report).not.toContain('careers@');
    expect(report).not.toContain('jane.doe');
    expect(report).not.toContain('About us');
  });
});

describe('renderSql: the generated correction is guarded', () => {
  it('changes exactly the planned descriptions and nothing else (other columns, other rows, can_redistribute)', async () => {
    await seed([{ ext: '1', desc: DIRTY, min: 168, max: 220, per: 'year' }, { ext: '2', desc: 'Already clean text.' }]);
    const before = await db.query("select external_id, title, company, salary_min, salary_max, geo_restrictions, status from public.jobs order by 1");
    await db.exec(renderSql(buildPlan(await stored())));
    expect(await desc('1')).toBe(CLEAN);
    expect(await desc('2')).toBe('Already clean text.');
    expect((await db.query("select external_id, title, company, salary_min, salary_max, geo_restrictions, status from public.jobs order by 1")).rows).toEqual(before.rows);
    expect((await db.query<{ v: boolean }>("select can_redistribute as v from public.job_sources where id='jobicy'")).rows[0]!.v).toBe(false);
  });
  it('sets Anywhere only on the confirmed row whose list is still empty', async () => {
    await seed([{ ext: '5', desc: '' }, { ext: '6', desc: '' }]);
    await db.exec(renderSql(buildPlan(await stored(), { '5': 'Anywhere' })));
    const g = (await db.query<{ external_id: string; geo_restrictions: string[] }>("select external_id, geo_restrictions from public.jobs order by 1")).rows;
    expect(g).toEqual([{ external_id: '5', geo_restrictions: ['Anywhere'] }, { external_id: '6', geo_restrictions: [] }]);
  });
  it('aborts and changes nothing if a row was edited after the plan (md5 guard)', async () => {
    await seed([{ ext: '1', desc: DIRTY }, { ext: '2', desc: DIRTY }]);
    const sql = renderSql(buildPlan(await stored()));
    await db.query("update public.jobs set description = description || ' edited' where external_id = '2'");
    await expectAborted(sql, /expected 2 rows, changed 1/);
    expect(await desc('1')).toBe(DIRTY);
  });
  it('aborts if a row appeared or disappeared since the plan (unexpected records)', async () => {
    await seed([{ ext: '1', desc: DIRTY }]);
    const sql = renderSql(buildPlan(await stored()));
    await seed([{ ext: '3', desc: 'new row' }]);
    await expectAborted(sql, /changed since the plan/);
    expect(await desc('1')).toBe(DIRTY);
  });
  it('a second run aborts instead of silently doing nothing (the guard no longer matches)', async () => {
    await seed([{ ext: '1', desc: DIRTY }]);
    const sql = renderSql(buildPlan(await stored()));
    await db.exec(sql);
    await expectAborted(sql, /expected 1 rows, changed 0/);
    expect(await desc('1')).toBe(CLEAN);
  });
  it('text that looks like SQL or contains dollar quotes is stored literally', async () => {
    const nasty = "**x** '; drop table public.jobs; -- $q0$ $$ y";
    await seed([{ ext: '1', desc: nasty }]);
    await db.exec(renderSql(buildPlan(await stored())));
    expect(await desc('1')).toBe("x '; drop table public.jobs; -- $q0$ $$ y");
    expect((await db.query("select count(*)::int as n from public.jobs")).rows).toEqual([{ n: 1 }]);
  });
  it('nothing to change produces a transaction with only the row-count guard', async () => {
    await seed([{ ext: '1', desc: 'fine' }]);
    const sql = renderSql(buildPlan(await stored()));
    expect(sql).not.toContain('update public.jobs');
    await db.exec(sql);
  });
});
