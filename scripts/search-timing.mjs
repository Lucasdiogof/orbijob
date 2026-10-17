// Read-only timing of the catalogue query the app sends (first page, no exact count) for every benchmark query: slow filters show up as a statement timeout in
// production long before they show up in a count. Uses the same alternatives table as search-benchmark.mjs.
//   BENCH_QUERIES=scripts/search-benchmark.queries.br.json BENCH_ALTS=scripts/search-benchmark.alternatives.br.json node scripts/search-timing.mjs
import { readFileSync } from 'node:fs';

const KEY = process.env.SUPABASE_PUBLISHABLE_KEY ?? JSON.parse(readFileSync(new URL('../app/dart_defines.web.json', import.meta.url), 'utf8')).SUPABASE_PUBLISHABLE_KEY;
const URL_ = 'https://rpmlfxwebnlxnwadyvle.supabase.co/rest/v1/jobs';
const queries = JSON.parse(readFileSync(process.env.BENCH_QUERIES ?? new URL('./search-benchmark.queries.json', import.meta.url), 'utf8'));
const table = JSON.parse(readFileSync(process.env.BENCH_ALTS ?? new URL('./search-benchmark.alternatives.json', import.meta.url), 'utf8'));
const sanitize = (s) => s.replace(/[^\p{L}\p{N}\s+#-]/gu, ' ').replace(/\s+/g, ' ').trim();
const alt = (a) => (a.length === 1 ? `title.ilike.*${a[0]}*` : `and(${a.map((p) => `title.ilike.*${p}*`).join(',')})`);
const COLS = 'id,source_id,external_id,company,title,description,country,city,language,work_mode,contract_type,geo_restrictions,skills,job_sources!inner(id,attribution,can_redistribute,status)';
let worst = 0, slow = 0, failed = 0;
for (const q of queries) {
  const term = sanitize(q);
  const after = (table[q]?.after ?? []).map(alt);
  const or = [...(after.length ? [] : [`search.wfts(simple).${term}`]), `title.ilike.*${term}*`, `city.ilike.*${term}*`, ...after].join(',');
  const u = new URL(URL_);
  u.searchParams.set('select', COLS);
  u.searchParams.set('status', 'eq.open');
  u.searchParams.set('job_sources.can_redistribute', 'eq.true');
  u.searchParams.set('last_checked_at', `gte.${new Date(Date.now() - 72 * 3600e3).toISOString()}`);
  u.searchParams.set('or', `(${or})`);
  u.searchParams.set('order', 'published_at.desc.nullslast,id.desc');
  const t0 = Date.now();
  const r = await fetch(u, { headers: { apikey: KEY, Range: '0-20' } });
  const ms = Date.now() - t0;
  const body = r.ok ? (await r.json()).length : (await r.text()).slice(0, 60);
  worst = Math.max(worst, ms);
  if (!r.ok) failed++; else if (ms > 3000) slow++;
  console.log(`${String(ms).padStart(6)} ms  HTTP ${r.status}  rows=${r.ok ? body : '-'}  alts=${after.length}  ${q}${r.ok ? '' : '  ' + body}`);
}
console.log(`worst ${worst} ms, slower than 3 s: ${slow}, failed: ${failed}, of ${queries.length}`);
