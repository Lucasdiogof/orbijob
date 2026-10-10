#!/usr/bin/env node
// End-to-end run of the Worker in the REAL Cloudflare runtime (workerd, via `wrangler dev`, local mode, no Cloudflare
// account and nothing deployed). It fires the scheduled handler through wrangler's local endpoint and checks, against the
// stub (scripts/e2e-stub.mjs), that the pass really happened, that the credential travelled in the right header and that a
// second delivery is skipped.
//
//   node scripts/e2e-workerd.mjs                          (in-memory Supabase model)
//   POSTGREST_URL=http://localhost:3000 E2E_KEY=<jwt> node scripts/e2e-workerd.mjs   (CI: real PostgREST behind the stub)
//
// Only localhost is contacted. The key used here is a made-up value (or a JWT signed with a throw-away CI secret).
import { spawn } from 'node:child_process';
import { createHmac } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const STUB = Number(process.env.STUB_PORT ?? 8788);
const WORKER = Number(process.env.WORKER_PORT ?? 8799);
const POSTGREST = process.env.POSTGREST_URL?.replace(/\/+$/, '');
// E2E_MODE=full (default): SYNC_MODE=full is passed explicitly and a whole pass is checked.
// E2E_MODE=pinned: nothing is passed; the SYNC_MODE pinned in wrangler.toml (the production setting) must import NOTHING.
const PINNED = process.env.E2E_MODE === 'pinned';
// With a real PostgREST behind the stub the credential must be a JWT it accepts: signed here with the throw-away CI secret.
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const signJwt = (secret) => { const h = b64({ alg: 'HS256', typ: 'JWT' }); const p = b64({ role: 'service_role', exp: Math.floor(Date.now() / 1000) + 3600 }); return `${h}.${p}.${createHmac('sha256', secret).update(`${h}.${p}`).digest('base64url')}`; };
const KEY = POSTGREST ? signJwt(process.env.E2E_JWT_SECRET) : (process.env.E2E_KEY ?? 'sb_secret_' + 'E2ETESTKEY'.repeat(5));
const here = (p) => fileURLToPath(new URL(p, import.meta.url));
const procs = [];
const failures = [];
const check = (ok, msg) => { if (!ok) failures.push(msg); console.log(`${ok ? '  ok  ' : '  FAIL'} ${msg}`); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
/** Counters come from the stub; stored data comes from the stub's memory, or from the real database when PostgREST is behind it. */
const state = async () => {
  const s = await (await fetch(`http://127.0.0.1:${STUB}/__state`)).json();
  if (!POSTGREST) return s;
  const q = async (path) => (await fetch(`${POSTGREST}${path}`, { headers: { Authorization: `Bearer ${KEY}` } })).json();
  const jobs = await q('/jobs?select=external_id,status&source_id=eq.jobicy');
  const runs = await q('/sync_runs?select=status,upserted&source_id=eq.jobicy');
  return { ...s, jobs: jobs.length, openJobs: jobs.filter((j) => j.status === 'open').length, runs };
};

function start(cmd, args, env, label, lines) {
  const p = spawn(cmd, args, { env: { ...process.env, ...env }, stdio: ['ignore', 'pipe', 'pipe'], cwd: here('../') });
  p.stdout.on('data', (d) => lines.push(String(d)));
  p.stderr.on('data', (d) => lines.push(String(d)));
  p.on('exit', (c) => lines.push(`[${label} exited ${c}]`));
  procs.push(p);
  return p;
}
async function waitFor(url, what, ms = 90_000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { try { await fetch(url); return; } catch { await sleep(500); } }
  throw new Error(`${what} did not start`);
}
const stop = () => { for (const p of procs) try { p.kill(); } catch { /* already gone */ } };
process.on('exit', stop);

const stubLog = [], workerLog = [];
try {
  start(process.execPath, [here('./e2e-stub.mjs')], { STUB_PORT: String(STUB), E2E_KEY: KEY, ...(POSTGREST ? { POSTGREST_URL: POSTGREST } : {}) }, 'stub', stubLog);
  await waitFor(`http://127.0.0.1:${STUB}/__state`, 'stub');
  start(process.execPath, [here('../node_modules/wrangler/bin/wrangler.js'), 'dev', '--local', '--port', String(WORKER), '--ip', '127.0.0.1',
    '--var', 'SUPABASE_URL:http://127.0.0.1:' + STUB, '--var', 'SUPABASE_SERVICE_ROLE_KEY:' + KEY, '--var', 'JOBICY_API_URL:http://127.0.0.1:' + STUB, ...(PINNED ? [] : ['--var', 'SYNC_MODE:full'])],
    { WRANGLER_SEND_METRICS: 'false', CI: '1', NO_COLOR: '1' }, 'worker', workerLog);
  await waitFor(`http://127.0.0.1:${WORKER}/`, 'wrangler dev');

  console.log('first delivery of the cron:');
  const r1 = await fetch(`http://127.0.0.1:${WORKER}/cdn-cgi/handler/scheduled?cron=0+*/6+*+*+*&format=json`);
  const t1 = await r1.text();
  check(r1.status === 200, `scheduled handler finished without an exception (HTTP ${r1.status} ${t1.slice(0, 80)})`);
  let s = await state();
  if (PINNED) {
    check(s.feed === 0, `the pinned production mode did NOT touch the Jobicy feed (feed calls ${s.feed})`);
    check(s.jobs === 0, `the pinned production mode imported NO job (got ${s.jobs})`);
    check(s.runs.length === 1 && s.runs[0].status === 'ok' && s.runs[0].upserted === 0, `ONE run row, finished ok with 0 upserted (got ${JSON.stringify(s.runs.map((r) => [r.status, r.upserted]))})`);
  } else {
    check(s.feed === 2, `Jobicy feed asked for exactly the 2 pages of one pass (got ${s.feed})`);
    check(s.jobs === 10 && s.openJobs === 10, `10 listings stored and open (got ${s.jobs}/${s.openJobs})`);
    check(s.runs.length === 1 && s.runs[0].status === 'ok' && s.runs[0].upserted === 10, `ONE run row, finished ok with 10 upserted (got ${JSON.stringify(s.runs.map((r) => [r.status, r.upserted]))})`);
  }
  check(s.badAuth === 0, 'no Supabase request was refused for its credential format');
  const isJwt = /^eyJ[\w-]+\.[\w-]+\.[\w-]+$/.test(KEY);
  check(s.headers.every((h) => h.apikey && h.authorization === isJwt), `credential sent in the right headers for a ${isJwt ? 'JWT' : 'sb_secret_'} key`);

  console.log('second delivery right after (duplicate cron / manual retry):');
  const r2 = await fetch(`http://127.0.0.1:${WORKER}/cdn-cgi/handler/scheduled?cron=0+*/6+*+*+*&format=json`);
  check(r2.status === 200, `second delivery did not fail (HTTP ${r2.status})`);
  s = await state();
  check(s.feed === (PINNED ? 0 : 2), `Jobicy was NOT asked again within the hour (feed calls ${s.feed})`);
  check(s.runs.length === 1, `no new run row for the skipped delivery (rows ${s.runs.length})`);

  await sleep(500);
  const logs = workerLog.join('');
  check(logs.includes('"event":"sync_start"') && logs.includes('"event":"sync_ok"'), 'structured logs reached the runtime console (sync_start, sync_ok)');
  check(logs.includes(PINNED ? '"mode":"revalidate"' : '"mode":"full"'), `the run logged its mode (${PINNED ? 'revalidate, from wrangler.toml' : 'full, passed explicitly'})`);
  check(logs.includes('"event":"sync_skipped"') && logs.includes('too_soon'), 'the skipped delivery was logged as too_soon');
  check(!logs.includes(KEY) && !logs.includes('E2ETESTKEY') && !logs.includes(KEY.split('.')[2] ?? KEY), 'the credential appears in no log line');
  check(!/Illegal invocation/i.test(logs), 'no "Illegal invocation" (platform functions are called correctly in workerd)');
  const pub = await fetch(`http://127.0.0.1:${WORKER}/`);
  check(pub.status === 404, `the Worker answers 404 to a plain HTTP request (HTTP ${pub.status})`);
} catch (e) {
  failures.push(String(e));
  console.error(String(e));
  console.error('--- worker log tail ---\n' + workerLog.join('').slice(-2500));
  console.error('--- stub log tail ---\n' + stubLog.join('').slice(-800));
} finally {
  stop();
}
if (failures.length) { console.error(`\nE2E FAILED (${failures.length})`); process.exit(1); }
console.log(PINNED ? '\nE2E OK: the pinned production mode revalidated and imported nothing, in workerd' : '\nE2E OK: the Worker ran a full pass in workerd');
process.exit(0);
