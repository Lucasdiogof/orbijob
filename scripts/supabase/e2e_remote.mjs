#!/usr/bin/env node
// OrbiJob end-to-end check against a REAL Supabase project, using the PUBLISHABLE key and two throw-away accounts.
// It talks to Auth, PostgREST and Storage exactly as the app does, and never uses a secret/service_role key.
//   ORBIJOB_E2E_CONFIRM=rpmlfxwebnlxnwadyvle SUPABASE_URL=https://rpmlfxwebnlxnwadyvle.supabase.co \
//   SUPABASE_PUBLISHABLE_KEY=sb_publishable_... E2E_EMAIL_A=... E2E_EMAIL_B=... E2E_PASSWORD=... \
//   node scripts/supabase/e2e_remote.mjs [--signup] [--quotas] [--quotas-bulk] [--dry-run]
//
//   --signup       only asks Auth to create A and B through the normal sign-up endpoint (a confirmation e-mail is sent
//                  to each address; a human must click it). Nothing else runs. Reports whether Auth auto-confirmed
//                  (which would mean e-mail confirmation is OFF).
//   (default)      sign in, RLS between A and B on every private table, catalogue and sync_runs, Storage, session
//                  refresh and logout, cleanup. The accounts must already exist and be confirmed.
//   --quotas       adds the small quota proofs (10 resumes, 100 saved searches), one bulk request each.
//   --quotas-bulk  adds the large ones (1,000 saved jobs, 2,000 applications): about 3,000 small rows, then removed.
//   --dry-run      prints the plan and touches nothing.
// WRITES test rows/objects under those two accounts only (tagged e2e-<time>) and removes them at the end. Auth accounts
// cannot be deleted with a publishable key: remove them in Dashboard -> Authentication -> Users.
// Tokens, passwords and keys are never printed.
const PROJECT_REF = 'rpmlfxwebnlxnwadyvle';
const args = new Set(process.argv.slice(2));
const dry = args.has('--dry-run');
const quotas = args.has('--quotas') || args.has('--quotas-bulk');
const bulk = args.has('--quotas-bulk');

export const PRIVATE_TABLES = ['professional_profiles', 'experiences', 'education', 'credentials', 'resumes', 'saved_jobs',
  'saved_searches', 'applications', 'application_events', 'reminders', 'user_preferences', 'viewed_jobs'];
export const CATALOGUE = ['jobs', 'job_sources', 'job_clusters'];

export const STEPS = [
  'Auth: wrong password refused; garbage bearer token refused; sign in as A and B',
  'Auth: session refresh works; after logout the refresh token is revoked',
  'anonymous key alone cannot read or write any private table; sync_runs unreadable',
  'catalogue (jobs, job_sources, job_clusters) is readable by anon and read-only for everyone',
  'A and B each seed a row in every private table that can be seeded without catalogue data',
  'RLS A->B and B->A on each table: SELECT, UPDATE, DELETE, forged INSERT, foreign parent, re-parent, give-away; owner data intact',
  'Storage: valid PDF in own folder; non-PDF and >5 MiB refused; foreign folder, list, overwrite, delete and anon blocked',
  'Storage: signed URL works and then expires; bucket is not public',
  'A data persists after signing in again',
  ...(quotas ? ['quota: 11th resume refused; 101st saved search refused (one bulk request each)'] : []),
  ...(bulk ? ['quota (bulk): 1,001st saved job and 2,001st application refused; upsert of an existing favourite still allowed'] : []),
  'cleanup of everything created and no leftovers (rows or objects)',
];

function fail(msg) { console.error(`E2E ABORTED: ${msg}`); process.exit(1); }

export function isSecretKey(key) {
  if (key.startsWith('sb_secret_')) return true;
  const p = key.split('.');
  if (p.length !== 3) return false;
  try { return JSON.parse(Buffer.from(p[1], 'base64url').toString()).role === 'service_role'; } catch { return false; }
}

