// Shared by worker-key-check.mjs and worker-secrets.mjs: where the Worker's own key comes from, and the READ-ONLY authentication checks.
// Nothing here writes to the database, and the key is never printed, logged, put in an argument or written to a file.
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const REF = 'rpmlfxwebnlxnwadyvle';
/** The key created for the Worker and for nothing else. */
export const WORKER_KEY_NAME = 'orbijob_sync_worker';
/** Keys that must NEVER be the Worker's: the one used by the local ingestion/revalidation scripts. */
export const FORBIDDEN_KEY_NAMES = ['orbijob_ingest_local', 'default'];

const here = (p) => fileURLToPath(new URL(p, import.meta.url));

/** Test rehearsal only: localhost addresses are accepted, anything else is refused, so the key cannot leave the machine this way. */
export function localOnly(name) {
  const v = process.env[name];
  if (!v) return undefined;
  let u; try { u = new URL(v); } catch { u = null; }
  if (!u || u.protocol !== 'http:' || !['127.0.0.1', 'localhost'].includes(u.hostname)) throw new Error(`${name} so aceita http://127.0.0.1 ou http://localhost`);
  return u.origin;
}

/** One call to the logged-in Supabase CLI. Returns { named: Map(name -> key), legacyPrefixes } and drops the rest of the output. */
export function cliSecretKeys() {
  const cli = ['supabase', 'projects', 'api-keys', '--project-ref', REF, '--reveal', '-o', 'json'];
  const cwd = here('../../');
  const r = process.platform === 'win32'
    ? spawnSync(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', 'npx', ...cli], { cwd, encoding: 'utf8', maxBuffer: 1e7, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true })
    : spawnSync('npx', cli, { cwd, encoding: 'utf8', maxBuffer: 1e7, stdio: ['ignore', 'pipe', 'pipe'] });
  let text = r.stdout ?? ''; r.stdout = ''; r.stderr = '';
  let keys;
  try { keys = JSON.parse(text.slice(text.indexOf('['))); } catch { return null; } finally { text = ''; }
  const named = new Map();
  for (const k of keys) if (k.type === 'secret' && typeof k.api_key === 'string') named.set(k.name, k.api_key);
  keys.length = 0;
  return named;
}

/**
 * The Worker's key: ORBIJOB_WORKER_KEY (memory of the calling process) or, with fromCli, the secret key NAMED WORKER_KEY_NAME in the
 * logged-in CLI. Refused: a legacy JWT, any non-`sb_secret_` value, and any value equal to a key that belongs to something else.
 */
export function resolveWorkerKey({ fromCli }) {
  const forbidden = [];
  let key = (process.env.ORBIJOB_WORKER_KEY ?? '').trim();
  const named = key && !fromCli ? null : cliSecretKeys();
  if (!key) {
    if (!fromCli) return { error: 'defina ORBIJOB_WORKER_KEY ou use --from-cli' };
    if (!named) return { error: 'a CLI do Supabase nao conseguiu listar as chaves (login?)' };
    key = named.get(WORKER_KEY_NAME) ?? '';
    if (!key) return { error: `nao existe a chave secreta "${WORKER_KEY_NAME}" (veja docs/JOBICY_WORKER_DEPLOY.md, passo 2)` };
  } else if (named) {
    for (const n of FORBIDDEN_KEY_NAMES) if (named.get(n) === key) forbidden.push(n);
  }
  if (named) for (const n of FORBIDDEN_KEY_NAMES) if (named.get(n) && named.get(n) === key && !forbidden.includes(n)) forbidden.push(n);
  if (!key.startsWith('sb_secret_')) return { error: 'so uma chave sb_secret_ e aceita (nunca a chave JWT legada service_role nem a publishable)' };
  if (forbidden.length) return { error: `a chave pertence a "${forbidden[0]}": o Worker precisa de uma chave PROPRIA (${WORKER_KEY_NAME})` };
  return { key };
}

/**
 * READ-ONLY checks of what the key can and cannot do. Only GET is ever sent (enforced here). Returns { failures, lines }.
 *  must read:  job_sources (the jobicy row), jobs, sync_runs
 *  must be refused: every table of user data
 */
export async function authChecks(projectUrl, key) {
  const failures = []; const lines = [];
  const get = async (path) => {
    const r = await fetch(`${projectUrl}/rest/v1/${path}`, { method: 'GET', headers: { apikey: key }, signal: AbortSignal.timeout(20_000) });
    return { status: r.status, body: await r.text() };
  };
  for (const [table, q] of [['job_sources', 'select=id,status,can_redistribute&id=eq.jobicy'], ['jobs', 'select=external_id&limit=1'], ['sync_runs', 'select=id&limit=1']]) {
    const r = await get(`${table}?${q}`);
    const ok = r.status === 200;
    lines.push(`${ok ? '  ok  ' : '  FAIL'} leitura de ${table}: HTTP ${r.status}`);
    if (!ok) failures.push(`a chave nao le ${table} (HTTP ${r.status})`);
  }
  for (const table of ['professional_profiles', 'saved_jobs', 'applications', 'user_preferences', 'credentials', 'education', 'experiences', 'reminders', 'saved_searches', 'viewed_jobs', 'application_events']) {
    const r = await get(`${table}?select=*&limit=1`);
    const refused = r.status === 401 || r.status === 403;
    lines.push(`${refused ? '  ok  ' : '  FAIL'} ${table} RECUSADA: HTTP ${r.status}`);
    if (!refused) failures.push(`a chave consegue ler a tabela de usuario ${table} (HTTP ${r.status}): permissao demais`);
  }
  return { failures, lines };
}
