#!/usr/bin/env node
// OrbiJob end-to-end check against a REAL Supabase project, using the PUBLISHABLE key and two throw-away accounts.
// It talks to Auth, PostgREST and Storage exactly as the app does, and never uses a secret/service_role key.
//   ORBIJOB_E2E_CONFIRM=rpmlfxwebnlxnwadyvle SUPABASE_URL=https://rpmlfxwebnlxnwadyvle.supabase.co \
//   SUPABASE_PUBLISHABLE_KEY=sb_publishable_... E2E_EMAIL_A=... E2E_EMAIL_B=... E2E_PASSWORD=... \
//   node scripts/supabase/e2e_remote.mjs [--quotas] [--dry-run]
// The accounts must already exist and be confirmed (create them in the dashboard: Authentication -> Users).
// WRITES test rows/objects under those two accounts only and removes them at the end. Do not run it before the
// migrations have been applied with the owner's authorization. --dry-run prints the plan and touches nothing.
const PROJECT_REF = 'rpmlfxwebnlxnwadyvle';
const args = new Set(process.argv.slice(2));
const dry = args.has('--dry-run');
const quotas = args.has('--quotas');

export const STEPS = [
  'sign in as A and B (Auth)',
  'anonymous key alone cannot read private tables',
  'A writes profile, favourite and saved search; B sees none of them',
  'B cannot update or delete A rows, nor insert rows owned by A',
  'A uploads a valid PDF to its own folder',
  'non-PDF content is rejected by the bucket',
  'file over 5 MiB is rejected',
  'B cannot read, list-by-path, overwrite or upload into A folder; bucket is not public',
  'signed URL works and then expires',
  'A data persists after signing out and in again',
  ...(quotas ? ['11th resume row is refused (quota)'] : []),
  'cleanup of everything created',
];

function fail(msg) { console.error(`E2E ABORTED: ${msg}`); process.exit(1); }

export function isSecretKey(key) {
  if (key.startsWith('sb_secret_')) return true;
  const p = key.split('.');
  if (p.length !== 3) return false;
  try { return JSON.parse(Buffer.from(p[1], 'base64url').toString()).role === 'service_role'; } catch { return false; }
}

