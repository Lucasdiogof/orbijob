#!/usr/bin/env node
// Primeira ingestão do Jobicy, LOCAL e CONTROLADA: uma passada, sem Cloudflare, sem cron, sem deploy.
//
//   node scripts/first-ingestion-local.mjs preflight   somente leitura: confere chave, fonte, tabelas vazias
//   node scripts/first-ingestion-local.mjs run --yes   preflight + UMA passada + verificação (grava vagas)
//   node scripts/first-ingestion-local.mjs verify      somente leitura: confere o que foi gravado (pode rodar sozinho, depois)
//
// Credencial (uma chave `sb_secret_...` exclusiva, nome KEY_NAME no painel do Supabase), nesta ordem:
//   1. variável ORBIJOB_SUPABASE_SECRET, se o processo chamador a definiu (só na memória dele);
//   2. a própria CLI do Supabase já logada: `supabase projects api-keys --reveal`, capturada em memória e filtrada pelo NOME
//      da chave (a saída da CLI nunca é impressa, nem as outras chaves que ela lista);
//   3. com --prompt-key, um prompt SEM ECO no terminal.
// A chave nunca é escrita em arquivo, nunca vai para argumentos de linha de comando e nunca é impressa (o logger também a
// oculta). Só `sb_secret_...` é aceita: a chave JWT legada `service_role` (exposta em 2026-10-10) é recusada.
//
// Limites: no máximo SYNC_MAX_PAGES páginas (padrão 3, teto 5), orçamento de 3 minutos (a passada se encerra sozinha como
// "partial/deadline") e corte duro em 4 minutos. A passada só começa com jobs e sync_runs vazias, portanto só pode acontecer
// uma vez. Nada aqui toca em can_redistribute: a fonte continua não publicada e o app não vê nenhuma vaga.
import { build } from 'esbuild';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { evaluatePreflight, evaluateVerification } from './first-ingestion-checks.mjs';

const REF = 'rpmlfxwebnlxnwadyvle';
// Ensaio local (testes): ORBIJOB_REHEARSAL_BASE / ORBIJOB_REHEARSAL_JOBICY trocam os destinos por um servidor de mentira em
// 127.0.0.1. Qualquer outro endereco e recusado, entao a chave nunca sai da maquina por esse caminho.
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
if (!['preflight', 'run', 'verify'].includes(mode)) {
  console.error('uso: node scripts/first-ingestion-local.mjs preflight | run --yes | verify  [--prompt-key]');
  process.exit(2);
}
const fail = (m) => { console.error(`PARE: ${m}`); process.exit(1); };

/**
 * Uma unica chamada a CLI logada (`projects api-keys --reveal`). Devolve SO as duas chaves de que o runner precisa: a secreta
 * pelo NOME e a publishable (publica por desenho, usada para ver o que o app enxerga). O resto da saida, que inclui as chaves
 * legadas completas, e descartado ali mesmo: nunca e impresso, gravado nem guardado.
 */
