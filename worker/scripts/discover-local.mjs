#!/usr/bin/env node
// DESCOBERTA INCREMENTAL de vagas novas de UMA fonte (ORBIJOB_SOURCE: jobicy, arbeitnow, remoteok ou remotive; padrão jobicy). Só INSERE vagas que ainda não estão no banco. Não usa Cloudflare, não deixa cron, não faz deploy.
//
//   node scripts/discover-local.mjs preflight      somente leitura: confere chave, fonte, passada em andamento e quantas vagas já existem
//   node scripts/discover-local.mjs preview        SIMULAÇÃO: lê o feed e pergunta o status, calcula o que seria importado e NÃO grava nada
//   node scripts/discover-local.mjs run --yes      UMA passada real (SYNC_MODE=discover) + verificação do que mudou
//
// O que a passada faz: lê o feed oficial da fonte (Jobicy: API v2 sem chave; as outras: docs/SOURCES_MATRIX.md; ritmo e páginas por fonte em src/sources.ts; uma passada por hora por fonte pela lease); separa o
// que já está gravado (qualquer status) e os duplicados; pergunta ao endpoint oficial de status se as vagas novas estão ATIVAS e só insere
// as confirmadas (INSERT ... ON CONFLICT DO NOTHING). NÃO atualiza, NÃO fecha, NÃO reabre e NÃO apaga vaga existente, NÃO toca em job_sources
// (can_redistribute) nem em tabela de usuário. Revalidar as já gravadas é outro trabalho (Supabase Cron / revalidate-local.mjs).
//
// Credencial: SOMENTE ORBIJOB_SUPABASE_SECRET (uma chave sb_secret_ exclusiva, vinda do ambiente do processo). Nunca a chave JWT legada, nunca a de
// ingestão local. A chave nunca é escrita em arquivo, nunca vai em argumento de linha de comando e nunca é impressa.
//
// A verificação final compara o banco antes e depois: toda vaga que existia continua existindo com o mesmo conteúdo (só podem mudar
// status open->closed e last_checked_at, que são da revalidação concorrente; closed->open reprova), as novas são exatamente as informadas,
// todas abertas e com URL do Jobicy, a fonte inalterada, uma linha nova em sync_runs. Qualquer diferença reprova (código 1), sem desfazer nada.
// Códigos de saída: 0 ok (ou adiada pela lease); 1 reprovada/falhou; 3 corte de tempo; 4 credencial recusada; 5 banco inalcançável; 6 passada parcial;
// 7 teto do catálogo atingido (nada mais é importado até haver limpeza ou o teto ser aumentado de propósito).
import { build } from 'esbuild';
import { createHash } from 'node:crypto';
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
const BUDGET_MS = 3 * 60_000;
const HARD_LIMIT_MS = 4 * 60_000;
const HOUR = 3_600_000;
const SRC = (process.env.ORBIJOB_SOURCE ?? 'jobicy').trim();
const [, , mode = '', ...flags] = process.argv;
if (!['preflight', 'preview', 'run'].includes(mode)) { console.error('uso: node scripts/discover-local.mjs preflight | preview | run --yes'); process.exit(2); }
const fail = (m) => { console.error(`PARE: ${m}`); process.exit(1); };

const KEY = (process.env.ORBIJOB_SUPABASE_SECRET ?? '').trim();
if (!KEY) fail('defina ORBIJOB_SUPABASE_SECRET (chave sb_secret_ exclusiva); nenhuma outra credencial e aceita');

const srcDir = fileURLToPath(new URL('../src/', import.meta.url));
const out = await build({
  stdin: {
    contents: "export { runScheduledSync } from './scheduled'; export { runSync } from './sync'; export { SOURCES } from './sources'; export { SupabaseJobStore } from './store/supabase'; export { classifyKey, DISCOVER_DEFAULT_CAP, DISCOVER_DEFAULT_CATALOGUE } from './env'; export { consoleSink } from './log';",
    resolveDir: srcDir, loader: 'ts',
  },
  bundle: true, format: 'esm', platform: 'node', target: 'node22', write: false, logLevel: 'silent',
});
const W = await import('data:text/javascript;base64,' + Buffer.from(out.outputFiles[0].text).toString('base64'));
const PROFILE = W.SOURCES[SRC];
if (!PROFILE) fail(`ORBIJOB_SOURCE desconhecida: ${SRC} (use ${Object.keys(W.SOURCES).join(', ')})`);
if (W.classifyKey(KEY) !== 'secret') fail('credencial recusada: so uma chave sb_secret_ exclusiva e aceita (nunca a chave JWT legada)');