export async function run(env, fetchImpl = fetch, { quotas: withQuotas = quotas } = {}) {
  const base = env.SUPABASE_URL?.replace(/\/$/, '');
  const key = env.SUPABASE_PUBLISHABLE_KEY;
  if (env.ORBIJOB_E2E_CONFIRM !== PROJECT_REF) throw new Error(`set ORBIJOB_E2E_CONFIRM=${PROJECT_REF} to confirm the target project`);
  if (!base || !key || !env.E2E_EMAIL_A || !env.E2E_EMAIL_B || !env.E2E_PASSWORD) throw new Error('missing SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, E2E_EMAIL_A, E2E_EMAIL_B or E2E_PASSWORD');
  if (new URL(base).hostname !== `${PROJECT_REF}.supabase.co` && !/^(localhost|127\.0\.0\.1)$/.test(new URL(base).hostname)) throw new Error('SUPABASE_URL does not belong to the expected project');
  if (isSecretKey(key)) throw new Error('refusing to run with a secret/service_role key: use the publishable key');

  const results = [];
  const check = (name, ok, detail = '') => { results.push({ name, ok, detail }); console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : `  -> ${detail}`}`); };
  const denied = (r) => r.status >= 400;
  const emptyOrDenied = async (r) => denied(r) || (await r.clone().json().catch(() => null))?.length === 0;

  const rest = (token, table, { method = 'GET', query = '', body } = {}) => fetchImpl(`${base}/rest/v1/${table}${query}`, {
    method, headers: { apikey: key, ...(token ? { Authorization: `Bearer ${token}` } : {}), 'Content-Type': 'application/json', Prefer: 'return=representation' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const signIn = async (email) => {
    const r = await fetchImpl(`${base}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: key, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password: env.E2E_PASSWORD }) });
    if (!r.ok) throw new Error(`sign-in failed for a test account (HTTP ${r.status}); accounts must exist and be confirmed`);
    const j = await r.json();
    return { token: j.access_token, id: j.user.id };
  };
  const obj = (token, method, path, { body, type, extra = {} } = {}) => fetchImpl(`${base}/storage/v1/${path}`, {
    method, headers: { apikey: key, ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(type ? { 'Content-Type': type } : {}), ...extra }, body,
  });
  const pdf = (bytes = 64) => { const b = Buffer.alloc(bytes, 0x20); b.write('%PDF-1.7\n'); return b; };

  const A = await signIn(env.E2E_EMAIL_A);
  const B = await signIn(env.E2E_EMAIL_B);
  check('sign in as A and B (Auth)', A.id !== B.id && !!A.token && !!B.token);

  const anon = await rest(null, 'professional_profiles');
  check('anonymous key alone cannot read private tables', denied(anon), `HTTP ${anon.status}`);

  const tag = `e2e-${Date.now()}`;
  const created = { profile: null, objects: [], favouriteKey: `e2e:${tag}` };
  try {
    const p = await rest(A.token, 'professional_profiles', { method: 'POST', body: { user_id: A.id, name: tag, skills: ['e2e'] } });
    const prof = (await p.json())[0];
    created.profile = prof?.id;
    const fav = await rest(A.token, 'saved_jobs', { method: 'POST', body: { user_id: A.id, job_key: created.favouriteKey, snapshot: { source: 'e2e', externalId: tag, title: 'T', company: 'C', originalUrl: 'https://example.invalid' } } });
    const ss = await rest(A.token, 'saved_searches', { method: 'POST', body: { user_id: A.id, query: { q: tag } } });
    const ssId = (await ss.json())[0]?.id;
    const bProfiles = await rest(B.token, 'professional_profiles', { query: `?id=eq.${created.profile}` });
    const bFav = await rest(B.token, 'saved_jobs', { query: `?job_key=eq.${encodeURIComponent(created.favouriteKey)}` });
    const bSearch = await rest(B.token, 'saved_searches', { query: `?id=eq.${ssId}` });
    check('A writes profile, favourite and saved search; B sees none of them',
      p.ok && fav.ok && ss.ok && await emptyOrDenied(bProfiles) && await emptyOrDenied(bFav) && await emptyOrDenied(bSearch),
      `A: ${p.status}/${fav.status}/${ss.status}`);

    const upd = await rest(B.token, 'professional_profiles', { method: 'PATCH', query: `?id=eq.${created.profile}`, body: { name: 'pwn' } });
    const del = await rest(B.token, 'professional_profiles', { method: 'DELETE', query: `?id=eq.${created.profile}` });
    const forged = await rest(B.token, 'saved_searches', { method: 'POST', body: { user_id: A.id, query: { forged: true } } });
    const stillThere = await (await rest(A.token, 'professional_profiles', { query: `?id=eq.${created.profile}` })).json();
    check('B cannot update or delete A rows, nor insert rows owned by A',
      await emptyOrDenied(upd) && await emptyOrDenied(del) && denied(forged) && stillThere[0]?.name === tag,
      `PATCH ${upd.status} DELETE ${del.status} forged-insert ${forged.status}`);

    const okPath = `${A.id}/${tag}.pdf`;
    const up = await obj(A.token, 'POST', `object/resumes/${okPath}`, { body: pdf(), type: 'application/pdf' });
    if (up.ok) created.objects.push(okPath);
    check('A uploads a valid PDF to its own folder', up.ok, `HTTP ${up.status}`);

    const txt = await obj(A.token, 'POST', `object/resumes/${A.id}/${tag}-text.pdf`, { body: Buffer.from('plain text, not a PDF'), type: 'text/plain' });
    if (txt.ok) created.objects.push(`${A.id}/${tag}-text.pdf`);
    check('non-PDF content is rejected by the bucket', denied(txt), `HTTP ${txt.status}`);

    const big = await obj(A.token, 'POST', `object/resumes/${A.id}/${tag}-big.pdf`, { body: pdf(5 * 1024 * 1024 + 1), type: 'application/pdf' });
    if (big.ok) created.objects.push(`${A.id}/${tag}-big.pdf`);
    check('file over 5 MiB is rejected', denied(big), `HTTP ${big.status}`);

    const bRead = await obj(B.token, 'GET', `object/authenticated/resumes/${okPath}`);
    const bWrite = await obj(B.token, 'POST', `object/resumes/${A.id}/${tag}-intruder.pdf`, { body: pdf(), type: 'application/pdf' });
    if (bWrite.ok) created.objects.push(`${A.id}/${tag}-intruder.pdf`);
    const bOverwrite = await obj(B.token, 'PUT', `object/resumes/${okPath}`, { body: pdf(80), type: 'application/pdf' });
    const pub = await obj(null, 'GET', `object/public/resumes/${okPath}`);
    const anonRead = await obj(null, 'GET', `object/authenticated/resumes/${okPath}`);
    check('B cannot read, list-by-path, overwrite or upload into A folder; bucket is not public',
      denied(bRead) && denied(bWrite) && denied(bOverwrite) && denied(pub) && denied(anonRead),
      `B-read ${bRead.status} B-write ${bWrite.status} B-overwrite ${bOverwrite.status} public ${pub.status} anon ${anonRead.status}`);

    const sign = await obj(A.token, 'POST', `object/sign/resumes/${okPath}`, { body: JSON.stringify({ expiresIn: 5 }), type: 'application/json' });
    const signed = sign.ok ? (await sign.json()).signedURL : null;
    const first = signed ? await fetchImpl(`${base}/storage/v1${signed}`) : null;
    await new Promise((r) => setTimeout(r, env.E2E_SIGNED_WAIT_MS ? Number(env.E2E_SIGNED_WAIT_MS) : 7000));
    const later = signed ? await fetchImpl(`${base}/storage/v1${signed}`) : null;
    check('signed URL works and then expires', !!first?.ok && !!later && denied(later), `create ${sign.status} first ${first?.status} after-expiry ${later?.status}`);

    const A2 = await signIn(env.E2E_EMAIL_A);
    const again = await (await rest(A2.token, 'professional_profiles', { query: `?id=eq.${created.profile}` })).json();
    const favAgain = await (await rest(A2.token, 'saved_jobs', { query: `?job_key=eq.${encodeURIComponent(created.favouriteKey)}` })).json();
    check('A data persists after signing out and in again', again[0]?.name === tag && favAgain.length === 1, `profile ${again.length} fav ${favAgain.length}`);

    if (withQuotas) {
      let refused = null;
      const ids = [];
      for (let i = 1; i <= 11; i++) {
        const r = await rest(A.token, 'resumes', { method: 'POST', body: { profile_id: created.profile, user_id: A.id, storage_path: `${A.id}/${tag}-q${i}.pdf` } });
        if (r.ok) ids.push((await r.json())[0].id); else { refused = { i, status: r.status, body: await r.text() }; break; }
      }
      for (const id of ids) await rest(A.token, 'resumes', { method: 'DELETE', query: `?id=eq.${id}` });
      check('11th resume row is refused (quota)', refused?.i === 11 && /quota exceeded|53400/.test(refused.body), JSON.stringify(refused));
    }
  } finally {
    let clean = true;
    if (created.objects.length) clean &&= (await obj(A.token, 'DELETE', 'object/resumes', { body: JSON.stringify({ prefixes: created.objects }), type: 'application/json' })).ok;
    clean &&= (await rest(A.token, 'saved_jobs', { method: 'DELETE', query: `?job_key=eq.${encodeURIComponent(created.favouriteKey)}` })).ok;
    clean &&= (await rest(A.token, 'saved_searches', { method: 'DELETE', query: `?query->>q=eq.${tag}` })).ok;
    if (created.profile) clean &&= (await rest(A.token, 'professional_profiles', { method: 'DELETE', query: `?id=eq.${created.profile}` })).ok;
    check('cleanup of everything created', clean);
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
    const res = await run(process.env);
    const bad = res.filter((r) => !r.ok);
    console.log(`\n${res.length - bad.length}/${res.length} checks passed`);
    process.exit(bad.length ? 2 : 0);
  } catch (e) { fail(e.message); }
}
