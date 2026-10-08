// Generates data/coverage-matrix.csv and docs/COVERAGE_MATRIX.md from data/sources.catalog.json.
// Usage: node scripts/build-coverage.mjs [--check]
import { readFileSync, writeFileSync } from 'node:fs';

const root = new URL('../', import.meta.url);
const cat = JSON.parse(readFileSync(new URL('data/sources.catalog.json', root), 'utf8'));
const occ = JSON.parse(readFileSync(new URL('data/occupations.seed.json', root), 'utf8')).occupations;
const STATUSES = ['READY', 'CONDITIONAL', 'EXTERNAL_ONLY', 'BLOCKED', 'RESEARCH'];

for (const s of cat.sources) if (!STATUSES.includes(s.status)) throw new Error(`bad status ${s.id}`);
if (cat.sources.some((s) => s.status === 'READY')) throw new Error('READY requires live validation evidence');

// Acceptance cases from the product owner (country x occupation).
const CASES = [
  ['US', 'software-dev', 'Flutter Developer'], ['DE', 'physio-pelvic', 'Fisioterapeuta pélvica'],
  ['PT', 'bricklayer', 'Pedreiro'], ['AU', 'house-painter', 'Pintor residencial'],
  ['CA', 'nurse', 'Enfermeiro'], ['ZA', 'electrician', 'Eletricista'],
  ['SG', 'teacher', 'Professor'], ['AE', 'driver', 'Motorista'],
];
const covers = (s, c) => s.countries.includes('*') || s.countries.includes(c);
// A source can only serve a search path if it is not EXTERNAL_ONLY/BLOCKED and supports cross-company search.
const GLOBAL_ATS = new Set(['lever', 'greenhouse', 'ashby']);

const rows = [['country', 'source_id', 'status', 'evidence', 'integration_scope']];
const countries = new Set();
for (const s of cat.sources) for (const c of s.countries) if (c !== '*') countries.add(c);
for (const n of cat.candidates_not_investigated) n.countries.forEach((c) => countries.add(c));
for (const c of [...countries].sort()) {
  for (const s of cat.sources) if (covers(s, c) && s.id !== 'esco') rows.push([c, s.id, s.status, s.evidence, GLOBAL_ATS.has(s.id) ? 'per-company only' : 'country/global']);
  cat.candidates_not_investigated.forEach((n) => n.names.forEach((name, i) => {
    if (n.countries[i] === c) rows.push([c, name.toLowerCase().replace(/[^a-z0-9]+/g, '-'), 'RESEARCH', 'none', 'not investigated']);
  }));
}
writeFileSync(new URL('data/coverage-matrix.csv', root), rows.map((r) => r.join(',')).join('\n') + '\n');

let md = '# OrbiJob — Matriz de cobertura (gerada)\n\n> Gerada por `node scripts/build-coverage.mjs` a partir de `data/sources.catalog.json`. **Não editar à mão.**\n> Nenhuma fonte está `READY`: o ambiente da Fase 0 não alcançou nenhum host de API de vagas, então nenhuma validação ao vivo foi possível.\n\n';
md += '## Casos de aceite (país × profissão)\n\n| País | Profissão | ISCO-08 | Fontes candidatas (status) | Fonte integrada hoje | Alternativa externa |\n|---|---|---|---|---|---|\n';
const ext = { US: 'us.indeed.com', DE: 'de.indeed.com', PT: 'pt.indeed.com', AU: 'au.indeed.com', CA: 'ca.indeed.com', ZA: 'za.indeed.com', SG: 'sg.indeed.com', AE: 'ae.indeed.com' };
for (const [c, id, label] of CASES) {
  const o = occ.find((x) => x.id === id);
  const cand = cat.sources.filter((s) => covers(s, c) && s.id !== 'esco' && s.status !== 'EXTERNAL_ONLY').map((s) => `${s.id} (${s.status}${GLOBAL_ATS.has(s.id) ? ', por empresa' : ''})`);
  md += `| ${c} | ${label} | ${o.isco08} | ${cand.join('; ') || '—'} | **nenhuma** | ${ext[c]}, LinkedIn Jobs |\n`;
}
md += '\n## Fontes por país\n\nVeja `data/coverage-matrix.csv` (' + (rows.length - 1) + ' linhas país×fonte).\n';
writeFileSync(new URL('docs/COVERAGE_MATRIX.md', root), md);
console.log(`ok: ${rows.length - 1} rows, ${countries.size} countries`);

// Per-source table (generated) used by docs/GLOBAL_SOURCES.md
let t = '# OrbiJob — Catálogo de fontes (gerado)\n\n> Gerado por `node scripts/build-coverage.mjs` de `data/sources.catalog.json`. Não editar à mão.\n> `Evidência`: doc = lido em texto primário; secondary = só resumo de terceiros; prior = conhecimento prévio não verificado.\n\n';
t += '| Fonte | Região | Países | Tipo | Status | Evidência | Autenticação | Limites | Termos / redistribuição | Docs |\n|---|---|---|---|---|---|---|---|---|---|\n';
for (const s of cat.sources) {
  const cs = s.countries.includes('*') ? 'global' : s.countries.join(' ');
  t += `| **${s.name}** | ${s.region} | ${cs} | ${s.kind} | \`${s.status}\` | ${s.evidence} | ${s.auth} | ${s.limits} | ${s.terms} | ${s.docs} |\n`;
}
t += '\n## Candidatos ainda não investigados (todos `RESEARCH`, alternativa = busca externa)\n\n| Região | Portais (país) |\n|---|---|\n';
for (const n of cat.candidates_not_investigated) t += `| ${n.region} | ${n.names.map((x, i) => `${x} (${n.countries[i]})`).join(', ')} |\n`;
writeFileSync(new URL('docs/SOURCES_TABLE.md', root), t);