let cliCache;
let cliStatus = null; // codigo de saida da CLI (so o numero: nunca a saida)
function cliKeys() {
  if (cliCache) return cliCache;
  const cli = ['supabase', 'projects', 'api-keys', '--project-ref', REF, '--reveal', '-o', 'json'];
  const cwd = fileURLToPath(new URL('../../', import.meta.url)); // raiz do repositorio, onde supabase/.temp ja existe (a CLI nao cria pastas novas em worker/)
  const r = process.platform === 'win32'
    ? spawnSync(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', 'npx', ...cli], { cwd, encoding: 'utf8', maxBuffer: 1e7, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true })
    : spawnSync('npx', cli, { cwd, encoding: 'utf8', maxBuffer: 1e7, stdio: ['ignore', 'pipe', 'pipe'] });
  cliStatus = r.error ? `erro ao iniciar (${r.error.code ?? 'desconhecido'})` : r.status;
  let text = r.stdout ?? '';
  r.stdout = ''; r.stderr = '';
  let keys;
  try { keys = JSON.parse(text.slice(text.indexOf('['))); } catch { return (cliCache = { secret: null, publishable: null }); } finally { text = ''; }
  const found = keys.filter((k) => k.type === 'secret' && k.name === KEY_NAME);
  const pub = keys.find((k) => k.type === 'publishable');
  cliCache = {
    secret: found.length === 1 && typeof found[0].api_key === 'string' ? found[0].api_key : null,
    publishable: typeof pub?.api_key === 'string' && pub.api_key.startsWith('sb_publishable_') ? pub.api_key : null,
  };
  keys.length = 0; found.length = 0;
  return cliCache;
}
const keyFromCli = () => cliKeys().secret;

/** Chave publishable: variavel ORBIJOB_PUBLISHABLE_KEY, ou a da CLI. (Nao depende de arquivos locais fora do Git.) */
function resolvePublishable() {
  const v = (process.env.ORBIJOB_PUBLISHABLE_KEY ?? '').trim();
  const k = v || cliKeys().publishable;
  if (!k || !k.startsWith('sb_publishable_')) fail('nao consegui obter a chave publishable (defina ORBIJOB_PUBLISHABLE_KEY ou deixe a CLI logada)');
  return k;
}

async function promptSecret() {
  if (!process.stdin.isTTY) fail('--prompt-key precisa de um terminal interativo');
  process.stderr.write('Chave sb_secret_ (nao aparece na tela): ');
  return await new Promise((resolve) => {
    let buf = '';
    process.stdin.setRawMode(true); process.stdin.resume(); process.stdin.setEncoding('utf8');
    const onData = (c) => {
      for (const ch of c) {
        if (ch === '\r' || ch === '\n') { process.stdin.setRawMode(false); process.stdin.pause(); process.stdin.off('data', onData); process.stderr.write('\n'); return resolve(buf.trim()); }
        if (ch === '\u0003') { process.stdin.setRawMode(false); process.exit(130); } // Ctrl+C
        if (ch === '\u007f' || ch === '\b') buf = buf.slice(0, -1); else buf += ch;
      }
    };
    process.stdin.on('data', onData);
  });
}

async function resolveKey() {
  const fromEnv = (process.env.ORBIJOB_SUPABASE_SECRET ?? '').trim();
  if (fromEnv) return fromEnv;
  if (flags.includes('--prompt-key')) return await promptSecret();
  const k = keyFromCli();
  if (!k) fail(`nao achei a chave secreta "${KEY_NAME}" (crie-a no painel do Supabase, em Project Settings > API Keys) ou a CLI nao esta logada (a CLI terminou com: ${cliStatus})`);
  return k;
}

// Bundle em memória de src/ (TypeScript) para reutilizar EXATAMENTE o código do Worker, sem arquivo temporário.
const srcDir = fileURLToPath(new URL('../src/', import.meta.url));
const out = await build({
  stdin: { contents: "export { runScheduledSync } from './scheduled'; export { classifyKey } from './env'; export { consoleSink } from './log';", resolveDir: srcDir, loader: 'ts' },
  bundle: true, format: 'esm', platform: 'node', target: 'node22', write: false, logLevel: 'silent',
});
const W = await import('data:text/javascript;base64,' + Buffer.from(out.outputFiles[0].text).toString('base64'));

const KEY = await resolveKey();
const keyKind = W.classifyKey(KEY);
const PUBLISHABLE = resolvePublishable(); // antes de qualquer gravacao: a verificacao final precisa dela
// Recusa ANTES de qualquer requisicao: a chave legada (ou qualquer outra que nao seja sb_secret_) nunca e enviada a lugar nenhum.
if (keyKind !== 'secret') fail(`credencial recusada: tipo "${keyKind}"; so uma chave sb_secret_ exclusiva e aceita (a chave JWT legada service_role esta comprometida)`);
const rest = async (path, { key = KEY, count = false } = {}) => {
  const r = await fetch(`${PROJECT_URL}/rest/v1/${path}`, { headers: { apikey: key, ...(count ? { Prefer: 'count=exact', Range: '0-0' } : {}) }, signal: AbortSignal.timeout(20_000) });
  if (!r.ok) fail(`consulta ${path.split('?')[0]} recusada (HTTP ${r.status})`);
  if (count) return Number((r.headers.get('content-range') ?? '*/0').split('/')[1]);
  return await r.json();
};

async function readPreflightState() {
  const [src] = await rest('job_sources?select=id,status,attribution,can_redistribute&id=eq.jobicy');
  return {
    keyKind, source: src ?? null,
    jobsTotal: await rest('jobs?select=id', { count: true }),
    syncRunsTotal: await rest('sync_runs?select=id', { count: true }),
  };
}

function report(title, { failures, warnings }) {
  console.log(`${title}: ${failures.length ? 'REPROVADO' : 'OK'}`);
  for (const f of failures) console.log(`  FALHA  ${f}`);
  for (const w of warnings) console.log(`  aviso  ${w}`);
  return failures.length === 0;
}

/** Leituras novas, sem usar nada do resultado da passada: o que vale é o que está no banco e o que o público enxerga. */
async function verify() {
  const pub = PUBLISHABLE;
  const state = {
    source: (await rest('job_sources?select=id,status,attribution,can_redistribute&id=eq.jobicy'))[0] ?? null,
    runs: await rest('sync_runs?select=status,fetched,upserted,duplicates,closed,http_errors,error_class,started_at,finished_at&source_id=eq.jobicy'),
    jobs: await rest('jobs?select=source_id,external_id,original_url,canonical_url,fingerprint,description,status&source_id=eq.jobicy&limit=1000'),
    otherSourceJobs: await rest('jobs?select=id&source_id=neq.jobicy', { count: true }),
    anonJobs: await rest('jobs?select=id', { key: pub, count: true }),
    anonSourceVisible: (await rest('job_sources?select=id,can_redistribute&id=eq.jobicy', { key: pub })).length === 1,
  };
  const r = evaluateVerification(state);
  const run = state.runs[0];
  if (run) console.log(`sync_runs: status=${run.status} fetched=${run.fetched} upserted=${run.upserted} duplicates=${run.duplicates} closed=${run.closed} http_errors=${run.http_errors} error_class=${run.error_class ?? '-'}`);
  console.log(`vagas do jobicy no banco: ${state.jobs.length}; de outras fontes: ${state.otherSourceJobs}; visiveis ao publico (anon): ${state.anonJobs}`);
  console.log(`fonte: status=${state.source?.status} can_redistribute=${state.source?.can_redistribute}`);
  return report('verificacao', r);
}

if (mode === 'verify') process.exit((await verify()) ? 0 : 1);

const pre = report('preflight', evaluatePreflight(await readPreflightState()));
if (mode === 'preflight') process.exit(pre ? 0 : 1);
if (!pre) fail('preflight reprovado: nada foi gravado');
if (!flags.includes('--yes')) fail('rode com --yes para confirmar que o proprietario autorizou esta UNICA passada');

const maxPages = Number(process.env.SYNC_MAX_PAGES ?? 3);
if (!Number.isInteger(maxPages) || maxPages < 1 || maxPages > 5) fail('SYNC_MAX_PAGES invalido (1 a 5)');
setTimeout(() => { console.error('PARE: corte duro de tempo atingido; veja a recuperacao no runbook'); process.exit(3); }, HARD_LIMIT_MS).unref();

console.log(`iniciando UMA passada (ate ${maxPages} paginas, orcamento ${BUDGET_MS / 60000} min, corte ${HARD_LIMIT_MS / 60000} min)...`);
let outcome;
try {
  outcome = await W.runScheduledSync(
    { SUPABASE_URL: PROJECT_URL, SUPABASE_SERVICE_ROLE_KEY: KEY, SYNC_MAX_PAGES: String(maxPages), ...(JOBICY_ORIGIN ? { JOBICY_API_URL: JOBICY_ORIGIN } : {}) },
    { fetch: (i, o) => fetch(i, o), now: () => new Date(), sink: W.consoleSink, budgetMs: BUDGET_MS },
  );
} catch (e) {
  console.error(`a passada terminou com erro: ${e instanceof Error ? e.name : 'desconhecido'} (detalhes nos logs acima; nenhum valor secreto e impresso)`);
}
if (outcome) console.log(`resultado: ${outcome.status}${outcome.status === 'skipped' ? ` (${outcome.reason})` : ''}`);
process.exit((await verify()) ? 0 : 1);
