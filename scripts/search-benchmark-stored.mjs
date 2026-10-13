#!/usr/bin/env node
// Same 36 queries and the same 5.0 matching rule as scripts/search-benchmark.mjs, but counted INSIDE the database (read-only, through the linked
// Supabase CLI) over everything stored and verified in the last 72 h, so sources that are imported but not yet published show up separately.
// The app sees only published sources; this is the projection of what it will find once the pending ones are published.
//   node scripts/search-benchmark-stored.mjs [label] > docs/evidence/search-coverage-<date>.md
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const queries = JSON.parse(readFileSync(new URL('./search-benchmark.queries.json', import.meta.url), 'utf8'));
const table = JSON.parse(readFileSync(new URL('./search-benchmark.alternatives.json', import.meta.url), 'utf8'));
const label = process.argv[2] ?? '';
const sanitize = (s) => s.replace(/[^\p{L}\p{N}\s+#-]/gu, ' ').replace(/\s+/g, ' ').trim();
const lit = (s) => `'${s.replace(/'/g, "''")}'`;
const like = (col, term) => `${col} ilike ${lit(`%${term.replace(/[%_\\]/g, '\\$&')}%`)}`;
const alt = (a) => (a.length === 1 ? like('j.title', a[0]) : `(${a.map((p) => like('j.title', p)).join(' and ')})`);

const parts = queries.map((q, i) => {
  const term = sanitize(q);
  const after = (table[q]?.after ?? []).map(alt);
  const own = [like('j.title', term), like('j.city', term)];
  const conds = [...(after.length ? [] : [`j.search @@ websearch_to_tsquery('simple', ${lit(term)})`]), ...own, ...after];
  return `select ${i} as qi, j.source_id, (s.can_redistribute) as published, count(*) as n from public.jobs j join public.job_sources s on s.id = j.source_id
    where j.status = 'open' and j.last_checked_at > now() - interval '72 hours' and (${conds.join(' or ')}) group by 1, 2, 3`;
});
const sql = parts.join('\nunion all\n');
const dir = mkdtempSync(join(tmpdir(), 'orbijob-bench-'));
const file = join(dir, 'q.sql');
writeFileSync(file, sql);
const raw = execFileSync('npx', ['supabase', 'db', 'query', '--linked', '-o', 'json', '-f', file], { cwd: new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'), encoding: 'utf8', shell: process.platform === 'win32', maxBuffer: 64 * 1024 * 1024 });
const rows = JSON.parse(raw.slice(raw.indexOf('{'))).rows;

const by = new Map();
for (const r of rows) {
  const k = Number(r.qi);
  if (!by.has(k)) by.set(k, { pub: 0, pend: 0, src: new Map() });
  const e = by.get(k);
  const n = Number(r.n);
  if (r.published) e.pub += n; else e.pend += n;
  e.src.set(r.source_id, (e.src.get(r.source_id) ?? 0) + n);
}
console.log(`# Search coverage over the stored catalogue ${label} (${new Date().toISOString()})`);
console.log('');
console.log('| query | shown in the app today | stored, not yet published | by source |');
console.log('|---|---:|---:|---|');
queries.forEach((q, i) => {
  const e = by.get(i) ?? { pub: 0, pend: 0, src: new Map() };
  const src = [...e.src].sort((a, b) => b[1] - a[1]).map(([s, n]) => `${s} ${n}`).join(', ');
  console.log(`| ${q} | ${e.pub} | ${e.pend} | ${src || '—'} |`);
});
