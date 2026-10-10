#!/usr/bin/env node
// REVALIDAÇÃO LOCAL das vagas do Jobicy que já estão no banco. Não importa nada, não usa Cloudflare, não deixa cron, não faz deploy.
//
//   node scripts/revalidate-local.mjs preflight   somente leitura: confere chave, fonte e se há o que revalidar
//   node scripts/revalidate-local.mjs run --yes   UMA passada em modo "revalidate" + verificação do que mudou
//
// O que a passada faz (SYNC_MODE=revalidate, fixo neste script): pergunta ao endpoint oficial de status do Jobicy sobre as vagas abertas
// já gravadas; fecha SÓ as que a fonte responde "closed"; move last_checked_at das que responde "active"; deixa como estão as
// "unknown" e as sem resposta. NÃO lê o feed, NÃO grava vaga nova, NÃO toca em job_sources (can_redistribute) nem em tabela de usuário.
//
// Credencial: igual a first-ingestion-local.mjs, nesta ordem: ORBIJOB_SUPABASE_SECRET (memória do processo chamador), ou a CLI do
// Supabase já logada (`projects api-keys --reveal`, filtrada pelo NOME da chave KEY_NAME, nada do restante é impresso ou guardado).
// A chave nunca é escrita em arquivo, nunca vai em argumento de linha de comando e nunca é impressa. Só `sb_secret_...` é aceita.
//
// A verificação final compara o banco antes e depois: mesmo conjunto de vagas (nada importado), só transições open -> closed, o
// número de fechadas igual ao que a passada informou, fonte inalterada. Qualquer diferença reprova (código de saída 1), sem desfazer nada.
// Códigos de saída: 0 ok (ou adiada pela lease); 1 reprovada/falhou; 3 corte de tempo; 4 credencial recusada; 5 banco inalcançável; 6 passada parcial.
import { build } from 'esbuild';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const REF = 'rpmlfxwebnlxnwadyvle';
const localOnly = (name) => {
  const v = process.env[name];
  if (!v) return undefined;
  let u; try { u = new URL(v); } catch { u = null; }
  if (!u || u.protocol !== 'http:' || !(['127.0.0.1', 'localhost'].includes(u.hostname))) { console.error(`PARE: ${name} so aceita http://127.0.0.1 ou http://localhost`); process.exit(1); }
  return u.origin;
};
const PROJECT_URL = localOnly('ORBIJOB_REHEARSAL_BASE') ?? `https://${REF}.supabase.co`;
const JOBICY_ORIGIN = localOnly('ORBIJOB_REHEARSAL_JOBICY');
const KEY_NAME = 'orbijob_ingest_local';
const BUDGET_MS = 3 * 60_000;
const HARD_LIMIT_MS = 4 * 60_000;
const [, , mode = '', ...flags] = process.argv;
if (!['preflight', 'run'].includes(mode)) { console.error('uso: node scripts/revalidate-local.mjs preflight | run --yes'); process.exit(2); }
const fail = (m) => { console.error(`PARE: ${m}`); process.exit(1); };

