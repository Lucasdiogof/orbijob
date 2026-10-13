#!/usr/bin/env node
// Search relevance benchmark against the real catalogue, with the PUBLIC key only (the same reads the app does).
//   node scripts/search-benchmark.mjs <synonym-groups.json> [label]
// The groups file is a JSON array of arrays of lower-case title fragments (what app/lib/features/search/domain/search_synonyms.dart compiles).
// For every query it reports: all results the app's text filter returns, how many of them have the term or another name of the profession in
// the TITLE (a job that only mentions the word in its description is the main source of irrelevant results), and the title matches that
// exist only thanks to the other names (cross-language finds). Exact counts; nothing is sampled.
import { readFileSync } from 'node:fs';

const URL_ = 'https://rpmlfxwebnlxnwadyvle.supabase.co/rest/v1/jobs';
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY ?? JSON.parse(readFileSync(new URL('../app/dart_defines.web.json', import.meta.url), 'utf8')).SUPABASE_PUBLISHABLE_KEY;
const groups = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const label = process.argv[3] ?? '';

export const QUERIES = [
  'fisioterapia pélvica', 'pelvic health physiotherapist', 'beckenbodenphysiotherapie', 'fisioterapeuta', 'physiotherapist',
  'desenvolvedor flutter', 'flutter developer', 'flutter-entwickler',
  'enfermeiro', 'nurse', 'krankenpfleger', 'sjuksköterska',
  'engenheiro civil', 'civil engineer', 'bauingenieur',
  'professor', 'teacher', 'lehrer',
  'motorista', 'truck driver', 'cozinheiro', 'chef', 'eletricista', 'electrician', 'contador', 'accountant',
  'vendedor', 'farmacêutico', 'psicólogo', 'soldador', 'recepcionista', 'advogado',
];

const norm = (s) => s.toLowerCase();
const sanitize = (s) => s.replace(/[^\p{L}\p{N}\s+#-]/gu, ' ').replace(/\s+/g, ' ').trim();
function alts(term) {
  const t = norm(term);
  const out = new Set();
  for (const g of groups) if (g.some((w) => t.includes(w))) for (const w of g) if (!t.includes(w)) out.add(w);
  return [...out];
}
async function count(or) {
  const u = new URL(URL_);
  u.searchParams.set('select', 'id,job_sources!inner(id)');
  u.searchParams.set('status', 'eq.open');
  u.searchParams.set('job_sources.can_redistribute', 'eq.true');
  u.searchParams.set('last_checked_at', `gte.${new Date(Date.now() - 72 * 3600e3).toISOString()}`);
  u.searchParams.set('or', `(${or})`);
  const r = await fetch(u, { headers: { apikey: KEY, Prefer: 'count=exact', Range: '0-0' } });
  if (!r.ok) throw new Error(`${r.status} ${await r.text()}`);
  return Number((r.headers.get('content-range') ?? '*/0').split('/')[1]);
}

const rows = [];
for (const q of QUERIES) {
  const term = sanitize(q);
  const a = alts(term);
  const all = await count([`search.wfts(simple).${term}`, `title.ilike.*${term}*`, `city.ilike.*${term}*`, ...a.map((w) => `title.ilike.*${w}*`)].join(','));
  const inTitle = await count([`title.ilike.*${term}*`, ...a.map((w) => `title.ilike.*${w}*`)].join(','));
  const onlyAlts = a.length ? await count(a.map((w) => `title.ilike.*${w}*`).join(',')) - (await count(`title.ilike.*${term}*`)) : 0;
  rows.push({ q, results: all, title: inTitle, descriptionOnly: all - inTitle, viaOtherNames: Math.max(0, onlyAlts), alts: a.length });
  await new Promise((r) => setTimeout(r, 150));
}
console.log(`# ${label}`);
console.log('query | results | title matches | description-only | found only via other names | other names');
for (const r of rows) console.log(`${r.q} | ${r.results} | ${r.title} | ${r.descriptionOnly} | ${r.viaOtherNames} | ${r.alts}`);
