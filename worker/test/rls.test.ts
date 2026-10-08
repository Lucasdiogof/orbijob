import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { beforeAll, describe, expect, it } from 'vitest';

const A = '00000000-0000-0000-0000-00000000000a';
const B = '00000000-0000-0000-0000-00000000000b';
let db: PGlite;

async function as(role: 'anon' | 'authenticated', uid: string | null, fn: () => Promise<void>) {
  await db.exec(`set role ${role}; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false);`);
  try { await fn(); } finally { await db.exec('reset role'); }
}

beforeAll(async () => {
  db = new PGlite({ extensions: { pg_trgm } });
  // Minimal stand-in for the Supabase platform pieces the migration depends on.
  await db.exec(`
    create role anon nologin; create role authenticated nologin;
    create schema auth;
    create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema auth to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;
    insert into auth.users values ('${A}'), ('${B}');
  `);
  const sql = readFileSync(new URL('../../supabase/migrations/20261008000000_init.sql', import.meta.url), 'utf8');
  await db.exec(sql);
  await db.exec(`
    grant usage on schema public to anon, authenticated;
    grant select on public.job_sources, public.jobs, public.job_clusters to anon, authenticated;
    -- Supabase grants table privileges broadly to anon/authenticated; RLS is the real gate.
    grant select, insert, update, delete on all tables in schema public to anon, authenticated;
    insert into job_sources values ('open-src','CONDITIONAL',null,true), ('closed-src','RESEARCH',null,false);
    insert into jobs (source_id, external_id, company, title, last_checked_at, original_url, fingerprint, canonical_url) values
      ('open-src','1','Co','Visible job', now(), 'https://x/1', 'f1', 'https://x/1'),
      ('closed-src','2','Co','Hidden job', now(), 'https://x/2', 'f2', 'https://x/2');
    insert into professional_profiles (id, user_id, name) values
      ('10000000-0000-0000-0000-000000000001','${A}','A profile'),
      ('10000000-0000-0000-0000-000000000002','${B}','B profile');
    insert into applications (id, user_id, job_snapshot) values
      ('20000000-0000-0000-0000-000000000001','${A}','{}'),
      ('20000000-0000-0000-0000-000000000002','${B}','{}');
    insert into resumes (profile_id, user_id, storage_path) values
      ('10000000-0000-0000-0000-000000000002','${B}','${B}/cv.pdf');
  `);
});

describe('RLS', () => {
  it('user A sees only own profiles, applications and resumes', async () => {
    await as('authenticated', A, async () => {
      expect((await db.query('select name from professional_profiles')).rows).toEqual([{ name: 'A profile' }]);
      expect((await db.query('select id from applications')).rows).toHaveLength(1);
      expect((await db.query('select id from resumes')).rows).toHaveLength(0);
    });
  });
  it('user A cannot update or delete B rows', async () => {
    await as('authenticated', A, async () => {
      const u = await db.query(`update professional_profiles set name='pwn' where user_id='${B}'`);
      const d = await db.query(`delete from applications where user_id='${B}'`);
      expect(u.affectedRows).toBe(0);
      expect(d.affectedRows).toBe(0);
    });
  });
  it('user A cannot insert a row owned by B', async () => {
    await as('authenticated', A, async () => {
      await expect(db.query(`insert into saved_searches (user_id, query) values ('${B}', '{}')`)).rejects.toThrow(/row-level security/);
    });
  });
  it('user A cannot attach an experience to B profile (parent check)', async () => {
    await as('authenticated', A, async () => {
      await expect(db.query(
        `insert into experiences (profile_id, user_id, company, title) values ('10000000-0000-0000-0000-000000000002','${A}','c','t')`,
      )).rejects.toThrow(/row-level security/);
    });
  });
  it('anonymous users see no private data', async () => {
    await as('anon', null, async () => {
      for (const t of ['applications', 'professional_profiles', 'resumes', 'saved_jobs']) {
        expect((await db.query(`select * from ${t}`)).rows).toHaveLength(0);
      }
    });
  });
  it('clients only read jobs of redistributable sources', async () => {
    await as('anon', null, async () => {
      expect((await db.query('select title from jobs')).rows).toEqual([{ title: 'Visible job' }]);
    });
  });
  it('clients cannot write jobs or read sync audit', async () => {
    await as('authenticated', A, async () => {
      await expect(db.query(`insert into jobs (source_id, external_id, company, title, last_checked_at, original_url, fingerprint, canonical_url) values ('open-src','9','c','t',now(),'u','f','c')`)).rejects.toThrow(/row-level security/);
      expect((await db.query('select * from sync_runs')).rows).toHaveLength(0);
    });
  });
});
