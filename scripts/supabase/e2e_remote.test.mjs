// Tests the E2E script's logic against an in-memory model of Supabase (Auth + PostgREST + Storage with RLS-like rules).
// The model is MY reading of the API; it proves the script's flow and that each check can fail, NOT that the real
// platform behaves this way. Real validation requires running the script against the real project.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { run, isSecretKey } from './e2e_remote.mjs';

const REF = 'rpmlfxwebnlxnwadyvle';
const ENV = { ORBIJOB_E2E_CONFIRM: REF, SUPABASE_URL: `https://${REF}.supabase.co`, SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_x',
  E2E_EMAIL_A: 'a@test.invalid', E2E_EMAIL_B: 'b@test.invalid', E2E_PASSWORD: 'x', E2E_SIGNED_WAIT_MS: '60' };

function makeBackend(flaws = {}) {
  const users = { 'a@test.invalid': 'user-a', 'b@test.invalid': 'user-b' };
  const tables = { professional_profiles: [], saved_jobs: [], saved_searches: [], resumes: [] };
  const objects = new Map(); // path -> {owner, bytes}
  const signed = new Map(); // token -> {path, expires}
  let seq = 0;
  const res = (status, body) => new Response(body === undefined ? null : typeof body === 'string' ? body : JSON.stringify(body), { status });
  const uid = (h) => { const t = h.Authorization?.replace('Bearer ', ''); return t?.startsWith('tok-') ? t.slice(4) : null; };
  const match = (row, q) => [...new URLSearchParams(q).entries()].every(([k, v]) => {
    const want = v.replace(/^eq\./, '');
    const got = k.includes('->>') ? row[k.split('->>')[0]]?.[k.split('->>')[1]] : row[k];
    return String(got) === decodeURIComponent(want);
  });

  return async (url, init = {}) => {
    const u = new URL(url); const h = init.headers ?? {}; const me = uid(h); const method = init.method ?? 'GET';
    if (u.pathname === '/auth/v1/token') {
      const b = JSON.parse(init.body); const id = users[b.email];
      return id ? res(200, { access_token: `tok-${id}`, user: { id } }) : res(400, {});
    }
    if (u.pathname.startsWith('/rest/v1/')) {
      const t = u.pathname.split('/').pop(); const rows = tables[t];
      if (!me) return res(401, { code: '42501' });
      const visible = rows.filter((r) => flaws.noRls || r.user_id === me);
      const q = u.search.replace(/^\?/, '');
      if (method === 'GET') return res(200, visible.filter((r) => match(r, q)));
      if (method === 'POST') {
        const b = JSON.parse(init.body);
        if (b.user_id !== me && !flaws.noRls) return res(403, { code: '42501' });
        if (t === 'resumes' && !flaws.noQuota && rows.filter((r) => r.user_id === me).length >= 10) return res(400, { code: '53400', message: 'quota exceeded: at most 10 rows in resumes' });
        const row = { id: `r${++seq}`, ...b }; rows.push(row); return res(201, [row]);
      }
      const hit = visible.filter((r) => match(r, q));
      if (method === 'PATCH') { hit.forEach((r) => Object.assign(r, JSON.parse(init.body))); return res(200, hit); }
      if (method === 'DELETE') { hit.forEach((r) => rows.splice(rows.indexOf(r), 1)); return res(200, hit); }
    }
    if (u.pathname.startsWith('/storage/v1/')) {
      const p = u.pathname.replace('/storage/v1/', '');
      if (p.startsWith('object/sign/') && u.searchParams.get('token')) {
        const s = signed.get(u.searchParams.get('token'));
        return s && Date.now() < s.expires ? res(200, 'pdf') : res(400, {});
      }
      if (method === 'POST' && p.startsWith('object/sign/')) {
        const path = p.replace('object/sign/resumes/', ''); const o = objects.get(path);
        if (!me || !o || (o.owner !== me && !flaws.noRls)) return res(404, {});
        const token = `t${++seq}`; signed.set(token, { path, expires: Date.now() + (flaws.neverExpires ? 1e9 : 20) });
        return res(200, { signedURL: `/object/sign/resumes/${path}?token=${token}` });
      }
      if (p.startsWith('object/public/')) return flaws.publicBucket ? res(200, 'pdf') : res(400, {});
      if (p.startsWith('object/authenticated/resumes/')) {
        const o = objects.get(p.replace('object/authenticated/resumes/', ''));
        return me && o && (o.owner === me || flaws.noRls) ? res(200, 'pdf') : res(404, {});
      }
      if ((method === 'POST' || method === 'PUT') && p.startsWith('object/resumes/')) {
        const path = p.replace('object/resumes/', ''); const folder = path.split('/')[0];
        if (!me || (folder !== me && !flaws.noRls)) return res(403, {});
        if (method === 'PUT' && objects.get(path)?.owner !== me && !flaws.noRls) return res(403, {});
        if (h['Content-Type'] !== 'application/pdf' && !flaws.noMime) return res(415, {});
        if (init.body.length > 5 * 1024 * 1024 && !flaws.noSize) return res(413, {});
        objects.set(path, { owner: me, bytes: init.body.length }); return res(200, {});
      }
      if (method === 'DELETE' && p === 'object/resumes') {
        for (const x of JSON.parse(init.body).prefixes) if (objects.get(x)?.owner === me) objects.delete(x);
        return res(200, []);
      }
    }
    return res(404, {});
  };
}
const quiet = async (fn) => { const log = console.log; console.log = () => {}; try { return await fn(); } finally { console.log = log; } };
const failing = (r) => r.filter((x) => !x.ok).map((x) => x.name);

