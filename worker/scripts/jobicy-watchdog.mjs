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
import { ISSUE_LABEL, ISSUE_TITLE, evaluate, renderIssueBody } from './watchdog-core.mjs';

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
const oldestCheckedAt = first[0]?.last_checked_at ?? null;

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

const { alerts, healthy } = evaluate({ nowMs: Date.now(), enabled, runs, oldestCheckedAt, visibleJobs });
console.log(`catalogo publico: ${visibleJobs} vagas; verificacao mais antiga: ${oldestCheckedAt ?? '-'}; automacao ${enabled ? 'LIGADA' : 'desligada'}; execucoes agendadas lidas: ${runs.length}`);
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
