// OrbiJob 14.1 read-only link check of the listings the app shows for Brazil (based there, or remote and explicitly open to Brazil/LATAM/anywhere):
// one GET per link with the project's User-Agent, 400 ms apart, status only (no content is kept). A 403/429 is reported as "blocked", not as a dead link.
import { readFileSync } from 'node:fs';

const KEY = process.env.SUPABASE_PUBLISHABLE_KEY ?? JSON.parse(readFileSync(new URL('../app/dart_defines.web.json', import.meta.url), 'utf8')).SUPABASE_PUBLISHABLE_KEY;
const BASE = 'https://rpmlfxwebnlxnwadyvle.supabase.co/rest/v1/jobs';
const since = new Date(Date.now() - 72 * 3_600_000).toISOString();
async function get(or) {
  const u = new URL(BASE);
  u.searchParams.set('select', 'source_id,original_url,job_sources!inner(can_redistribute)');
  u.searchParams.set('status', 'eq.open');
  u.searchParams.set('job_sources.can_redistribute', 'eq.true');
  u.searchParams.set('last_checked_at', `gte.${since}`);
  u.searchParams.set('or', or);
  u.searchParams.set('limit', '1000');
  return (await fetch(u, { headers: { apikey: KEY } })).json();
}
const rows = await get('(country.eq.BR,geo_restrictions.cs.{BR},geo_restrictions.cs.{LATAM},and(work_mode.eq.remote,geo_restrictions.cs.{Anywhere}))');
const UA = 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)';
const tally = {};
const bad = [];
for (const r of rows) {
  let st;
  try {
    const res = await fetch(r.original_url, { headers: { 'user-agent': UA }, redirect: 'follow', signal: AbortSignal.timeout(20000) });
    st = res.status;
    await res.body?.cancel();
  } catch { st = 'error'; }
  const k = st === 403 || st === 429 ? 'blocked' : typeof st === 'number' && st < 400 ? 'ok' : String(st);
  tally[k] = (tally[k] ?? 0) + 1;
  if (k !== 'ok' && k !== 'blocked') bad.push(`${r.source_id} ${st} ${new URL(r.original_url).host}`);
  await new Promise((x) => setTimeout(x, 400));
}
console.log(JSON.stringify({ checked: rows.length, tally, bad: bad.slice(0, 20) }, null, 1));
