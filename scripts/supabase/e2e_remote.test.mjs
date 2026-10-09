// Tests the E2E script's logic against an in-memory model of Supabase (Auth + PostgREST + Storage with RLS-like rules).
// The model is MY reading of the API (including the policies in the migrations); it proves the script's flow and that
// each check can fail, NOT that the real platform behaves this way. Real validation requires running the script
// against the real project (see docs/SUPABASE_OWNER_RUNBOOK.md).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { run, signup, isSecretKey, parseOnly, SECTIONS, PRIVATE_TABLES, CATALOGUE } from './e2e_remote.mjs';

const REF = 'rpmlfxwebnlxnwadyvle';
const ENV = { ORBIJOB_E2E_CONFIRM: REF, SUPABASE_URL: `https://${REF}.supabase.co`, SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_x',
  E2E_EMAIL_A: 'e2e-a@test.invalid', E2E_EMAIL_B: 'e2e-b@test.invalid', E2E_PASSWORD: 'x', E2E_SIGNED_WAIT_MS: '60' };

const PROFILE_CHILD = { parent: ['profile_id', 'professional_profiles'] };
const META = {
  professional_profiles: {},
  experiences: PROFILE_CHILD, education: PROFILE_CHILD, credentials: PROFILE_CHILD,
  resumes: { ...PROFILE_CHILD, quota: 10 },
  saved_jobs: { quota: 1000, unique: 'job_key' },
  saved_searches: { quota: 100 },
  applications: { parent: ['profile_id', 'professional_profiles', true], quota: 2000 },
  application_events: { parent: ['application_id', 'applications'] },
  reminders: { parent: ['application_id', 'applications', true] },
  user_preferences: { pk: 'user_id' },
  viewed_jobs: { fk: 'job_id' },
};
const CASCADE = { professional_profiles: ['experiences', 'education', 'credentials', 'resumes'], applications: ['application_events', 'reminders'] };

