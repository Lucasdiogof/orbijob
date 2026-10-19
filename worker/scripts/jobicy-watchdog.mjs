#!/usr/bin/env node
// Monitor da revalidação automática do Jobicy, feito só com recursos gratuitos do GitHub.
//
// Lê: (1) o catálogo PÚBLICO do Supabase com a chave publishable (variável SUPABASE_PUBLISHABLE_KEY; chave pública por desenho,
// a mesma que vai dentro do app; NÃO é um segredo), (2) as execuções agendadas do workflow "Jobicy revalidate" pela API do GitHub com o GITHUB_TOKEN do
// próprio job (permissões actions: read e issues: write). Escreve: SOMENTE uma issue de alerta (abre, atualiza, fecha). Não toca no banco.
//
//   node worker/scripts/jobicy-watchdog.mjs            avalia e mantém a issue
//   node worker/scripts/jobicy-watchdog.mjs --dry-run  avalia e imprime; não mexe em issue
//
// Variáveis: SUPABASE_PUBLISHABLE_KEY, GITHUB_TOKEN, GITHUB_REPOSITORY, JOBICY_REVALIDATION_ENABLED ('true' liga as regras das execuções agendadas),
// GITHUB_RUN_ID/GITHUB_SERVER_URL (só para o link). Em teste: WATCHDOG_GITHUB_API e WATCHDOG_SUPABASE_URL (apenas http://127.0.0.1).
import { ISSUE_LABEL, ISSUE_TITLE, evaluate, evaluateDiscovery, renderIssueBody } from './watchdog-core.mjs';

const dry = process.argv.includes('--dry-run');
const localOnly = (name, fallback) => {
  const v = process.env[name];
  if (!v) return fallback;
  const u = new URL(v);
  if (u.protocol !== 'http:' || !['127.0.0.1', 'localhost'].includes(u.hostname)) { console.error(`PARE: ${name} so aceita http://127.0.0.1`); process.exit(1); }
  return u.origin;
};
const SUPABASE = localOnly('WATCHDOG_SUPABASE_URL', 'https://rpmlfxwebnlxnwadyvle.supabase.co');
const PUBLISHABLE = (process.env.SUPABASE_PUBLISHABLE_KEY ?? '').trim();
if (!PUBLISHABLE.startsWith('sb_publishable_')) { console.error('PARE: defina SUPABASE_PUBLISHABLE_KEY com a chave PUBLISHABLE (publica) do projeto; nunca uma chave secreta'); process.exit(1); }
const GH = localOnly('WATCHDOG_GITHUB_API', 'https://api.github.com');
const REPO = process.env.GITHUB_REPOSITORY ?? 'Lucasdiogof/orbijob';
const TOKEN = process.env.GITHUB_TOKEN ?? '';
const enabled = (process.env.JOBICY_REVALIDATION_ENABLED ?? '') === 'true';
const discoveryEnabled = (process.env.JOBICY_DISCOVERY_ENABLED ?? '') === 'true';
const sourcesEnabled = (process.env.SOURCES_DISCOVERY_ENABLED ?? '') === 'true';
const sourcesRevalEnabled = (process.env.SOURCES_REVALIDATION_ENABLED ?? '') === 'true';

const gh = async (path, init = {}) => {
  const r = await fetch(`${GH}${path}`, { ...init, headers: { Accept: 'application/vnd.github+json', ...(TOKEN ? { Authorization: `Bearer ${TOKEN}` } : {}), 'X-GitHub-Api-Version': '2022-11-28', ...(init.headers ?? {}) }, signal: AbortSignal.timeout(20_000) });
  if (!r.ok) throw new Error(`GitHub API ${init.method ?? 'GET'} ${path.split('?')[0]} -> HTTP ${r.status}`);
  return r.status === 204 ? null : await r.json();
};

