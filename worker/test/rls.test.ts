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
  const migration = (f: string) => readFileSync(new URL(`../../supabase/migrations/${f}`, import.meta.url), 'utf8');
  await db.exec(migration('20261008000000_init.sql'));
  await db.exec(`
    grant usage on schema public to anon, authenticated;
    -- Supabase grants table privileges broadly to anon/authenticated by default; the hardening migration narrows them.
    grant select, insert, update, delete on all tables in schema public to anon, authenticated;
  `);
  await db.exec(migration('20261009000000_rls_hardening.sql'));
  await db.exec(`
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
  it('anonymous users have no privilege on private tables', async () => {
    await as('anon', null, async () => {
      for (const t of ['applications', 'professional_profiles', 'resumes', 'saved_jobs', 'reminders', 'education']) {
        await expect(db.query(`select * from ${t}`)).rejects.toThrow(/permission denied/);
      }
    });
  });
  it('clients only read jobs of redistributable sources', async () => {
    await as('anon', null, async () => {
      expect((await db.query('select title from jobs')).rows).toEqual([{ title: 'Visible job' }]);
    });
  });
  it('clients cannot write the catalogue or touch sync audit', async () => {
    for (const [role, uid] of [['authenticated', A], ['anon', null]] as const) {
      await as(role, uid, async () => {
        await expect(db.query(`insert into jobs (source_id, external_id, company, title, last_checked_at, original_url, fingerprint, canonical_url) values ('open-src','9','c','t',now(),'u','f','c')`)).rejects.toThrow(/permission denied/);
        await expect(db.query(`update job_sources set can_redistribute = true`)).rejects.toThrow(/permission denied/);
        await expect(db.query('select * from sync_runs')).rejects.toThrow(/permission denied/);
      });
    }
  });
  it.each([
    ['education', `insert into education (profile_id, user_id, institution) values ('10000000-0000-0000-0000-000000000002','${A}','x')`],
    ['credentials', `insert into credentials (profile_id, user_id, kind, name) values ('10000000-0000-0000-0000-000000000002','${A}','license','x')`],
    ['resumes', `insert into resumes (profile_id, user_id, storage_path) values ('10000000-0000-0000-0000-000000000002','${A}','${A}/cv.pdf')`],
    ['applications', `insert into applications (user_id, profile_id, job_snapshot) values ('${A}','10000000-0000-0000-0000-000000000002','{}')`],
    ['reminders', `insert into reminders (user_id, application_id, due_at, text) values ('${A}','20000000-0000-0000-0000-000000000002', now(), 'x')`],
  ])('user A cannot link %s to B parent', async (_t, sql) => {
    await as('authenticated', A, async () => {
      await expect(db.query(sql)).rejects.toThrow(/row-level security/);
    });
  });
  it('own children and nullable parents still work', async () => {
    await as('authenticated', A, async () => {
      await db.query(`insert into education (profile_id, user_id, institution) values ('10000000-0000-0000-0000-000000000001','${A}','Uni')`);
      await db.query(`insert into applications (user_id, job_snapshot) values ('${A}','{}')`);
      await db.query(`insert into reminders (user_id, due_at, text) values ('${A}', now(), 'free reminder')`);
      await db.query(`insert into reminders (user_id, application_id, due_at, text) values ('${A}','20000000-0000-0000-0000-000000000001', now(), 'x')`);
    });
  });
  it('resume path must live in the owner folder', async () => {
    await as('authenticated', A, async () => {
      for (const path of [`${B}/cv.pdf`, `${A}/../${B}/cv.pdf`, 'cv.pdf']) {
        await expect(db.query(`insert into resumes (profile_id, user_id, storage_path) values ('10000000-0000-0000-0000-000000000001','${A}','${path}')`)).rejects.toThrow(/violates check constraint|row-level security/);
      }
      await db.query(`insert into resumes (profile_id, user_id, storage_path) values ('10000000-0000-0000-0000-000000000001','${A}','${A}/cv.pdf')`);
    });
  });
  it('only readable jobs can be saved, and only by their owner', async () => {
    const hidden = (await db.query<{ id: string }>(`select id from jobs where title='Hidden job'`)).rows[0]!.id;
    const visible = (await db.query<{ id: string }>(`select id from jobs where title='Visible job'`)).rows[0]!.id;
    await as('authenticated', A, async () => {
      await expect(db.query(`insert into saved_jobs (user_id, job_id) values ('${A}','${hidden}')`)).rejects.toThrow(/row-level security/);
      await db.query(`insert into saved_jobs (user_id, job_id) values ('${A}','${visible}')`);
    });
  });
  it('the app bundle never references the service role', async () => {
    const { readdirSync, readFileSync: read, statSync } = await import('node:fs');
    const { join } = await import('node:path');
    const root = join(import.meta.dirname, '../../app');
    const walk = (d: string): string[] =>
      readdirSync(d).flatMap((n) => {
        const p = join(d, n);
        return statSync(p).isDirectory() ? walk(p) : [p];
      });
    const files = ['lib', 'web', 'android/app/src', 'ios/Runner'].flatMap((d) => walk(join(root, d)));
    expect(files.length).toBeGreaterThan(50); // guards against a vacuous scan
    // AppConfig is the one file allowed to name the key: it is the guard that REJECTS such keys at start-up.
    const guard = join(root, 'lib/core/config/app_config.dart');
    const hits = files.filter((f) => f !== guard && !/\.(png|ttf|otf|ico|webp)$/.test(f) && /service_role|SUPABASE_SERVICE/i.test(read(f, 'latin1')));
    expect(hits).toEqual([]);
  });
});