const rest = async (path) => {
  let r;
  try { r = await fetch(`${PROJECT_URL}/rest/v1/${path}`, { headers: { apikey: KEY }, signal: AbortSignal.timeout(20_000) }); }
  catch { console.error('PARE: banco inalcancavel (rede/tempo esgotado)'); process.exit(5); }
  if (r.status === 401 || r.status === 403) { console.error(`PARE: a credencial foi recusada pelo Supabase (HTTP ${r.status})`); process.exit(4); }
  if (!r.ok) fail(`consulta ${path.split('?')[0]} recusada (HTTP ${r.status})`);
  return await r.json();
};

// Conteúdo que a descoberta jamais pode mexer (status e last_checked_at são da revalidação, que pode rodar ao mesmo tempo).
const CONTENT = ['company', 'title', 'description', 'original_url', 'apply_url', 'fingerprint', 'canonical_url', 'country', 'salary_min', 'salary_max', 'salary_currency', 'salary_period', 'published_at', 'contract_type', 'geo_restrictions'];
const hash = (row) => createHash('sha256').update(JSON.stringify(CONTENT.map((c) => row[c] ?? null))).digest('hex');
async function snapshot() {
  const jobs = new Map();
  for (let off = 0; ; off += 1000) {
    const page = await rest(`jobs?select=external_id,source_id,status,last_checked_at,${CONTENT.join(',')}&source_id=eq.${SRC}&order=external_id&limit=1000&offset=${off}`);
    for (const j of page) jobs.set(j.external_id, { status: j.status, last_checked_at: j.last_checked_at, source_id: j.source_id, url: j.original_url, hash: hash(j) });
    if (page.length < 1000) break;
  }
  const source = (await rest(`job_sources?select=id,status,attribution,can_redistribute&id=eq.${SRC}`))[0] ?? null;
  const runs = await rest(`sync_runs?select=id,status,started_at&source_id=eq.${SRC}&order=started_at.desc&limit=200`);
  return { jobs, source, running: runs.filter((r) => r.status === 'running').length, runs: runs.length, lastStart: runs[0]?.started_at ?? null };
}

const before = await snapshot();
const pre = [];
if (!before.source) pre.push(`a fonte ${SRC} nao existe`);
if (before.running > 0) pre.push('ha uma passada em andamento (running) em sync_runs');
if (before.lastStart && Date.now() - Date.parse(before.lastStart) < HOUR && mode !== 'preflight') pre.push('houve uma passada na ultima hora (no maximo uma passada por hora por fonte); tente mais tarde');
console.log(`preflight: ${pre.length ? 'REPROVADO' : 'OK'}  vagas_gravadas=${before.jobs.size} fonte=${before.source?.status}/${before.source?.can_redistribute} fonte=${SRC} limite_por_passada=${process.env.SYNC_MAX_NEW_JOBS || PROFILE.newCap} teto_do_catalogo=${process.env.SYNC_MAX_CATALOGUE || PROFILE.catalogue}`);
for (const p of pre) console.log(`  FALHA  ${p}`);
if (mode === 'preflight') process.exit(pre.length ? 1 : 0);
if (pre.length) fail('preflight reprovado: nada foi gravado');

const metrics = (s) => `metricas: lidas=${s.fetched} importadas=${s.upserted} ja_conhecidas=${s.alreadyKnown} duplicadas=${s.duplicates} inativas=${s.inactive} rejeitadas=${s.rejected} adiadas_pelo_limite=${s.skippedNew} atualizadas=0 fechadas=0 paginas=${s.pages}`;
setTimeout(() => { console.error('PARE: corte duro de tempo atingido'); process.exit(3); }, HARD_LIMIT_MS).unref();

if (mode === 'preview') {
  // SIMULAÇÃO: as mesmas regras da passada real sobre as leituras reais, mas a escrita é trocada por uma contagem. Nada é gravado.
  const store = new W.SupabaseJobStore(PROJECT_URL, KEY, (i, o) => fetch(i, o));
  const wrote = [];
  const dry = {
    listKnownKeys: (s) => store.listKnownKeys(s),
    insertNewJobs: async (rows) => { wrote.push(...rows); return rows.length; },
    upsertJobs: async () => { throw new Error('preview must never write'); },
    listOpenExternalIds: async () => [], markClosed: async () => { throw new Error('preview must never write'); },
    recordRun: async () => {},
  };
  const maxNewJobs = process.env.SYNC_MAX_NEW_JOBS ? Number(process.env.SYNC_MAX_NEW_JOBS) : PROFILE.newCap;
  const s = await W.runSync({
    connector: PROFILE.make((i, o) => fetch(i, o), () => new Date(), JOBICY_ORIGIN),
    store: dry, scope: '', mode: 'discover', maxNewJobs, maxTotalJobs: process.env.SYNC_MAX_CATALOGUE ? Number(process.env.SYNC_MAX_CATALOGUE) : PROFILE.catalogue, maxPages: PROFILE.maxPages,
    deadlineAt: Date.now() + BUDGET_MS, recordRun: async () => {},
    log: (event, data) => console.log(JSON.stringify({ level: 'info', event, ...data })),
  });
  const companies = new Set(wrote.map((r) => r.company)).size;
  console.log(`simulacao: ${s.status === 'ok' ? 'OK' : s.status.toUpperCase()} NADA FOI GRAVADO  seriam_importadas=${wrote.length} de_${companies}_empresas`);
  console.log(metrics(s));
  process.exit(s.status === 'ok' ? 0 : s.status === 'partial' ? (s.error_class === 'catalogue_full' ? 7 : 6) : 1);
}

