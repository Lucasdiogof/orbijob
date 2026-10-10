// Verificações PURAS da primeira ingestão do Jobicy (sem rede, sem segredo): recebem o estado lido do banco e devolvem
// { failures, warnings }. Usadas por scripts/first-ingestion-local.mjs e testadas em test/first-ingestion.test.ts.
export const EXPECTED_ATTRIBUTION = 'Remote jobs via Jobicy (https://jobicy.com)';

const isJobicyUrl = (s) => {
  try {
    const u = new URL(s);
    return u.protocol === 'https:' && (u.hostname === 'jobicy.com' || u.hostname.endsWith('.jobicy.com')) && !u.username && !u.password;
  } catch {
    return false;
  }
};

/** Antes de gravar qualquer coisa. state: { keyKind, source, jobsTotal, syncRunsTotal } */
export function evaluatePreflight(state) {
  const failures = [];
  if (state.keyKind !== 'secret') {
    failures.push(`a credencial deve ser uma chave sb_secret_ NOVA (tipo encontrado: ${state.keyKind}); a chave JWT legada exposta nao pode ser usada`);
  }
  const s = state.source;
  if (!s) failures.push('a fonte jobicy nao existe em job_sources');
  else {
    if (s.status !== 'CONDITIONAL') failures.push(`status da fonte deve ser CONDITIONAL (encontrado ${s.status})`);
    if (s.can_redistribute !== false) failures.push('can_redistribute deve ser false antes da ingestao');
    if (s.attribution !== EXPECTED_ATTRIBUTION) failures.push('texto de atribuicao da fonte diferente do esperado');
  }
  if (state.jobsTotal !== 0) failures.push(`a primeira ingestao exige jobs vazia (ha ${state.jobsTotal})`);
  if (state.syncRunsTotal !== 0) failures.push(`a primeira ingestao exige sync_runs vazia (ha ${state.syncRunsTotal})`);
  return { failures, warnings: [] };
}

/** Depois da passada, somente leitura. state: { source, runs[], jobs[], otherSourceJobs, anonJobs } */
export function evaluateVerification(state) {
  const failures = [];
  const warnings = [];
  const s = state.source;
  if (!s || s.status !== 'CONDITIONAL' || s.can_redistribute !== false || s.attribution !== EXPECTED_ATTRIBUTION) {
    failures.push('a linha da fonte mudou (esperado CONDITIONAL, can_redistribute=false, atribuicao original)');
  }
  const runs = state.runs ?? [];
  if (runs.length !== 1) failures.push(`esperada exatamente 1 linha em sync_runs (ha ${runs.length})`);
  const run = runs[0];
  if (run) {
    if (run.status === 'running' || !run.finished_at) failures.push('a passada nao foi encerrada (status running / sem finished_at)');
    else if (run.status === 'failed') failures.push(`a passada falhou (error_class=${run.error_class ?? 'desconhecida'})`);
    else if (run.status === 'partial' && run.error_class === 'max_pages') { /* esperado: o teto de paginas da primeira ingestao foi atingido */ }
    else if (run.status === 'partial') warnings.push(`passada parcial (http_errors=${run.http_errors}, error_class=${run.error_class ?? '-'}): a publicacao ficara bloqueada ate uma passada limpa`);
    if (run.http_errors > 0 && run.status === 'ok') warnings.push(`http_errors=${run.http_errors} numa passada ok`);
  }
  const jobs = state.jobs ?? [];
  if (jobs.length === 0) failures.push('nenhuma vaga gravada');
  if (run && jobs.length !== run.upserted) warnings.push(`vagas no banco (${jobs.length}) != upserted do sync_runs (${run.upserted})`);
  const badUrl = jobs.filter((j) => !isJobicyUrl(j.original_url) || !isJobicyUrl(j.canonical_url)).length;
  if (badUrl) failures.push(`${badUrl} vaga(s) com URL fora de https://jobicy.com`);
  const html = jobs.filter((j) => /<\/?[a-z][^>]*>/i.test(j.description ?? '')).length;
  if (html) failures.push(`${html} vaga(s) com HTML na descricao`);
  const dup = (key) => {
    const seen = new Map();
    for (const j of jobs) seen.set(j[key], (seen.get(j[key]) ?? 0) + 1);
    return [...seen.values()].filter((n) => n > 1).length;
  };
  if (dup('external_id')) failures.push('external_id duplicado (viola a chave unica)');
  const dupFp = dup('fingerprint');
  const dupCanon = dup('canonical_url');
  if (dupFp) warnings.push(`${dupFp} fingerprint(s) repetido(s)`);
  if (dupCanon) warnings.push(`${dupCanon} canonical_url(s) repetida(s)`);
  if (jobs.some((j) => j.source_id !== 'jobicy')) failures.push('vaga com source_id diferente de jobicy');
  if (state.otherSourceJobs !== 0) failures.push(`ha ${state.otherSourceJobs} vaga(s) de outra fonte`);
  if (state.anonSourceVisible === false) warnings.push('o acesso publico nao enxerga a linha da fonte (job_sources_read): a atribuicao nao seria exibida');
  if (state.anonJobs !== 0) failures.push(`o acesso publico (anon) enxerga ${state.anonJobs} vaga(s) com can_redistribute=false`);
  return { failures, warnings };
}