function keyFromCli() {
  const cli = ['supabase', 'projects', 'api-keys', '--project-ref', REF, '--reveal', '-o', 'json'];
  const cwd = fileURLToPath(new URL('../../', import.meta.url));
  const r = process.platform === 'win32'
    ? spawnSync(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', 'npx', ...cli], { cwd, encoding: 'utf8', maxBuffer: 1e7, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true })
    : spawnSync('npx', cli, { cwd, encoding: 'utf8', maxBuffer: 1e7, stdio: ['ignore', 'pipe', 'pipe'] });
  let text = r.stdout ?? ''; r.stdout = ''; r.stderr = '';
  let keys;
  try { keys = JSON.parse(text.slice(text.indexOf('['))); } catch { return null; } finally { text = ''; }
  const found = keys.filter((k) => k.type === 'secret' && k.name === KEY_NAME);
  const k = found.length === 1 && typeof found[0].api_key === 'string' ? found[0].api_key : null;
  keys.length = 0; found.length = 0;
  return k;
}
const KEY = (process.env.ORBIJOB_SUPABASE_SECRET ?? '').trim() || keyFromCli();
if (!KEY) fail(`nao achei a chave secreta "${KEY_NAME}" nem a CLI logada`);

const srcDir = fileURLToPath(new URL('../src/', import.meta.url));
const out = await build({
  stdin: { contents: "export { runScheduledSync } from './scheduled'; export { classifyKey } from './env'; export { consoleSink } from './log';", resolveDir: srcDir, loader: 'ts' },
  bundle: true, format: 'esm', platform: 'node', target: 'node22', write: false, logLevel: 'silent',
});
const W = await import('data:text/javascript;base64,' + Buffer.from(out.outputFiles[0].text).toString('base64'));
if (W.classifyKey(KEY) !== 'secret') fail('credencial recusada: so uma chave sb_secret_ exclusiva e aceita (nunca a chave JWT legada)');

const rest = async (path) => {
  let r;
  try { r = await fetch(`${PROJECT_URL}/rest/v1/${path}`, { headers: { apikey: KEY }, signal: AbortSignal.timeout(20_000) }); }
  catch { console.error('PARE: banco inalcancavel (rede/tempo esgotado)'); process.exit(5); }
  if (r.status === 401 || r.status === 403) { console.error(`PARE: a credencial foi recusada pelo Supabase (HTTP ${r.status})`); process.exit(4); }
  if (!r.ok) fail(`consulta ${path.split('?')[0]} recusada (HTTP ${r.status})`);
  return await r.json();
};
async function snapshot() {
  const jobs = [];
  for (let off = 0; ; off += 1000) {
    const page = await rest(`jobs?select=external_id,status,last_checked_at&source_id=eq.jobicy&order=external_id&limit=1000&offset=${off}`);
    jobs.push(...page);
    if (page.length < 1000) break;
  }
  const source = (await rest('job_sources?select=id,status,attribution,can_redistribute&id=eq.jobicy'))[0] ?? null;
  const running = await rest('sync_runs?select=id&source_id=eq.jobicy&status=eq.running');
  const runs = await rest('sync_runs?select=id&source_id=eq.jobicy');
  return { jobs, source, running: running.length, runs: runs.length };
}

const before = await snapshot();
const open = before.jobs.filter((j) => j.status === 'open').length;
const pre = [];
if (!before.source) pre.push('a fonte jobicy nao existe');
if (before.jobs.length === 0) pre.push('nao ha vagas gravadas para revalidar');
if (open === 0) pre.push('nao ha vaga aberta para revalidar');
if (before.running > 0) pre.push('ha uma passada em andamento (running) em sync_runs');
console.log(`preflight: ${pre.length ? 'REPROVADO' : 'OK'}  vagas=${before.jobs.length} abertas=${open} fonte=${before.source?.status}/${before.source?.can_redistribute}`);
for (const p of pre) console.log(`  FALHA  ${p}`);
if (mode === 'preflight') process.exit(pre.length ? 1 : 0);
if (pre.length) fail('preflight reprovado: nada foi gravado');
if (!flags.includes('--yes')) fail('rode com --yes para confirmar que o proprietario autorizou esta passada de revalidacao');
setTimeout(() => { console.error('PARE: corte duro de tempo atingido'); process.exit(3); }, HARD_LIMIT_MS).unref();

console.log('iniciando UMA revalidacao (nenhuma vaga sera importada)...');
let outcome;
let crash = null; // SyncFailure kind ('auth' | 'unreachable' | 'unexpected') or the error name, for the exit code
try {
  outcome = await W.runScheduledSync(
    { SUPABASE_URL: PROJECT_URL, SUPABASE_SERVICE_ROLE_KEY: KEY, SYNC_MODE: 'revalidate', ...(JOBICY_ORIGIN ? { JOBICY_API_URL: JOBICY_ORIGIN } : {}) },
    { fetch: (i, o) => fetch(i, o), now: () => new Date(), sink: W.consoleSink, budgetMs: BUDGET_MS },
  );
} catch (e) {
  crash = e && typeof e === 'object' && 'kind' in e ? String(e.kind) : (e instanceof Error ? e.name : 'desconhecido');
  console.error(`a passada terminou com erro: ${crash} (detalhes nos logs acima; nenhum valor secreto e impresso)`);
}
if (outcome) console.log(`resultado: ${outcome.status}${outcome.status === 'skipped' ? ` (${outcome.reason})` : ''}${outcome.summary ? ` fechadas=${outcome.summary.closed} confirmadas=${outcome.summary.confirmed} sem_resposta=${outcome.summary.unverified}` : ''}`);

// Verificação: só leituras novas.
const after = await snapshot();
const problems = [];
const a = new Map(after.jobs.map((j) => [j.external_id, j]));
const b = new Map(before.jobs.map((j) => [j.external_id, j]));
if (after.jobs.length !== before.jobs.length || [...a.keys()].some((k) => !b.has(k)) || [...b.keys()].some((k) => !a.has(k))) problems.push('o conjunto de vagas mudou (algo foi importado ou removido)');
let newlyClosed = 0, stamped = 0;
for (const [id, j] of a) {
  const o = b.get(id); if (!o) continue;
  if (o.status !== j.status) { if (o.status === 'open' && j.status === 'closed') newlyClosed++; else problems.push(`transicao inesperada em uma vaga (${o.status} -> ${j.status})`); }
  if (j.last_checked_at !== o.last_checked_at && j.status === 'open') stamped++;
}
if (outcome?.summary && newlyClosed !== outcome.summary.closed) problems.push(`vagas fechadas (${newlyClosed}) diferem do informado pela passada (${outcome.summary.closed})`);
if (JSON.stringify(after.source) !== JSON.stringify(before.source)) problems.push('a linha da fonte mudou');
if (outcome && outcome.status !== 'skipped' && after.runs !== before.runs + 1) problems.push('esperava exatamente 1 linha nova em sync_runs');
console.log(`verificacao: ${problems.length ? 'REPROVADO' : 'OK'}  vagas=${after.jobs.length} (antes ${before.jobs.length}) fechadas_agora=${newlyClosed} com_nova_data=${stamped} fonte=${after.source?.status}/${after.source?.can_redistribute}`);
for (const p of problems) console.log(`  FALHA  ${p}`);
// Exit codes (the GitHub Actions workflow maps them to alerts): 0 ok or skipped by the lease; 1 verification failed / pass failed;
// 4 Supabase refused the credential; 5 Supabase unreachable; 6 partial pass (API errors or timeout on some batch).
const code = problems.length ? 1
  : crash === 'auth' ? 4
  : crash === 'unreachable' ? 5
  : !outcome || outcome.status === 'failed' ? 1
  : outcome.status === 'partial' ? 6
  : 0;
console.log(`codigo de saida: ${code}`);
process.exit(code);