test('against a correct backend every check passes and nothing is left behind', async () => {
  const be = makeBackend();
  const r = await quiet(() => run({ ...ENV }, be));
  assert.deepEqual(failing(r), []);
  assert.equal(r.length, 11);
});

test('--quotas adds the 11th-resume check and it fails when the backend has no quota', async () => {
  const ok = await quiet(() => run({ ...ENV }, makeBackend(), { quotas: true }));
  assert.equal(ok.length, 12);
  assert.deepEqual(failing(ok), []);
  const bad = await quiet(() => run({ ...ENV }, makeBackend({ noQuota: true }), { quotas: true }));
  assert.deepEqual(failing(bad), ['11th resume row is refused (quota)']);
});

const FLAWS = {
  noRls: ['A writes profile, favourite and saved search; B sees none of them', 'B cannot update or delete A rows, nor insert rows owned by A'],
  publicBucket: ['B cannot read, list-by-path, overwrite or upload into A folder; bucket is not public'],
  noMime: ['non-PDF content is rejected by the bucket'],
  noSize: ['file over 5 MiB is rejected'],
  neverExpires: ['signed URL works and then expires'],
};
for (const [flaw, names] of Object.entries(FLAWS)) {
  test(`a backend with flaw "${flaw}" is caught`, async () => {
    const r = await quiet(() => run({ ...ENV }, makeBackend({ [flaw]: true })));
    for (const n of names) assert.ok(failing(r).includes(n), `${n} should fail; failing: ${failing(r)}`);
  });
}

test('refuses without confirmation, wrong host, or a secret key', async () => {
  await assert.rejects(run({ ...ENV, ORBIJOB_E2E_CONFIRM: '' }, makeBackend()), /ORBIJOB_E2E_CONFIRM/);
  await assert.rejects(run({ ...ENV, SUPABASE_URL: 'https://other.supabase.co' }, makeBackend()), /expected project/);
  await assert.rejects(run({ ...ENV, SUPABASE_PUBLISHABLE_KEY: 'sb_secret_abc' }, makeBackend()), /secret/);
  const jwt = (p) => `x.${Buffer.from(JSON.stringify(p)).toString('base64url')}.y`;
  assert.equal(isSecretKey(jwt({ role: 'service_role' })), true);
  assert.equal(isSecretKey(jwt({ role: 'anon' })), false);
});