if (!flags.includes('--yes')) fail('rode com --yes para confirmar que o proprietario autorizou esta passada de importacao');
console.log('iniciando UMA descoberta (so vagas novas serao inseridas; nenhuma existente sera alterada)...');
let outcome;
let crash = null; // SyncFailure kind ('auth' | 'unreachable' | 'unexpected') or the error name, for the exit code
try {
  outcome = await W.runScheduledSync(
    { SUPABASE_URL: PROJECT_URL, SUPABASE_SERVICE_ROLE_KEY: KEY, SYNC_MODE: 'discover', SYNC_SOURCE: SRC, ...(process.env.SYNC_MAX_NEW_JOBS ? { SYNC_MAX_NEW_JOBS: process.env.SYNC_MAX_NEW_JOBS } : {}), ...(process.env.SYNC_MAX_CATALOGUE ? { SYNC_MAX_CATALOGUE: process.env.SYNC_MAX_CATALOGUE } : {}), ...(JOBICY_ORIGIN ? (SRC === 'jobicy' ? { JOBICY_API_URL: JOBICY_ORIGIN } : { SOURCE_API_URL: JOBICY_ORIGIN }) : {}) },
    { fetch: (i, o) => fetch(i, o), now: () => new Date(), sink: W.consoleSink, budgetMs: BUDGET_MS },
  );
} catch (e) {
  crash = e && typeof e === 'object' && 'kind' in e ? String(e.kind) : (e instanceof Error ? e.name : 'desconhecido');
  console.error(`a passada terminou com erro: ${crash} (detalhes nos logs acima; nenhum valor secreto e impresso)`);
}
if (outcome) {
  console.log(`resultado: ${outcome.status}${outcome.status === 'skipped' ? ` (${outcome.reason})` : ''}${outcome.summary ? ` importadas=${outcome.summary.upserted}` : ''}`);
  if (outcome.summary) console.log(metrics(outcome.summary));
}

// Verificação: só leituras novas.
const after = await snapshot();
const problems = [];
let added = 0;
for (const [id, o] of before.jobs) {
  const j = after.jobs.get(id);
  if (!j) { problems.push('uma vaga que existia desapareceu'); continue; }
  if (j.hash !== o.hash) problems.push('o conteudo de uma vaga existente mudou (a descoberta nao pode alterar vagas existentes)');
  if (o.status !== j.status && !(o.status === 'open' && j.status === 'closed')) problems.push(`transicao inesperada em uma vaga existente (${o.status} -> ${j.status})`);
}
for (const [id, j] of after.jobs) {
  if (before.jobs.has(id)) continue;
  added++;
  if (j.status !== 'open') problems.push('uma vaga nova entrou fechada');
  if (j.source_id !== SRC) problems.push('uma vaga nova entrou com fonte diferente');
  let host = ''; try { host = new URL(j.url).hostname; } catch { /* below */ }
  if (host !== PROFILE.host && !host.endsWith(`.${PROFILE.host}`)) problems.push(`uma vaga nova nao tem a URL original de ${PROFILE.host}`);
}
const expected = outcome?.summary ? outcome.summary.upserted : 0;
if (outcome && outcome.status !== 'skipped' && added !== expected) problems.push(`vagas novas (${added}) diferem do informado pela passada (${expected})`);
if (outcome?.status === 'skipped' && added !== 0) problems.push('a passada foi adiada mas apareceram vagas novas');
if (JSON.stringify(after.source) !== JSON.stringify(before.source)) problems.push('a linha da fonte mudou');
if (outcome && outcome.status !== 'skipped' && after.runs !== before.runs + 1) problems.push('esperava exatamente 1 linha nova em sync_runs');
console.log(`verificacao: ${problems.length ? 'REPROVADO' : 'OK'}  vagas=${after.jobs.size} (antes ${before.jobs.size}) novas=${added} fonte=${after.source?.status}/${after.source?.can_redistribute}`);
for (const p of [...new Set(problems)]) console.log(`  FALHA  ${p}`);
const code = problems.length ? 1
  : crash === 'auth' ? 4
  : crash === 'unreachable' ? 5
  : !outcome || outcome.status === 'failed' ? 1
  : outcome.status === 'partial' && outcome.summary?.error_class === 'catalogue_full' ? 7
  : outcome.status === 'partial' ? 6
  : 0;
console.log(`codigo de saida: ${code}`);
process.exit(code);