// 1. the public catalogue
const pub = await fetch(`${SUPABASE}/rest/v1/jobs?select=last_checked_at&order=last_checked_at.asc&limit=1`, { headers: { apikey: PUBLISHABLE, Prefer: 'count=exact' }, signal: AbortSignal.timeout(20_000) });
if (!pub.ok) { console.error(`PARE: leitura publica do catalogo falhou (HTTP ${pub.status})`); process.exit(1); }
const first = await pub.json();
const visibleJobs = Number((pub.headers.get('content-range') ?? '*/0').split('/')[1]);
// The validity deadline (72 h) is judged on the sources that are verified one by one: Jobicy (status endpoint) and the Platsbanken (/ad/{id}).
// A source read as a window of its newest pages (Arbeitnow) or as a whole feed (Remote OK, Remotive) legitimately holds older rows that the app
// already hides; they are reported in the log line below, not alarmed on.
// A few listings the source no longer answers for (neither open nor closed) stay unverified: the app already hides them after 72 h and the expiry
// turns them `unknown` after 7 days. Alarming on the single oldest of them was a false CRITICAL (2026-10-19: 4 of 1,624 Jobicy listings at 109 h while
// 1,620 were verified within 24 h). The age is judged after skipping those stragglers: max(25, 2 % of the open listings). If the revalidation
// really stops, the whole catalogue ages together and the alert fires exactly as before.
const STRAGGLERS = (open) => Math.max(25, Math.ceil(open * 0.02));
const oldestOf = async (source) => {
  const head = await fetch(`${SUPABASE}/rest/v1/jobs?select=id&source_id=eq.${source}&status=eq.open&limit=1`, { headers: { apikey: PUBLISHABLE, Prefer: 'count=exact' }, signal: AbortSignal.timeout(20_000) });
  if (!head.ok) throw new Error(`leitura publica (${source}) falhou (HTTP ${head.status})`);
  const open = Number((head.headers.get('content-range') ?? '*/0').split('/')[1]) || 0;
  const skip = Math.min(STRAGGLERS(open), Math.max(0, open - 1));
  const r = await fetch(`${SUPABASE}/rest/v1/jobs?select=last_checked_at&source_id=eq.${source}&status=eq.open&order=last_checked_at.asc&offset=${skip}&limit=1`, { headers: { apikey: PUBLISHABLE }, signal: AbortSignal.timeout(20_000) });
  if (!r.ok) throw new Error(`leitura publica (${source}) falhou (HTTP ${r.status})`);
  return (await r.json())[0]?.last_checked_at ?? null;
};
const verified = (await Promise.all(['jobicy', 'jobtech'].map(oldestOf))).filter(Boolean).sort();
const oldestCheckedAt = verified[0] ?? first[0]?.last_checked_at ?? null;

// 2. the scheduled runs of the revalidation workflow (newest first), and what the last finished one reported about itself
const wf = 'jobicy-revalidate.yml';
const list = await gh(`/repos/${REPO}/actions/workflows/${wf}/runs?event=schedule&per_page=10`);
const runs = (list.workflow_runs ?? []).map((r) => ({ id: r.id, createdAt: r.created_at, conclusion: r.conclusion, status: r.status, url: r.html_url, alerts: [] }));
const lastDone = runs.find((r) => r.status === 'completed' && r.conclusion === 'failure');
if (enabled && lastDone && lastDone === runs.find((r) => r.status === 'completed')) {
  const jobs = await gh(`/repos/${REPO}/actions/runs/${lastDone.id}/jobs`).catch(() => ({ jobs: [] }));
  for (const j of jobs.jobs ?? []) for (const s of j.steps ?? []) {
    if (s.conclusion !== 'success') continue;
    const m = /^ALERT (auth|unreachable|api):/.exec(s.name ?? '');
    if (m) lastDone.alerts.push(m[1]);
  }
}

