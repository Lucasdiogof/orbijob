#!/usr/bin/env node
// Search relevance benchmark against the real catalogue, with the PUBLIC key only (the same reads the app does). Exact counts, nothing sampled.
//   (from app/) DUMP_ALTS=1 flutter test test/tool/dump_alternatives_test.dart     -> scripts/search-benchmark.alternatives.json
//   node scripts/search-benchmark.mjs [label] [--samples]
// For every query (scripts/search-benchmark.queries.json) it runs the catalogue filter the app builds in two versions:
//   before = OrbiJob 4.0: full-text OR title/city OR any flat fragment of the profession's other names inside the title
//   after  = OrbiJob 5.0: a profession search is judged on the title/city; alternatives keep their qualifying words together
// and reports the result count, how many results have the term or another name in the TITLE (a job that only mentions the word in its
// description is the main source of irrelevant results), and how many exist only thanks to the other names (cross-language finds).
// `--samples` also prints up to 6 titles that `before` returned and `after` drops, and 6 that only `after` finds, to be judged by eye.
import { readFileSync } from 'node:fs';

const URL_ = 'https://rpmlfxwebnlxnwadyvle.supabase.co/rest/v1/jobs';
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY ?? JSON.parse(readFileSync(new URL('../app/dart_defines.web.json', import.meta.url), 'utf8')).SUPABASE_PUBLISHABLE_KEY;
const queries = JSON.parse(readFileSync(new URL('./search-benchmark.queries.json', import.meta.url), 'utf8'));
const table = JSON.parse(readFileSync(new URL('./search-benchmark.alternatives.json', import.meta.url), 'utf8'));
const label = process.argv[2] && !process.argv[2].startsWith('--') ? process.argv[2] : '';
const samples = process.argv.includes('--samples');

const sanitize = (s) => s.replace(/[^\p{L}\p{N}\s+#-]/gu, ' ').replace(/\s+/g, ' ').trim();
const alt = (a) => (a.length === 1 ? `title.ilike.*${a[0]}*` : `and(${a.map((p) => `title.ilike.*${p}*`).join(',')})`);
const fetchRows = async (or, { head = true, limit = 0 } = {}) => {
  const u = new URL(URL_);
  u.searchParams.set('select', head ? 'id,job_sources!inner(id)' : 'id,title,job_sources!inner(id)');
  u.searchParams.set('status', 'eq.open');
  u.searchParams.set('job_sources.can_redistribute', 'eq.true');
  u.searchParams.set('last_checked_at', `gte.${new Date(Date.now() - 72 * 3600e3).toISOString()}`);
  u.searchParams.set('or', `(${or})`);
  const r = await fetch(u, { headers: { apikey: KEY, Prefer: 'count=exact', Range: `0-${head ? 0 : limit - 1}` } });
  if (!r.ok) throw new Error(`${r.status} ${await r.text()}`);
  const total = Number((r.headers.get('content-range') ?? '*/0').split('/')[1]);
  return head ? total : { total, rows: await r.json() };
};
const count = (or) => fetchRows(or);
const pause = () => new Promise((r) => setTimeout(r, 150));

const rows = [];
for (const q of queries) {
  const term = sanitize(q);
  const before = (table[q]?.before ?? []).map(alt);
  const after = (table[q]?.after ?? []).map(alt);
  const own = [`title.ilike.*${term}*`, `city.ilike.*${term}*`];
  const bAll = await count([`search.wfts(simple).${term}`, `title.ilike.*${term}*`, `city.ilike.*${term}*`, ...before].join(','));
  const aAll = await count([...(after.length ? [] : [`search.wfts(simple).${term}`]), ...own, ...after].join(','));
  const bTitle = await count([`title.ilike.*${term}*`, ...before].join(','));
  const viaOther = after.length ? Math.max(0, (await count([`title.ilike.*${term}*`, ...after].join(','))) - (await count(`title.ilike.*${term}*`))) : 0;
  rows.push({ q, before: bAll, beforeDescOnly: bAll - bTitle, after: aAll, viaOther, alts: table[q]?.after?.length ?? 0 });
  if (samples) {
    const b = await fetchRows([`search.wfts(simple).${term}`, ...own, ...before].join(','), { head: false, limit: 100 });
    const a = await fetchRows([...(after.length ? [] : [`search.wfts(simple).${term}`]), ...own, ...after].join(','), { head: false, limit: 100 });
    const ids = (x) => new Set(x.rows.map((r) => r.id));
    const lost = b.rows.filter((r) => !ids(a).has(r.id)).slice(0, 6).map((r) => r.title);
    const gained = a.rows.filter((r) => !ids(b).has(r.id)).slice(0, 6).map((r) => r.title);
    rows[rows.length - 1].lost = lost;
    rows[rows.length - 1].gained = gained;
  }
  await pause();
}
console.log(`# ${label} (${new Date().toISOString()})`);
console.log('query | 4.0 results | 4.0 description-only | 5.0 results | 5.0 found only via other names | alternatives');
for (const r of rows) console.log(`${r.q} | ${r.before} | ${r.beforeDescOnly} | ${r.after} | ${r.viaOther} | ${r.alts}`);
const sum = (k) => rows.reduce((n, r) => n + r[k], 0);
console.log(`TOTAL | ${sum('before')} | ${sum('beforeDescOnly')} | ${sum('after')} | ${sum('viaOther')} | -`);
if (samples) {
  for (const r of rows) {
    if (r.lost?.length) console.log(`\n[${r.q}] dropped by 5.0: ${r.lost.join(' / ')}`);
    if (r.gained?.length) console.log(`[${r.q}] only in 5.0: ${r.gained.join(' / ')}`);
  }
}
