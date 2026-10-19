#!/usr/bin/env node
// Remote operational health check, READ-ONLY (11.0). Uses the Worker's own key (ORBIJOB_WORKER_KEY, the same secret the revalidation workflow already
// has), which can read job_sources, jobs and sync_runs and nothing else; only GET is ever sent. Exit code 1 when a check is ALERT, so a scheduled run
// turns red and GitHub notifies the owner (the free plan has no other paging channel); 0 for OK and WARN.
//   ORBIJOB_WORKER_KEY=sb_secret_... node scripts/ops-health-remote.mjs
import { appendFileSync } from 'node:fs';
import { REF, resolveWorkerKey } from './worker-key.mjs';
import { evaluateHealth, worst } from './ops-health-lib.mjs';

const r = resolveWorkerKey({ fromCli: false });
if (r.error) { console.error(`PARE: ${r.error}`); process.exit(2); }
const BASE = `https://${REF}.supabase.co/rest/v1`;
const get = async (path, headers = {}) => {
  const res = await fetch(`${BASE}/${path}`, { method: 'GET', headers: { apikey: r.key, ...headers }, signal: AbortSignal.timeout(20_000) });
  if (!res.ok) throw new Error(`HTTP ${res.status} on ${path.split('?')[0]}`);
  return res;
};
const now = new Date();
const iso = (h) => new Date(now.getTime() - h * 3600_000).toISOString();

try {
  const sources = await (await get('job_sources?select=id,can_redistribute')).json();
  const runs24h = await (await get(`sync_runs?select=source_id,scope,status,error_class,started_at&started_at=gte.${iso(24)}&limit=1000`)).json();
  const newestChecked = {};
  const openCounts = {};
  for (const s of sources.filter((x) => x.can_redistribute)) {
    const rows = await (await get(`jobs?select=last_checked_at&source_id=eq.${s.id}&status=eq.open&order=last_checked_at.desc&limit=1`)).json();
    newestChecked[s.id] = rows[0]?.last_checked_at ?? null;
    const count = async (q) => Number(((await get(`jobs?select=id&source_id=eq.${s.id}&status=eq.open${q}`, { Prefer: 'count=exact', Range: '0-0' })).headers.get('content-range') ?? '').split('/')[1] ?? 0);
    openCounts[s.id] = { open: await count(''), stale: await count(`&last_checked_at=lt.${iso(72)}`) };
  }
  const head = await get(`jobs?select=id,job_sources!inner(id)&status=eq.open&job_sources.can_redistribute=eq.true&last_checked_at=gte.${iso(72)}`, { Prefer: 'count=exact', Range: '0-0' });
  const visibleJobs = Number((head.headers.get('content-range') ?? '').split('/')[1] ?? 0);
  const rows = evaluateHealth({ now, sources, newestChecked, runs24h, visibleJobs, openCounts });
  const overall = worst(rows);
  const lines = rows.map((x) => `${x.status.padEnd(11)} ${x.check}: ${x.value}`);
  console.log(`ops-health ${now.toISOString()}: ${overall}\n${lines.join('\n')}`);
  if (process.env.GITHUB_STEP_SUMMARY) {
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, `### Ops health: ${overall}\n\n| status | check | value |\n|---|---|---|\n${rows.map((x) => `| ${x.status} | ${x.check} | ${x.value} |`).join('\n')}\n`);
  }
  process.exit(overall === 'ALERT' ? 1 : 0);
} catch (e) {
  console.error(`ALERT ops-health could not read the project: ${e instanceof Error ? e.message : e}`);
  process.exit(1);
}
