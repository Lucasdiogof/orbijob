// End-to-end check of account export and deletion against the REAL project, using ONLY throw-away accounts it creates itself
// (e-mail `e2e-<random>@orbijob-test.invalid`). It never touches a real user: every account it deletes was created by this run.
//
//   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SECRET_KEY=... node worker/scripts/account-e2e.mjs
//
// The secret key is read from the environment, used only to create/clean up the test accounts and to confirm that nothing is left, and is never
// printed. Exit code 1 on any failed expectation.
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const URL_ = process.env.SUPABASE_URL;
const PUB = process.env.SUPABASE_PUBLISHABLE_KEY;
const SECRET = process.env.SUPABASE_SECRET_KEY;
if (!URL_ || !PUB || !SECRET) { console.error('missing SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY / SUPABASE_SECRET_KEY'); process.exit(2); }
if (!/^https:\/\/[a-z0-9]{20}\.supabase\.co$/.test(URL_)) { console.error('unexpected project url'); process.exit(2); }

let failed = 0;
const check = (name, ok, extra = '') => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : `  ${extra}`}`); if (!ok) failed++; };

const j = async (method, path, { key = PUB, token, body, headers = {} } = {}) => {
  const r = await fetch(`${URL_}${path}`, {
    method,
    headers: { apikey: key, authorization: `Bearer ${token ?? key}`, 'content-type': 'application/json', ...headers },
    body: body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
  });
  const text = await r.text();
  let json = null; try { json = JSON.parse(text); } catch { /* not JSON */ }
  return { status: r.status, json, text };
};

async function makeUser() {
  const email = `e2e-${randomUUID().slice(0, 8)}@orbijob-test.invalid`;
  const password = `Pw-${randomUUID()}`;
  const c = await j('POST', '/auth/v1/admin/users', { key: SECRET, body: { email, password, email_confirm: true } });
  if (c.status >= 300) throw new Error(`create user: ${c.status} ${c.text.slice(0, 120)}`);
  const s = await j('POST', '/auth/v1/token?grant_type=password', { body: { email, password } });
  if (s.status !== 200) throw new Error(`sign in: ${s.status}`);
  return { id: c.json.id, email, password, token: s.json.access_token };
}

async function seed(u) {
  const rest = (m, t, body, extra = {}) => j(m, `/rest/v1/${t}`, { token: u.token, body, headers: { prefer: 'return=representation', ...extra } });
  const p = await rest('POST', 'professional_profiles', { user_id: u.id, name: 'E2E Test Profile' });
  const pid = p.json?.[0]?.id;
  if (!pid) throw new Error(`profile: ${p.status} ${p.text.slice(0, 160)}`);
  const pdf = Buffer.from('%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n');
  const path = `${u.id}/${randomUUID()}.pdf`;
  const up = await fetch(`${URL_}/storage/v1/object/resumes/${path}`, { method: 'POST', headers: { apikey: PUB, authorization: `Bearer ${u.token}`, 'content-type': 'application/pdf' }, body: pdf });
  if (up.status >= 300) throw new Error(`upload: ${up.status} ${(await up.text()).slice(0, 120)}`);
  await rest('POST', 'resumes', { user_id: u.id, profile_id: pid, storage_path: path });
  await rest('POST', 'saved_searches', { user_id: u.id, name: 'e2e search', query: { q: 'e2e' } });
  await rest('POST', 'user_preferences', { user_id: u.id, locale: 'pt-BR' });
  const a = await rest('POST', 'applications', { user_id: u.id, stage: 'interested', note: 'e2e note', job_snapshot: { title: 'x' } });
  return { pid, path, appId: a.json?.[0]?.id };
}

// The service role has no SELECT on the private tables (least privilege, migration 20261014), so the counts go through the linked CLI.
const countAdmin = async (table, uid) => {
  if (!/^[a-z_]+$/.test(table) || !/^[0-9a-f-]{36}$/.test(uid)) throw new Error('bad count arguments');
  const file = join(tmpdir(), `orbijob-e2e-${process.pid}.sql`);
  writeFileSync(file, `select count(*)::int n from public.${table} where user_id='${uid}'`);
  const out = execFileSync(process.platform === 'win32' ? 'npx.cmd' : 'npx', ['supabase', 'db', 'query', '--linked', '-f', file], { encoding: 'utf8', shell: process.platform === 'win32' });
  rmSync(file, { force: true });
  const m = /"n":\s*(\d+)/.exec(out);
  return m ? Number(m[1]) : -1;
};
const listFolder = async (uid) => {
  const r = await j('POST', '/storage/v1/object/list/resumes', { key: SECRET, body: { prefix: `${uid}/`, limit: 100 } });
  return Array.isArray(r.json) ? r.json.filter((o) => o.name && o.name !== '.emptyFolderPlaceholder').length : -1;
};
const userExists = async (uid) => (await j('GET', `/auth/v1/admin/users/${uid}`, { key: SECRET })).status === 200;

const created = [];
try {
  const a = await makeUser(); created.push(a);
  const b = await makeUser(); created.push(b);
  const sa = await seed(a);
  const sb = await seed(b);

  // ── export ──
  const noTok = await j('POST', '/functions/v1/account-export', { key: PUB });
  check('export refuses a call with only the publishable key', noTok.status === 401, String(noTok.status));
  const ex = await j('POST', '/functions/v1/account-export', { token: a.token });
  check('export answers 200 to the signed-in person', ex.status === 200, `${ex.status} ${ex.text.slice(0, 120)}`);
  const body = ex.json ?? {};
  check('export carries A\'s profile', body.data?.professional_profiles?.length === 1 && body.data.professional_profiles[0].id === sa.pid);
  check('export carries A\'s application and note', body.data?.applications?.[0]?.note === 'e2e note');
  check('export has no row of B', !JSON.stringify(body).includes(sb.pid) && !JSON.stringify(body).includes(b.id));
  check('export gives a resume link that downloads a PDF', await (async () => {
    const url = body.resume_files?.[0]?.download_url;
    if (!url) return false;
    const r = await fetch(url.startsWith('http') ? url : `${URL_}/storage/v1${url}`);
    return r.status === 200 && (await r.text()).startsWith('%PDF');
  })());
  check('export never includes a push token or password', !/"token"|password/.test(JSON.stringify(body.data)));

  // ── isolation between accounts (IDOR) ──
  const asA = (path, init = {}) => fetch(`${URL_}${path}`, { ...init, headers: { apikey: PUB, authorization: `Bearer ${a.token}`, ...(init.headers ?? {}) } });
  const peek = await j('GET', `/rest/v1/professional_profiles?select=id&user_id=eq.${b.id}`, { token: a.token });
  check('A cannot read B’s profile rows', Array.isArray(peek.json) && peek.json.length === 0, peek.text.slice(0, 80));
  const peekApp = await j('GET', `/rest/v1/applications?select=id&id=eq.${sb.appId}`, { token: a.token });
  check('A cannot read B’s application by id', Array.isArray(peekApp.json) && peekApp.json.length === 0);
  const dl = await asA(`/storage/v1/object/authenticated/resumes/${sb.path}`);
  check('A cannot download B’s resume file', dl.status >= 400, String(dl.status));
  const sign = await j('POST', `/storage/v1/object/sign/resumes/${sb.path}`, { token: a.token, body: { expiresIn: 60 } });
  check('A cannot get a signed link for B’s resume', sign.status >= 400 || !sign.json?.signedURL, String(sign.status));
  const ls = await j('POST', '/storage/v1/object/list/resumes', { token: a.token, body: { prefix: `${b.id}/`, limit: 10 } });
  check('A cannot list B’s folder', Array.isArray(ls.json) && ls.json.length === 0);
  const up = await fetch(`${URL_}/storage/v1/object/resumes/${b.id}/${randomUUID()}.pdf`, { method: 'POST', headers: { apikey: PUB, authorization: `Bearer ${a.token}`, 'content-type': 'application/pdf' }, body: Buffer.from('%PDF-1.4 x') });
  check('A cannot upload into B’s folder', up.status >= 400, String(up.status));
  const forged = await j('POST', '/rest/v1/resumes', { token: a.token, body: { user_id: a.id, profile_id: sa.pid, storage_path: sb.path }, headers: { prefer: 'return=minimal' } });
  check('A cannot register B’s file path as its own resume', forged.status >= 400, String(forged.status));
  const writeB = await j('PATCH', `/rest/v1/professional_profiles?id=eq.${sb.pid}`, { token: a.token, body: { name: 'hijacked' }, headers: { prefer: 'return=representation' } });
  check('A cannot modify B’s profile', Array.isArray(writeB.json) && writeB.json.length === 0);
  const asOwner = await j('GET', `/rest/v1/professional_profiles?select=name&id=eq.${sb.pid}`, { token: b.token });
  check('B’s profile is untouched', asOwner.json?.[0]?.name === 'E2E Test Profile');
  const anon = await j('GET', '/rest/v1/professional_profiles?select=id', { key: PUB });
  check('anonymous visitors see no profile rows', (Array.isArray(anon.json) && anon.json.length === 0) || anon.status >= 400);
  const anonUsers = await j('GET', '/auth/v1/admin/users', { key: PUB });
  check('the admin user list is closed to the publishable key', anonUsers.status >= 400, String(anonUsers.status));
  const push = await j('POST', '/functions/v1/push-send', { token: a.token, body: {} });
  check('push-send refuses a signed-in user without the shared secret', push.status === 401, String(push.status));

  // ── deletion refusals (nothing may be deleted) ──
  const bad1 = await j('POST', '/functions/v1/account-delete', { token: a.token, body: { password: 'wrong-password', confirm: true } });
  check('delete refuses a wrong password', bad1.status === 401, String(bad1.status));
  const bad2 = await j('POST', '/functions/v1/account-delete', { token: a.token, body: { password: a.password } });
  check('delete refuses without explicit confirmation', bad2.status === 400, String(bad2.status));
  const bad3 = await j('POST', '/functions/v1/account-delete', { token: a.token, body: { password: b.password, confirm: true } });
  check('delete refuses B\'s password presented with A\'s token', bad3.status === 401, String(bad3.status));
  const bad4 = await j('POST', '/functions/v1/account-delete', { token: a.token, body: { password: a.password, confirm: true, user_id: b.id } });
  check('an id in the body cannot redirect the deletion to B (A is deleted, B stays)', bad4.status === 200, `${bad4.status} ${bad4.text.slice(0, 120)}`);

  // ── after A's deletion ──
  check('A\'s Auth user is gone', !(await userExists(a.id)));
  for (const t of ['professional_profiles', 'resumes', 'saved_searches', 'user_preferences', 'applications']) {
    check(`A's ${t} rows are gone`, (await countAdmin(t, a.id)) === 0);
  }
  check('A\'s resume file is gone', (await listFolder(a.id)) === 0);
  check('A\'s old token no longer works', (await j('POST', '/functions/v1/account-export', { token: a.token })).status === 401);
  check('B still exists with its data and file', (await userExists(b.id)) && (await countAdmin('professional_profiles', b.id)) === 1 && (await listFolder(b.id)) === 1);
  const again = await j('POST', '/functions/v1/account-delete', { token: a.token, body: { password: a.password, confirm: true } });
  check('repeating A\'s deletion is refused cleanly (no 5xx)', again.status === 401, String(again.status));

  // ── B deletes itself normally ──
  const del = await j('POST', '/functions/v1/account-delete', { token: b.token, body: { password: b.password, confirm: true } });
  check('B deletes itself', del.status === 200 && del.json?.resumes_removed === 1, `${del.status} ${del.text.slice(0, 120)}`);
  check('B is gone with its file', !(await userExists(b.id)) && (await listFolder(b.id)) === 0 && (await countAdmin('applications', b.id)) === 0);
} catch (e) {
  console.error('ERROR', e instanceof Error ? e.message : e);
  failed++;
} finally {
  // clean-up: only accounts created by THIS run (e-mail pattern checked again before deleting)
  for (const u of created) {
    if (!/^e2e-[0-9a-f]{8}@orbijob-test\.invalid$/.test(u.email)) continue;
    if (await userExists(u.id)) {
      const files = await j('POST', '/storage/v1/object/list/resumes', { key: SECRET, body: { prefix: `${u.id}/`, limit: 100 } });
      const names = (Array.isArray(files.json) ? files.json : []).map((o) => `${u.id}/${o.name}`);
      if (names.length) await j('DELETE', '/storage/v1/object/resumes', { key: SECRET, body: { prefixes: names } });
      await j('DELETE', `/auth/v1/admin/users/${u.id}`, { key: SECRET });
      console.log(`cleanup: removed leftover test account ${u.email}`);
    }
  }
}
console.log(failed ? `\n${failed} check(s) FAILED` : '\nall checks passed');
process.exit(failed ? 1 : 0);