// 2b. the recurring discovery, only once it is switched on (JOBICY_DISCOVERY_ENABLED); same reading of the ALERT markers of the last failed run
// reads the scheduled runs of one discovery workflow and the ALERT markers of the last failed one
async function readDiscoveryRuns(workflow) {
  const dl = await gh(`/repos/${REPO}/actions/workflows/${workflow}/runs?event=schedule&per_page=10`);
  const out = (dl.workflow_runs ?? []).map((r) => ({ id: r.id, createdAt: r.created_at, conclusion: r.conclusion, status: r.status, url: r.html_url, alerts: [] }));
  const lastFailed = out.find((r) => r.status === 'completed');
  if (lastFailed && lastFailed.conclusion === 'failure') {
    const jobs = await gh(`/repos/${REPO}/actions/runs/${lastFailed.id}/jobs`).catch(() => ({ jobs: [] }));
    for (const j of jobs.jobs ?? []) for (const s of j.steps ?? []) {
      if (s.conclusion !== 'success') continue;
      const m = /^ALERT (auth|unreachable|api|storage):/.exec(s.name ?? '');
      if (m) lastFailed.alerts.push(m[1]);
    }
  }
  return out;
}
const discoverRuns = discoveryEnabled ? await readDiscoveryRuns('jobicy-discover.yml') : [];
const sourcesRuns = sourcesEnabled ? await readDiscoveryRuns('sources-discover.yml') : [];
const platsRevalRuns = sourcesRevalEnabled ? await readDiscoveryRuns('sources-revalidate.yml') : [];

const base = evaluate({ nowMs: Date.now(), enabled, runs, oldestCheckedAt, visibleJobs });
const alerts = [
  ...base.alerts,
  ...evaluateDiscovery({ nowMs: Date.now(), enabled: discoveryEnabled, runs: discoverRuns }),
  ...evaluateDiscovery({ nowMs: Date.now(), enabled: sourcesEnabled, runs: sourcesRuns, prefix: 'sources', label: 'das fontes adicionais (Arbeitnow, Remote OK, Remotive, Platsbanken)' }),
  ...evaluateDiscovery({ nowMs: Date.now(), enabled: sourcesRevalEnabled, runs: platsRevalRuns, prefix: 'platsbanken_revalidation', label: 'da revalidacao da Platsbanken' }),
];
const healthy = alerts.length === 0;
console.log(`catalogo publico: ${visibleJobs} vagas; verificacao mais antiga: ${oldestCheckedAt ?? '-'}; automacao ${enabled ? 'LIGADA' : 'desligada'}; execucoes agendadas lidas: ${runs.length}; descoberta ${discoveryEnabled ? `LIGADA (${discoverRuns.length} execucoes lidas)` : 'desligada'}; fontes adicionais ${sourcesEnabled ? `LIGADAS (${sourcesRuns.length} execucoes lidas)` : 'desligadas'}; revalidacao da Platsbanken ${sourcesRevalEnabled ? `LIGADA (${platsRevalRuns.length} execucoes lidas)` : 'desligada'}`);
for (const a of alerts) console.log(`${a.severity.toUpperCase()} ${a.id}: ${a.message}`);
console.log(healthy ? 'tudo normal' : `${alerts.length} alerta(s)`);
if (dry) process.exit(0);

// 3. the alert issue: opened/updated while there are alerts, closed when everything is normal
const open = (await gh(`/repos/${REPO}/issues?labels=${ISSUE_LABEL}&state=open&per_page=5`)).filter((i) => !i.pull_request);
const runUrl = process.env.GITHUB_RUN_ID ? `${process.env.GITHUB_SERVER_URL ?? 'https://github.com'}/${REPO}/actions/runs/${process.env.GITHUB_RUN_ID}` : '';
if (healthy) {
  for (const i of open) {
    await gh(`/repos/${REPO}/issues/${i.number}/comments`, { method: 'POST', body: JSON.stringify({ body: 'Tudo voltou ao normal; fechando automaticamente.' }) });
    await gh(`/repos/${REPO}/issues/${i.number}`, { method: 'PATCH', body: JSON.stringify({ state: 'closed', state_reason: 'completed' }) });
  }
} else {
  const body = renderIssueBody({ alerts, nowIso: new Date().toISOString(), runUrl });
  if (open.length) await gh(`/repos/${REPO}/issues/${open[0].number}`, { method: 'PATCH', body: JSON.stringify({ title: ISSUE_TITLE, body }) });
  else await gh(`/repos/${REPO}/issues`, { method: 'POST', body: JSON.stringify({ title: ISSUE_TITLE, body, labels: [ISSUE_LABEL] }) });
}
// A critical alert also fails this job, so GitHub's own failure e-mail reaches the owner.
process.exit(alerts.some((a) => a.severity === 'critical') ? 1 : 0);