function guard(env) {
  const base = env.SUPABASE_URL?.replace(/\/$/, '');
  const key = env.SUPABASE_PUBLISHABLE_KEY;
  if (env.ORBIJOB_E2E_CONFIRM !== PROJECT_REF) throw new Error(`set ORBIJOB_E2E_CONFIRM=${PROJECT_REF} to confirm the target project`);
  if (!base || !key || !env.E2E_EMAIL_A || !env.E2E_EMAIL_B || !env.E2E_PASSWORD) throw new Error('missing SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, E2E_EMAIL_A, E2E_EMAIL_B or E2E_PASSWORD');
  if (new URL(base).hostname !== `${PROJECT_REF}.supabase.co` && !/^(localhost|127\.0\.0\.1)$/.test(new URL(base).hostname)) throw new Error('SUPABASE_URL does not belong to the expected project');
  if (isSecretKey(key)) throw new Error('refusing to run with a secret/service_role key: use the publishable key');
  return { base, key };
}

// Normal sign-up flow only (no admin API). Returns what Auth said about confirmation, never a token.
export async function signup(env, fetchImpl = fetch) {
  const { base, key } = guard(env);
  const out = [];
  for (const email of [env.E2E_EMAIL_A, env.E2E_EMAIL_B]) {
    const r = await fetchImpl(`${base}/auth/v1/signup`, { method: 'POST', headers: { apikey: key, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password: env.E2E_PASSWORD }) });
    const j = await r.json().catch(() => ({}));
    const autoConfirmed = !!j.access_token || !!j.session;
    out.push({ status: r.status, ok: r.ok, autoConfirmed });
    console.log(`${r.ok ? 'PASS' : 'FAIL'}  sign-up requested for a test account (HTTP ${r.status})${autoConfirmed ? '  WARNING: Auth returned a session, so e-mail confirmation is OFF' : '  -> confirmation e-mail sent; click the link before running the checks'}`);
  }
  return out;
}