function makeBackend(flaws = {}, preload = {}) {
  const users = { 'e2e-a@test.invalid': 'user-a', 'e2e-b@test.invalid': 'user-b' };
  const tables = Object.fromEntries([...PRIVATE_TABLES, ...CATALOGUE, 'sync_runs'].map((t) => [t, []]));
  for (const [t, r] of Object.entries(preload)) tables[t].push({ id: 'pre1', ...r });
  const writes = [];
  const objects = new Map(); // path -> owner
  const signed = new Map();
  const sessions = new Map(); // refresh -> { user, session, revoked }
  let seq = 0;
  const res = (status, body, headers = {}) => new Response(body === undefined ? null : typeof body === 'string' ? body : JSON.stringify(body), { status, headers });
  const who = (h) => { const t = h.Authorization?.replace('Bearer ', ''); const m = /^tok-(user-[ab])\.(\d+)$/.exec(t ?? ''); return m ? { id: m[1], session: Number(m[2]) } : { bad: !!t }; };
  const match = (row, q) => [...new URLSearchParams(q).entries()].every(([k, v]) => {
    if (['select', 'limit', 'on_conflict'].includes(k)) return true;
    const got = k.includes('->>') ? row[k.split('->>')[0]]?.[k.split('->>')[1]] : row[k];
    if (v === 'not.is.null') return got != null;
    if (v.startsWith('neq.')) return String(got) !== v.slice(4);
    if (v.startsWith('like.')) return String(got ?? '').startsWith(decodeURIComponent(v.slice(5)).replace(/\*$/, ''));
    return String(got) === v.replace(/^eq\./, '');
  });
  const mineOf = (t, me) => tables[t].filter((r) => flaws.noRls || r.user_id === me);
  const parentOk = (t, row, me) => {
    const m = META[t]; if (!m.parent || flaws.noParentCheck) return true;
    const [col, ptable, optional] = m.parent; if (row[col] == null) return !!optional || false;
    const p = tables[ptable].find((x) => x.id === row[col]); return !!p && p.user_id === me;
  };
  const remove = (t, row) => {
    tables[t].splice(tables[t].indexOf(row), 1);
    for (const c of CASCADE[t] ?? []) for (const ch of tables[c].filter((x) => x[c === 'application_events' || c === 'reminders' ? 'application_id' : 'profile_id'] === row.id)) remove(c, ch);
  };

  const handler = async (url, init = {}) => {
    const u = new URL(url); const h = init.headers ?? {}; const w = who(h); const me = w.id; const method = init.method ?? 'GET';
    const prefer = h.Prefer ?? '';
    if (u.pathname === '/auth/v1/signup') return res(200, flaws.autoConfirm ? { access_token: 't', user: {} } : { user: { id: 'x' } });
    if (u.pathname === '/auth/v1/token') {
      const b = JSON.parse(init.body);
      if (u.searchParams.get('grant_type') === 'refresh_token') {
        const s = sessions.get(b.refresh_token); if (!s || s.revoked) return res(400, {});
        const refresh = `ref-${++seq}`; sessions.set(refresh, { ...s }); return res(200, { access_token: `tok-${s.user}.${s.session}`, refresh_token: refresh, user: { id: s.user } });
      }
      const id = users[b.email]; if (!id || b.password !== ENV.E2E_PASSWORD) return res(400, {});
      const session = ++seq; const refresh = `ref-${++seq}`; sessions.set(refresh, { user: id, session, revoked: false });
      return res(200, { access_token: `tok-${id}.${session}`, refresh_token: refresh, user: { id } });
    }
    if (u.pathname === '/auth/v1/logout') {
      if (!me) return res(401, {});
      if (!flaws.logoutNoRevoke) for (const s of sessions.values()) if (s.session === w.session) s.revoked = true;
      return res(204);
    }
    if (u.pathname.startsWith('/rest/v1/')) {
      const t = u.pathname.split('/').pop(); const q = u.search.replace(/^\?/, '');
      if (w.bad) return res(401, { code: 'PGRST301' });
      if (CATALOGUE.includes(t)) {
        if (method === 'GET') return res(200, []);
        return flaws.catalogWritable ? res(201, [{}]) : res(403, { code: '42501' });
      }
      if (t === 'sync_runs') return flaws.syncReadable ? res(200, []) : res(403, { code: '42501' });
      if (!me && !flaws.anonReadsPrivate) return res(401, { code: '42501' });
      if (!me) return res(200, tables[t]);
      const m = META[t]; const visible = mineOf(t, me);
      if (method === 'GET') {
        if (t === 'user_preferences' && /select=id\b/.test(q)) return res(400, { code: '42703', message: 'column user_preferences.id does not exist' });
        const hit = visible.filter((r) => match(r, q));
        return res(prefer.includes('count=exact') ? 206 : 200, hit.slice(0, prefer.includes('count=exact') ? 1 : undefined), prefer.includes('count=exact') ? { 'content-range': `0-0/${hit.length}` } : {});
      }
      if (method === 'POST') {
        writes.push(t);
        if (m.fk) return res(409, { code: '23503' });
        const batch = [].concat(JSON.parse(init.body));
        const merge = prefer.includes('merge-duplicates');
        let have = tables[t].filter((r) => r.user_id === me).length; const made = [];
        for (const b of batch) {
          if (b.user_id !== me && !flaws.noRls) return res(403, { code: '42501' });
          if (!parentOk(t, b, me)) return res(403, { code: '42501' });
          const dup = m.unique ? tables[t].find((r) => r.user_id === b.user_id && r[m.unique] === b[m.unique]) : m.pk ? tables[t].find((r) => r[m.pk] === b[m.pk]) : null;
          if (dup && merge && !flaws.noUpsertExemption) { Object.assign(dup, b); made.push(dup); continue; }
          if (dup) return res(409, { code: '23505' });
          if (m.quota && !flaws.noQuota && have >= m.quota) return res(400, { code: '53400', message: `quota exceeded: at most ${m.quota} rows in ${t}` });
          const row = { id: `r${++seq}`, ...b }; tables[t].push(row); made.push(row); have++;
          if (t === 'applications') tables.application_events.push({ id: `r${++seq}`, application_id: row.id, user_id: row.user_id, stage: 'applied' });
        }
        return prefer.includes('return=minimal') ? res(201) : res(201, made);
      }
      const hit = visible.filter((r) => match(r, q));
      if (method === 'PATCH') {
        const b = JSON.parse(init.body);
        if (!flaws.allowGiveAway && b.user_id && b.user_id !== me) return hit.length ? res(403, { code: '42501' }) : res(200, []);
        if (hit.length && !parentOk(t, { ...hit[0], ...b }, me)) return res(403, { code: '42501' });
        hit.forEach((r) => Object.assign(r, b)); return res(200, hit);
      }
      if (method === 'DELETE') { if (!flaws.cleanupBroken) hit.forEach((r) => remove(t, r)); return res(200, hit); }
    }
    if (u.pathname.startsWith('/storage/v1/')) {
      const p = u.pathname.replace('/storage/v1/', '');
      if (p.startsWith('object/sign/') && u.searchParams.get('token')) {
        const s = signed.get(u.searchParams.get('token'));
        return s && Date.now() < s.expires ? res(200, 'pdf') : res(400, {});
      }
      if (method === 'POST' && p.startsWith('object/sign/')) {
        const path = p.replace('object/sign/resumes/', ''); const o = objects.get(path);
        if (!me || !o || (o !== me && !flaws.noRls)) return res(404, {});
        const token = `t${++seq}`; signed.set(token, { path, expires: Date.now() + (flaws.neverExpires ? 1e9 : 20) });
        return res(200, { signedURL: `/object/sign/resumes/${path}?token=${token}` });
      }
      if (p.startsWith('object/public/')) return flaws.publicBucket ? res(200, 'pdf') : res(400, {});
      if (p.startsWith('object/authenticated/resumes/')) {
        const o = objects.get(p.replace('object/authenticated/resumes/', ''));
        return me && o && (o === me || flaws.noRls) ? res(200, 'pdf') : res(404, {});
      }
      if (method === 'POST' && p === 'object/list/resumes') {
        const prefix = JSON.parse(init.body).prefix;
        if (!me && !flaws.anonUpload) return res(401, {});
        const names = [...objects.entries()].filter(([path, owner]) => path.startsWith(`${prefix}/`) && (owner === me || flaws.listLeak)).map(([path]) => ({ name: path.slice(prefix.length + 1) }));
        return res(200, names);
      }
      if ((method === 'POST' || method === 'PUT') && p.startsWith('object/resumes/')) {
        const path = p.replace('object/resumes/', ''); const folder = path.split('/')[0];
        if (!me && !flaws.anonUpload) return res(401, {});
        if (me && folder !== me && !flaws.noRls) return res(403, {});
        if (method === 'PUT' && objects.get(path) !== me && !flaws.noRls) return res(403, {});
        if (h['Content-Type'] !== 'application/pdf' && !flaws.noMime) return res(415, {});
        if (init.body.length > 5 * 1024 * 1024 && !flaws.noSize) return res(413, {});
        objects.set(path, me ?? 'anon'); return res(200, {});
      }
      if (method === 'DELETE' && p === 'object/resumes') {
        if (!flaws.cleanupBroken) for (const x of JSON.parse(init.body).prefixes) if (objects.get(x) === me || flaws.deleteForeign) objects.delete(x);
        return res(200, []);
      }
    }
    return res(404, {});
  };
  handler.writes = writes;
  return handler;
}
const quiet = async (fn) => { const log = console.log; console.log = () => {}; try { return await fn(); } finally { console.log = log; } };
const failing = (r) => r.filter((x) => !x.ok).map((x) => x.name);
const starts = (names, s) => names.some((n) => n.startsWith(s));

