import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeEach, describe, expect, it } from 'vitest';

/**
 * scripts/supabase/ops/publish_jobicy.sql is the ONLY thing in the repository allowed to switch can_redistribute on. It must
 * refuse unless the owner's switch is set AND the stored records look right. Run here against the real schema (PGlite).
 */
const PUBLISH = readFileSync(new URL('../../scripts/supabase/ops/publish_jobicy.sql', import.meta.url), 'utf8');
const migration = (f: string) => readFileSync(new URL(`../../supabase/migrations/${f}`, import.meta.url), 'utf8');
const AUTH = "set orbijob.publish_jobicy = 'EU-REVISEI-OS-REGISTROS-E-AUTORIZO';";
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
  await db.exec(migration('20261013000000_service_role_grants.sql'));
  await db.exec("insert into public.job_sources (id, status, attribution, can_redistribute) values ('jobicy','CONDITIONAL','Remote jobs via Jobicy (https://jobicy.com)',false)");
}
const addJob = (url = 'https://jobicy.com/jobs/1-x') => db.query(
  "insert into public.jobs (source_id, external_id, company, title, last_checked_at, original_url, canonical_url, fingerprint) values ('jobicy','1','c','t', now(), $1, $1, 'fp')", [url]);
const addRun = (status = 'ok', errorClass: string | null = null) => db.query("insert into public.sync_runs (source_id, status, finished_at, error_class) values ('jobicy', $1, now(), $2)", [status, errorClass]);
const published = async () => (await db.query<{ v: boolean }>("select can_redistribute as v from public.job_sources where id='jobicy'")).rows[0]!.v;

beforeEach(reset);

describe('publish_jobicy.sql guard', () => {
  it('refuses to run as written, even with a perfect catalogue (no owner switch)', async () => {
    await addRun(); await addJob();
    await expect(db.exec(PUBLISH)).rejects.toThrow(/autorizacao explicita/);
    expect(await published()).toBe(false);
  });
  it('refuses a wrong switch value', async () => {
    await addRun(); await addJob();
    await expect(db.exec(`set orbijob.publish_jobicy = 'yes'; ${PUBLISH}`)).rejects.toThrow(/autorizacao explicita/);
    expect(await published()).toBe(false);
  });
  it.each([
    ['no sync run', async () => { await addJob(); }, /nenhuma passada/],
    ['only a partial run', async () => { await addRun('partial'); await addJob(); }, /nenhuma passada/],
    ['only a failed run', async () => { await addRun('failed'); await addJob(); }, /nenhuma passada/],
    ['a partial run stopped by an HTTP error', async () => { await addRun('partial', 'http_500'); await addJob(); }, /nenhuma passada/],
    ['a good run plus a failed one', async () => { await addRun(); await addRun('failed', 'http_429'); await addJob(); }, /failed.running/],
    ['no jobs', async () => { await addRun(); }, /nao ha vagas/],
    ['a job outside jobicy.com', async () => { await addRun(); await addJob('https://jobicy.com.evil.io/x'); }, /fora de https:\/\/jobicy.com/],
    ['a job with an http url', async () => { await addRun(); await addJob('http://jobicy.com/x'); }, /fora de https:\/\/jobicy.com/],
  ])('refuses with the switch set but: %s', async (_n, setup, msg) => {
    await setup();
    await expect(db.exec(`${AUTH} ${PUBLISH}`)).rejects.toThrow(msg);
    expect(await published()).toBe(false);
  });
  it('accepts a pass that only stopped at the page cap (partial/max_pages): the expected first-ingestion outcome', async () => {
    await addRun('partial', 'max_pages'); await addJob();
    await db.exec(`${AUTH} ${PUBLISH}`);
    expect(await published()).toBe(true);
  });
  it('refuses when the source is not CONDITIONAL or has no attribution', async () => {
    await addRun(); await addJob();
    await db.exec("update public.job_sources set status = 'READY' where id = 'jobicy'");
    await expect(db.exec(`${AUTH} ${PUBLISH}`)).rejects.toThrow(/CONDITIONAL/);
    await db.exec("update public.job_sources set status = 'CONDITIONAL', attribution = ' ' where id = 'jobicy'");
    await expect(db.exec(`${AUTH} ${PUBLISH}`)).rejects.toThrow(/atribuicao/);
  });
  it('publishes only when the switch is set and every check passes; clients then see the job; a second run refuses', async () => {
    await addRun(); await addJob();
    await db.exec(`${AUTH} ${PUBLISH}`);
    expect(await published()).toBe(true);
    await db.exec('set role anon');
    expect((await db.query<{ n: number }>('select count(*)::int as n from public.jobs')).rows[0]!.n).toBe(1);
    await db.exec('reset role');
    await expect(db.exec(`${AUTH} ${PUBLISH}`)).rejects.toThrow(/ja esta publicada/);
  });
  it('before publishing, clients (anon AND signed-in users, i.e. the Flutter app) see no job even though one is stored', async () => {
    await addRun(); await addJob();
    for (const role of ['anon', 'authenticated']) {
      await db.exec(`set role ${role}`);
      expect((await db.query<{ n: number }>('select count(*)::int as n from public.jobs')).rows[0]!.n).toBe(0);
      await db.exec('reset role');
    }
  });
});