export async function run(env, fetchImpl = fetch, { quotas: withQuotas = quotas, bulk: withBulk = bulk } = {}) {
  const { base, key } = guard(env);

  const results = [];
  const check = (name, ok, detail = '') => { results.push({ name, ok, detail }); console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : `  -> ${detail}`}`); };
  const denied = (r) => r.status >= 400;
  const rows = async (r) => { const j = await r.clone().json().catch(() => null); return Array.isArray(j) ? j : null; };
  const emptyOrDenied = async (r) => denied(r) || (await rows(r))?.length === 0;

  const rest = (token, table, { method = 'GET', query = '', body, prefer = 'return=representation', headers = {} } = {}) => fetchImpl(`${base}/rest/v1/${table}${query}`, {
    method, headers: { apikey: key, ...(token ? { Authorization: `Bearer ${token}` } : {}), 'Content-Type': 'application/json', Prefer: prefer, ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const authReq = (path, body, token) => fetchImpl(`${base}/auth/v1/${path}`, { method: 'POST', headers: { apikey: key, 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
  const signIn = async (email, label) => {
    const r = await authReq('token?grant_type=password', { email, password: env.E2E_PASSWORD });
    if (!r.ok) throw new Error(`sign-in failed for test account ${label} (HTTP ${r.status}); the accounts must exist and be confirmed`);
    const j = await r.json();
    return { token: j.access_token, refresh: j.refresh_token, id: j.user.id, label };
  };
  const obj = (token, method, path, { body, type, extra = {} } = {}) => fetchImpl(`${base}/storage/v1/${path}`, {
    method, headers: { apikey: key, ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(type ? { 'Content-Type': type } : {}), ...extra }, body,
  });
  const list = (tok, prefix) => obj(tok, 'POST', 'object/list/resumes', { body: JSON.stringify({ prefix, limit: 100 }), type: 'application/json' });
  const pdf = (bytes = 64) => { const b = Buffer.alloc(bytes, 0x20); b.write('%PDF-1.7\n'); return b; };
  const count = async (token, table, query = '') => {
    const r = await rest(token, table, { query: `${query}${query ? '&' : '?'}select=id`, headers: { Prefer: 'count=exact', Range: '0-0' } });
    const m = /\/(\d+)$/.exec(r.headers.get('content-range') ?? '');
    return m ? Number(m[1]) : (await rows(r))?.length ?? -1;
  };

  // ───────── 1. Auth
  const wrong = await authReq('token?grant_type=password', { email: env.E2E_EMAIL_A, password: `${env.E2E_PASSWORD}-wrong` });
  const garbage = await rest('not.a.valid.token', 'professional_profiles');
  const A = await signIn(env.E2E_EMAIL_A, 'A');
  const B = await signIn(env.E2E_EMAIL_B, 'B');
  check('Auth: wrong password refused; garbage bearer token refused; sign in as A and B',
    denied(wrong) && denied(garbage) && A.id !== B.id && !!A.token && !!B.token, `wrong-password ${wrong.status} garbage-token ${garbage.status}`);

  const refreshed = await authReq('token?grant_type=refresh_token', { refresh_token: A.refresh });
  const rj = refreshed.ok ? await refreshed.json() : null;
  const withNew = rj ? await rest(rj.access_token, 'professional_profiles', { query: '?select=id&limit=1' }) : null;
  const S = await signIn(env.E2E_EMAIL_A, 'A-throwaway-session');
  const out = await authReq('logout?scope=local', undefined, S.token);
  const afterLogout = await authReq('token?grant_type=refresh_token', { refresh_token: S.refresh });
  check('Auth: session refresh works; after logout the refresh token is revoked',
    !!rj?.access_token && !!withNew?.ok && out.status < 300 && denied(afterLogout),
    `refresh ${refreshed.status} refreshed-token-read ${withNew?.status} logout ${out.status} refresh-after-logout ${afterLogout.status}`);

  // ───────── 2. anonymous
  const anonProblems = [];
  for (const t of PRIVATE_TABLES) {
    const g = await rest(null, t, { query: '?select=*&limit=1' });
    const p = await rest(null, t, { method: 'POST', body: { user_id: A.id } });
    if (!(await emptyOrDenied(g))) anonProblems.push(`GET ${t}`);
    if (!denied(p)) anonProblems.push(`POST ${t}`);
  }
  const anonSync = await rest(null, 'sync_runs', { query: '?select=*&limit=1' });
  const authSync = await rest(A.token, 'sync_runs', { query: '?select=*&limit=1' });
  if (!denied(anonSync)) anonProblems.push(`GET sync_runs (anon ${anonSync.status})`);
  if (!denied(authSync)) anonProblems.push(`GET sync_runs (authenticated ${authSync.status})`);
  check('anonymous key alone cannot read or write any private table; sync_runs unreadable', anonProblems.length === 0, anonProblems.join(', '));

  // ───────── 3. catalogue is public and read-only
  const catProblems = [];
  for (const t of CATALOGUE) {
    const g = await rest(null, t, { query: '?select=*&limit=1' });
    if (!g.ok) catProblems.push(`anon cannot read ${t} (${g.status})`);
    for (const [who, tok] of [['anon', null], ['authenticated', A.token]]) {
      const w = await rest(tok, t, { method: 'POST', body: t === 'job_sources' ? { id: 'e2e', status: 'READY' } : {} });
      const u = await rest(tok, t, { method: 'PATCH', query: '?id=not.is.null', body: t === 'job_sources' ? { status: 'BLOCKED' } : { created_at: '2000-01-01' } });
      const d = await rest(tok, t, { method: 'DELETE', query: '?id=not.is.null' });
      if (!denied(w)) catProblems.push(`${who} INSERT ${t} (${w.status})`);
      if (!(await emptyOrDenied(u))) catProblems.push(`${who} UPDATE ${t} (${u.status})`);
      if (!(await emptyOrDenied(d))) catProblems.push(`${who} DELETE ${t} (${d.status})`);
    }
  }
  check('catalogue (jobs, job_sources, job_clusters) is readable by anon and read-only for everyone', catProblems.length === 0, catProblems.join(', '));

  const tag = `e2e-${Date.now()}`;
  const created = { objects: [], profiles: [], applications: [], prefs: [], favouritePrefix: `e2e:${tag}` };
  const seeds = {};
  const ids = (j) => (Array.isArray(j) ? j[0]?.id : undefined);
  const post = async (user, table, body) => { const r = await rest(user.token, table, { method: 'POST', body }); return { ok: r.ok, status: r.status, row: r.ok ? (await r.json())[0] : null }; };

  try {
    // ───────── 4. seed one row per table, for each user
    for (const U of [A, B]) {
      const s = { user: U };
      const prof = await post(U, 'professional_profiles', { user_id: U.id, name: `${tag}-${U.label}`, skills: ['e2e'] });
      if (!prof.ok) throw new Error(`could not seed the profile for ${U.label} (HTTP ${prof.status}); is the account clean and confirmed?`);
      s.profile = prof.row.id; created.profiles.push(s.profile);
      const app = await post(U, 'applications', { user_id: U.id, profile_id: s.profile, note: tag, job_snapshot: { title: tag, company: 'C', url: 'https://example.invalid' } });
      s.application = app.row?.id; if (s.application) created.applications.push(s.application);
      const ev = s.application ? await (await rest(U.token, 'application_events', { query: `?application_id=eq.${s.application}&select=id` })).json() : [];
      const seeded = {
        experiences: await post(U, 'experiences', { user_id: U.id, profile_id: s.profile, company: 'C', title: tag }),
        education: await post(U, 'education', { user_id: U.id, profile_id: s.profile, institution: tag }),
        credentials: await post(U, 'credentials', { user_id: U.id, profile_id: s.profile, kind: 'certification', name: tag }),
        resumes: await post(U, 'resumes', { user_id: U.id, profile_id: s.profile, storage_path: `${U.id}/${tag}-seed.pdf` }),
        saved_jobs: await post(U, 'saved_jobs', { user_id: U.id, job_key: `${created.favouritePrefix}:${U.label}`, snapshot: { source: 'e2e', externalId: tag, title: 'T', company: 'C', originalUrl: 'https://example.invalid' } }),
        saved_searches: await post(U, 'saved_searches', { user_id: U.id, query: { q: tag, who: U.label } }),
        reminders: await post(U, 'reminders', { user_id: U.id, application_id: s.application, due_at: '2099-01-01T00:00:00Z', text: tag }),
        user_preferences: await post(U, 'user_preferences', { user_id: U.id, theme: 'dark' }),
      };
      if (seeded.user_preferences.ok) created.prefs.push(U.id);
      s.rows = { professional_profiles: s.profile, applications: s.application, application_events: ev[0]?.id };
      for (const [t, r] of Object.entries(seeded)) s.rows[t] = t === 'user_preferences' ? U.id : r.row?.id;
      s.seedFailures = Object.entries(seeded).filter(([, r]) => !r.ok).map(([t, r]) => `${t} ${r.status}`);
      if (!s.rows.application_events) s.seedFailures.push('application_events (no event from the trigger)');
      seeds[U.label] = s;
    }
    const seedFail = [...seeds.A.seedFailures, ...seeds.B.seedFailures];
    check('A and B each seed a row in every private table that can be seeded without catalogue data', seedFail.length === 0, seedFail.join(', '));

    // ───────── 5. RLS both ways
    const ID = (t) => (t === 'user_preferences' ? 'user_id' : 'id');
    const PATCH = { professional_profiles: { name: 'pwn' }, experiences: { title: 'pwn' }, education: { institution: 'pwn' }, credentials: { name: 'pwn' },
      resumes: { storage_path: 'pwn' }, saved_jobs: { note: 'pwn' }, saved_searches: { query: { q: 'pwn' } }, applications: { note: 'pwn' },
      application_events: { note: 'pwn' }, reminders: { text: 'pwn' }, user_preferences: { theme: 'light' } };
    const seededTables = Object.keys(PATCH);
    for (const [O, X] of [[seeds.A, seeds.B], [seeds.B, seeds.A]]) {
      const bad = [];
      const note = (cond, what) => { if (!cond) bad.push(what); };
      const readOwn = async (t) => (await (await rest(O.user.token, t, { query: `?${ID(t)}=eq.${O.rows[t]}&select=*` })).json())[0];
      for (const t of seededTables) {
        if (!O.rows[t]) { bad.push(`${t}: no seed`); continue; }
        const sel = await rest(X.user.token, t, { query: `?${ID(t)}=eq.${O.rows[t]}&select=*` });
        note(await emptyOrDenied(sel), `SELECT ${t}`);
        const upd = await rest(X.user.token, t, { method: 'PATCH', query: `?${ID(t)}=eq.${O.rows[t]}`, body: PATCH[t] });
        note(await emptyOrDenied(upd), `UPDATE ${t}`);
        const del = await rest(X.user.token, t, { method: 'DELETE', query: `?${ID(t)}=eq.${O.rows[t]}` });
        note(await emptyOrDenied(del), `DELETE ${t}`);
        const mine = await readOwn(t);
        note(!!mine, `owner lost ${t}`);
        for (const [k, v] of Object.entries(PATCH[t])) note(mine && JSON.stringify(mine[k]) !== JSON.stringify(v), `owner's ${t}.${k} was changed`);
      }
      // forged INSERTs: user_id of the owner
      const forged = {
        professional_profiles: { user_id: O.user.id, name: 'forged' },
        experiences: { user_id: O.user.id, profile_id: O.profile, company: 'c', title: 't' },
        education: { user_id: O.user.id, profile_id: O.profile, institution: 'i' },
        credentials: { user_id: O.user.id, profile_id: O.profile, kind: 'license', name: 'n' },
        resumes: { user_id: O.user.id, profile_id: O.profile, storage_path: `${O.user.id}/forged.pdf` },
        saved_jobs: { user_id: O.user.id, job_key: 'forged', snapshot: { a: 1 } },
        saved_searches: { user_id: O.user.id, query: { forged: true } },
        applications: { user_id: O.user.id, job_snapshot: { t: 1 } },
        application_events: { user_id: O.user.id, application_id: O.application, stage: 'applied' },
        reminders: { user_id: O.user.id, application_id: O.application, due_at: '2099-01-01T00:00:00Z', text: 'forged' },
        user_preferences: { user_id: O.user.id, theme: 'dark' },
        viewed_jobs: { user_id: O.user.id, job_id: '00000000-0000-0000-0000-000000000000' },
      };
      for (const [t, body] of Object.entries(forged)) note(denied(await rest(X.user.token, t, { method: 'POST', body })), `forged INSERT ${t}`);
      // own user_id but the OTHER user's parent
      const foreignParent = {
        experiences: { user_id: X.user.id, profile_id: O.profile, company: 'c', title: 't' },
        education: { user_id: X.user.id, profile_id: O.profile, institution: 'i' },
        credentials: { user_id: X.user.id, profile_id: O.profile, kind: 'license', name: 'n' },
        resumes: { user_id: X.user.id, profile_id: O.profile, storage_path: `${X.user.id}/x.pdf` },
        applications: { user_id: X.user.id, profile_id: O.profile, job_snapshot: { t: 1 } },
        application_events: { user_id: X.user.id, application_id: O.application, stage: 'applied' },
        reminders: { user_id: X.user.id, application_id: O.application, due_at: '2099-01-01T00:00:00Z', text: 'x' },
      };
      for (const [t, body] of Object.entries(foreignParent)) note(denied(await rest(X.user.token, t, { method: 'POST', body })), `INSERT ${t} under the other user's parent`);
      // re-parenting an own row to the other user's parent, and giving an own row away
      const reparent = { experiences: { profile_id: O.profile }, resumes: { profile_id: O.profile }, applications: { profile_id: O.profile }, reminders: { application_id: O.application } };
      for (const [t, body] of Object.entries(reparent)) {
        const r = await rest(X.user.token, t, { method: 'PATCH', query: `?${ID(t)}=eq.${X.rows[t]}`, body });
        const mineNow = (await (await rest(X.user.token, t, { query: `?${ID(t)}=eq.${X.rows[t]}&select=*` })).json())[0];
        const k = Object.keys(body)[0];
        note((denied(r) || (await rows(r))?.length === 0) && mineNow && mineNow[k] !== body[k], `re-parent ${t}`);
      }
      for (const t of ['saved_searches', 'saved_jobs', 'applications', 'professional_profiles']) {
        const r = await rest(X.user.token, t, { method: 'PATCH', query: `?id=eq.${X.rows[t]}`, body: { user_id: O.user.id } });
        const mineNow = (await (await rest(X.user.token, t, { query: `?id=eq.${X.rows[t]}&select=user_id` })).json())[0];
        note(denied(r) && mineNow?.user_id === X.user.id, `give away ${t}`);
      }
      check(`RLS ${X.user.label} -> ${O.user.label}: SELECT, UPDATE, DELETE, forged INSERT, foreign parent, re-parent and give-away all blocked on ${seededTables.length + 1} tables; owner data intact`,
        bad.length === 0, bad.join('; '));
    }

    // ───────── 6. Storage
    const { A: SA, B: SB } = seeds;
    const okPath = `${A.id}/${tag}.pdf`;
    const up = await obj(A.token, 'POST', `object/resumes/${okPath}`, { body: pdf(), type: 'application/pdf' });
    if (up.ok) created.objects.push(okPath);
    const txt = await obj(A.token, 'POST', `object/resumes/${A.id}/${tag}-text.pdf`, { body: Buffer.from('plain text, not a PDF'), type: 'text/plain' });
    if (txt.ok) created.objects.push(`${A.id}/${tag}-text.pdf`);
    const big = await obj(A.token, 'POST', `object/resumes/${A.id}/${tag}-big.pdf`, { body: pdf(5 * 1024 * 1024 + 1), type: 'application/pdf' });
    if (big.ok) created.objects.push(`${A.id}/${tag}-big.pdf`);
    const bRead = await obj(B.token, 'GET', `object/authenticated/resumes/${okPath}`);
    const bWrite = await obj(B.token, 'POST', `object/resumes/${A.id}/${tag}-intruder.pdf`, { body: pdf(), type: 'application/pdf' });
    if (bWrite.ok) created.objects.push(`${A.id}/${tag}-intruder.pdf`);
    const bOverwrite = await obj(B.token, 'PUT', `object/resumes/${okPath}`, { body: pdf(80), type: 'application/pdf' });
    const bDelete = await obj(B.token, 'DELETE', 'object/resumes', { body: JSON.stringify({ prefixes: [okPath] }), type: 'application/json' });
    const anonUp = await obj(null, 'POST', `object/resumes/${A.id}/${tag}-anon.pdf`, { body: pdf(), type: 'application/pdf' });
    if (anonUp.ok) created.objects.push(`${A.id}/${tag}-anon.pdf`);
    const pub = await obj(null, 'GET', `object/public/resumes/${okPath}`);
    const anonRead = await obj(null, 'GET', `object/authenticated/resumes/${okPath}`);
    const bList = await list(B.token, A.id);
    const anonList = await list(null, A.id);
    const aList = await list(A.token, A.id);
    const stillThere = await obj(A.token, 'GET', `object/authenticated/resumes/${okPath}`);
    check('Storage: valid PDF in own folder; non-PDF and >5 MiB refused; foreign folder, list, overwrite, delete and anon blocked',
      up.ok && denied(txt) && denied(big) && denied(bRead) && denied(bWrite) && denied(bOverwrite) && denied(anonUp) && denied(anonRead) && denied(pub)
        && (denied(bList) || (await rows(bList))?.length === 0) && (denied(anonList) || (await rows(anonList))?.length === 0)
        && (await rows(aList))?.some((o) => `${A.id}/${o.name}` === okPath) && stillThere.ok,
      `own-upload ${up.status} text ${txt.status} big ${big.status} B-read ${bRead.status} B-write ${bWrite.status} B-overwrite ${bOverwrite.status} B-delete ${bDelete.status} anon-upload ${anonUp.status} public ${pub.status} anon-read ${anonRead.status} B-list ${bList.status} anon-list ${anonList.status} A-list ${aList.status} A-still-reads ${stillThere.status}`);

    const sign = await obj(A.token, 'POST', `object/sign/resumes/${okPath}`, { body: JSON.stringify({ expiresIn: 5 }), type: 'application/json' });
    const signed = sign.ok ? (await sign.json()).signedURL : null;
    const first = signed ? await fetchImpl(`${base}/storage/v1${signed}`) : null;
    const bSign = await obj(B.token, 'POST', `object/sign/resumes/${okPath}`, { body: JSON.stringify({ expiresIn: 5 }), type: 'application/json' });
    await new Promise((r) => setTimeout(r, env.E2E_SIGNED_WAIT_MS ? Number(env.E2E_SIGNED_WAIT_MS) : 7000));
    const later = signed ? await fetchImpl(`${base}/storage/v1${signed}`) : null;
    check('Storage: signed URL works and then expires; bucket is not public; B cannot sign A\'s file',
      !!first?.ok && !!later && denied(later) && denied(bSign) && denied(pub), `create ${sign.status} first ${first?.status} after-expiry ${later?.status} B-sign ${bSign.status}`);

    const A2 = await signIn(env.E2E_EMAIL_A, 'A');
    const again = await (await rest(A2.token, 'professional_profiles', { query: `?id=eq.${SA.profile}&select=name` })).json();
    const favAgain = await count(A2.token, 'saved_jobs', `?job_key=eq.${encodeURIComponent(`${created.favouritePrefix}:A`)}`);
    check('A data persists after signing in again', again[0]?.name === `${tag}-A` && favAgain === 1, `profile ${again.length} fav ${favAgain}`);

    // ───────── 7. quotas
    const quotaProbe = async (user, table, limit, make, extraQuery = '') => {
      const have = await count(user.token, table);
      const fill = limit - have;
      if (fill < 0) return { ok: false, why: `${table}: already ${have} rows` };
      const first = fill ? await rest(user.token, table, { method: 'POST', body: Array.from({ length: fill }, (_, i) => make(have + i)), prefer: 'return=minimal' }) : { ok: true, status: 0 };
      const over = await rest(user.token, table, { method: 'POST', body: make(limit + 1000) });
      const body = over.ok ? '' : await over.text();
      return { ok: first.ok && !over.ok && /quota exceeded|53400/.test(body), why: `fill ${first.status} over ${over.status} ${body.slice(0, 80)}` };
    };
    if (withQuotas) {
      const q1 = await quotaProbe(A, 'resumes', 10, (i) => ({ user_id: A.id, profile_id: SA.profile, storage_path: `${A.id}/${tag}-q${i}.pdf` }));
      await rest(A.token, 'resumes', { method: 'DELETE', query: `?storage_path=like.${encodeURIComponent(`${A.id}/${tag}-`)}*` });
      const q2 = await quotaProbe(A, 'saved_searches', 100, (i) => ({ user_id: A.id, query: { q: tag, n: i } }));
      await rest(A.token, 'saved_searches', { method: 'DELETE', query: `?query->>q=eq.${tag}` });
      check('quota: 11th resume refused; 101st saved search refused (one bulk request each)', q1.ok && q2.ok, `resumes: ${q1.why}; saved_searches: ${q2.why}`);
    }
    if (withBulk) {
      const q3 = await quotaProbe(A, 'saved_jobs', 1000, (i) => ({ user_id: A.id, job_key: `${created.favouritePrefix}:q${i}`, snapshot: { source: 'e2e', title: 'T', company: 'C' } }));
      const upsert = await rest(A.token, 'saved_jobs', { method: 'POST', prefer: 'resolution=merge-duplicates,return=minimal', query: '?on_conflict=user_id,job_key',
        body: { user_id: A.id, job_key: `${created.favouritePrefix}:q5`, note: 'upsert at the limit', snapshot: { source: 'e2e', title: 'T2', company: 'C' } } });
      await rest(A.token, 'saved_jobs', { method: 'DELETE', query: `?job_key=like.${encodeURIComponent(`${created.favouritePrefix}:`)}*` });
      const q4 = await quotaProbe(A, 'applications', 2000, (i) => ({ user_id: A.id, note: tag, job_snapshot: { title: tag, n: i } }));
      await rest(A.token, 'applications', { method: 'DELETE', query: `?note=eq.${tag}&id=neq.${SA.application}` });
      check('quota (bulk): 1,001st saved job and 2,001st application refused; upsert of an existing favourite still allowed',
        q3.ok && q4.ok && upsert.ok, `saved_jobs: ${q3.why}; applications: ${q4.why}; upsert at limit ${upsert.status}`);
    }
  } finally {
    // ───────── 8. cleanup + leftovers check
    let clean = true; const left = [];
    for (const U of [A, B]) {
      const mine = created.objects.filter((p) => p.startsWith(`${U.id}/`));
      // objects are owned by the folder's user; try with that user's token (an intruder-created file would be refused: reported)
      if (mine.length) clean &&= (await obj(U.token, 'DELETE', 'object/resumes', { body: JSON.stringify({ prefixes: mine }), type: 'application/json' })).ok;
      clean &&= (await rest(U.token, 'saved_jobs', { method: 'DELETE', query: `?job_key=like.${encodeURIComponent('e2e:')}*&snapshot->>source=eq.e2e` })).ok;
      clean &&= (await rest(U.token, 'saved_searches', { method: 'DELETE', query: `?query->>q=eq.${tag}` })).ok;
      clean &&= (await rest(U.token, 'applications', { method: 'DELETE', query: `?note=eq.${tag}` })).ok;
      for (const id of created.applications) clean &&= (await rest(U.token, 'applications', { method: 'DELETE', query: `?id=eq.${id}` })).ok;
      for (const id of created.profiles) clean &&= (await rest(U.token, 'professional_profiles', { method: 'DELETE', query: `?id=eq.${id}` })).ok;
      if (created.prefs.includes(U.id)) clean &&= (await rest(U.token, 'user_preferences', { method: 'DELETE', query: `?user_id=eq.${U.id}` })).ok;
      const folder = await list(U.token, U.id);
      const names = ((await rows(folder)) ?? []).map((o) => o.name).filter((n) => n.includes(tag));
      if (names.length) left.push(`${names.length} object(s) of ${U.label}`);
      for (const t of ['professional_profiles', 'experiences', 'education', 'credentials', 'resumes', 'saved_jobs', 'saved_searches', 'applications', 'application_events', 'reminders', 'user_preferences']) {
        const n = await count(U.token, t);
        if (n > 0) left.push(`${n} row(s) in ${t} of ${U.label}`);
      }
    }
    check('cleanup of everything created and no leftovers (rows or objects)', clean && left.length === 0, `${clean ? '' : 'a delete failed; '}${left.join(', ')}`);
  }
  return results;
}

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  if (dry) {
    console.log('DRY RUN: no request is sent. Planned checks:');
    STEPS.forEach((s, i) => console.log(`${String(i + 1).padStart(2)}. ${s}`));
    process.exit(0);
  }
  try {
    if (args.has('--signup')) {
      const res = await signup(process.env);
      process.exit(res.every((r) => r.ok && !r.autoConfirmed) ? 0 : 2);
    }
    const res = await run(process.env);
    const bad = res.filter((r) => !r.ok);
    console.log(`\n${res.length - bad.length}/${res.length} checks passed`);
    process.exit(bad.length ? 2 : 0);
  } catch (e) { fail(e.message); }
}