test('against a correct backend every check passes, nothing is left behind, and no secret is printed', async () => {
  const logs = []; const log = console.log; console.log = (...a) => logs.push(a.join(' '));
  let r; try { r = await run({ ...ENV }, makeBackend()); } finally { console.log = log; }
  assert.deepEqual(failing(r), []);
  assert.equal(r.length, 11);
  assert.equal(logs.join('\n').includes('tok-'), false);
  assert.equal(logs.join('\n').includes('ref-'), false);
});

test('--quotas adds the small quota proofs; --quotas-bulk adds the large ones; both fail when the backend has no quota', async () => {
  const small = await quiet(() => run({ ...ENV }, makeBackend(), { quotas: true }));
  assert.equal(small.length, 12);
  assert.deepEqual(failing(small), []);
  const big = await quiet(() => run({ ...ENV }, makeBackend(), { quotas: true, bulk: true }));
  assert.equal(big.length, 13);
  assert.deepEqual(failing(big), []);
  const bad = await quiet(() => run({ ...ENV }, makeBackend({ noQuota: true }), { quotas: true, bulk: true }));
  assert.ok(starts(failing(bad), 'quota: 11th'));
  assert.ok(starts(failing(bad), 'quota (bulk)'));
  const noUpsert = await quiet(() => run({ ...ENV }, makeBackend({ noUpsertExemption: true }), { quotas: true, bulk: true }));
  assert.ok(starts(failing(noUpsert), 'quota (bulk)'), 'an upsert at the limit must be allowed');
});

const FLAWS = {
  noRls: ['RLS B -> A', 'RLS A -> B', 'Storage: valid PDF'],
  noParentCheck: ['RLS B -> A'],
  allowGiveAway: ['RLS B -> A'],
  anonReadsPrivate: ['anonymous key alone'],
  catalogWritable: ['catalogue'],
  syncReadable: ['anonymous key alone'],
  publicBucket: ['Storage: valid PDF', 'Storage: signed URL'],
  noMime: ['Storage: valid PDF'],
  noSize: ['Storage: valid PDF'],
  anonUpload: ['Storage: valid PDF'],
  listLeak: ['Storage: valid PDF'],
  deleteForeign: ['Storage: valid PDF'],
  neverExpires: ['Storage: signed URL'],
  logoutNoRevoke: ['Auth: session refresh'],
  cleanupBroken: ['cleanup of everything'],
};
for (const [flaw, prefixes] of Object.entries(FLAWS)) {
  test(`a backend with flaw "${flaw}" is caught`, async () => {
    const r = await quiet(() => run({ ...ENV }, makeBackend({ [flaw]: true })));
    for (const p of prefixes) assert.ok(starts(failing(r), p), `a check starting with "${p}" should fail; failing: ${failing(r)}`);
  });
}

test('the RLS check names the table and operation that failed', async () => {
  const lines = []; const log = console.log; console.log = (...a) => lines.push(a.join(' '));
  try { await run({ ...ENV }, makeBackend({ noParentCheck: true })); } finally { console.log = log; }
  const l = lines.find((x) => x.startsWith('FAIL  RLS B -> A'));
  assert.match(l, /INSERT experiences under the other user's parent/);
});

test('sign-up uses the normal endpoint and flags auto-confirmation (e-mail confirmation OFF)', async () => {
  const ok = await quiet(() => signup({ ...ENV }, makeBackend()));
  assert.deepEqual(ok.map((x) => x.autoConfirmed), [false, false]);
  const off = await quiet(() => signup({ ...ENV }, makeBackend({ autoConfirm: true })));
  assert.deepEqual(off.map((x) => x.autoConfirmed), [true, true]);
});

test('refuses without confirmation, wrong host, or a secret key', async () => {
  await assert.rejects(run({ ...ENV, ORBIJOB_E2E_CONFIRM: '' }, makeBackend()), /ORBIJOB_E2E_CONFIRM/);
  await assert.rejects(run({ ...ENV, SUPABASE_URL: 'https://other.supabase.co' }, makeBackend()), /expected project/);
  await assert.rejects(run({ ...ENV, SUPABASE_PUBLISHABLE_KEY: 'sb_secret_abc' }, makeBackend()), /secret/);
  await assert.rejects(signup({ ...ENV, SUPABASE_PUBLISHABLE_KEY: 'sb_secret_abc' }, makeBackend()), /secret/);
  const jwt = (p) => `x.${Buffer.from(JSON.stringify(p)).toString('base64url')}.y`;
  assert.equal(isSecretKey(jwt({ role: 'service_role' })), true);
  assert.equal(isSecretKey(jwt({ role: 'anon' })), false);
});

test('the accounts must look disposable and be two different accounts', async () => {
  await assert.rejects(run({ ...ENV, E2E_EMAIL_A: 'maria@gmail.com' }, makeBackend()), /do not look disposable/);
  await run({ ...ENV, E2E_EMAIL_A: 'maria@gmail.com', E2E_EMAIL_B: 'joao@gmail.com', ORBIJOB_E2E_ACCOUNTS_DISPOSABLE: 'yes' }, makeBackend()).then(() => assert.fail('the backend has no such users'), (e) => assert.match(e.message, /sign-in failed/));
  await assert.rejects(run({ ...ENV, E2E_EMAIL_B: ENV.E2E_EMAIL_A }, makeBackend()), /two different accounts/);
  await assert.rejects(signup({ ...ENV, E2E_EMAIL_A: 'maria@gmail.com' }, makeBackend()), /do not look disposable/);
});

test('an account that already has data is refused BEFORE anything is written, and its data is untouched', async () => {
  const be = makeBackend({}, { saved_searches: { user_id: 'user-a', query: { q: 'mine' } } });
  await assert.rejects(quiet(() => run({ ...ENV }, be)), /must be empty.*A:saved_searches\(1\)/);
  assert.deepEqual(be.writes, []);
  const pre = makeBackend({}, { user_preferences: { user_id: 'user-b', theme: 'dark' } });
  await assert.rejects(quiet(() => run({ ...ENV }, pre)), /B:user_preferences\(1\)/);
});

test('--only runs just the chosen sections (and quotas needs a volume flag)', async () => {
  const names = async (only, opts = {}) => (await quiet(() => run({ ...ENV }, makeBackend(), { only, ...opts }))).map((r) => r.name.split(':')[0].split(' ')[0]);
  const storage = await quiet(() => run({ ...ENV }, makeBackend(), { only: new Set(['storage']) }));
  assert.deepEqual(failing(storage), []);
  assert.ok(storage.some((r) => r.name.startsWith('Storage: valid PDF')));
  assert.ok(!storage.some((r) => r.name.startsWith('RLS')));
  assert.ok(!storage.some((r) => r.name.startsWith('catalogue')));
  const rls = await quiet(() => run({ ...ENV }, makeBackend(), { only: new Set(['rls']) }));
  assert.deepEqual(failing(rls), []);
  assert.ok(rls.some((r) => r.name.startsWith('RLS')) && !rls.some((r) => r.name.startsWith('Storage')));
  const anon = await quiet(() => run({ ...ENV }, makeBackend(), { only: new Set(['anon', 'catalogue']) }));
  assert.deepEqual(failing(anon), []);
  assert.ok(!anon.some((r) => r.name.startsWith('RLS')) && !anon.some((r) => r.name.startsWith('Storage')));
  await assert.rejects(run({ ...ENV }, makeBackend(), { only: new Set(['quotas']) }), /needs --quotas/);
  const q = await quiet(() => run({ ...ENV }, makeBackend(), { only: new Set(['quotas']), quotas: true }));
  assert.deepEqual(failing(q), []);
  assert.ok(q.some((r) => r.name.startsWith('quota:')));
  assert.equal(parseOnly(['--only=rls,storage']).size, 2);
  assert.equal(parseOnly([]), null);
  assert.throws(() => parseOnly(['--only=rls,nope']), /nope/);
  assert.throws(() => parseOnly(['--only=']), /accepts/);
  assert.deepEqual(SECTIONS.slice().sort(), ['anon', 'auth', 'catalogue', 'quotas', 'rls', 'storage']);
});
