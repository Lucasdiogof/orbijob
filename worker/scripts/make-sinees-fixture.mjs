// One-off helper that captured the SINE-ES fixtures from the live open-data catalogue of the Espírito Santo government (2026-10-17): the CKAN package (trimmed to
// three offices) and a few real rows of each office's CSV, including the awkward ones (a field with line breaks, a filler schooling field, a blank quantity, an old
// update date). The data is open (Creative Commons Attribution) and holds no personal data; nothing is scrubbed.
import { writeFileSync } from 'node:fs';

const UA = 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)';
const pkg = await (await fetch('https://dados.es.gov.br/api/3/action/package_show?id=c43d6653-634a-4e6e-bd66-c9ca3f6ee106', { headers: { 'user-agent': UA } })).json();
const want = ['VAGAS_CARIACICA', 'VAGAS_ARACRUZ', 'VAGAS_GUARAPARI'];
const resources = pkg.result.resources.filter((r) => want.includes(r.name));

function parse(csv) {
  const rows = []; let row = [], cur = '', q = false;
  for (let i = 0; i < csv.length; i++) {
    const c = csv[i];
    if (q) { if (c === '"') { if (csv[i + 1] === '"') { cur += '"'; i++; } else q = false; } else cur += c; }
    else if (c === '"') q = true;
    else if (c === ',') { row.push(cur); cur = ''; }
    else if (c === '\n') { row.push(cur.replace(/\r$/, '')); rows.push(row); row = []; cur = ''; }
    else cur += c;
  }
  if (cur || row.length) { row.push(cur); rows.push(row); }
  return rows.filter((r) => r.length > 3);
}
const esc = (f) => (/[",\n]/.test(f) ? `"${f.replace(/"/g, '""')}"` : f);
const all = {};
for (const r of pkg.result.resources) {
  const t = (await (await fetch(r.url, { headers: { 'user-agent': UA } })).text()).replace(/^﻿/, '');
  all[r.name] = parse(t);
}
const header = all.VAGAS_CARIACICA[0];
const pick = (name, n) => all[name].slice(1, 1 + n);
const special = {
  multiline: Object.values(all).flatMap((rows) => rows.slice(1)).find((r) => r.some((f) => f.includes('\n'))),
  filler: Object.values(all).flatMap((rows) => rows.slice(1)).find((r) => /^\*+$/.test(r[4].trim())),
  blankQty: Object.values(all).flatMap((rows) => rows.slice(1)).find((r) => r[5].trim() === ''),
  old: Object.values(all).flatMap((rows) => rows.slice(1)).find((r) => r[6].trim() === '09/15/2026'),
};
const files = {
  VAGAS_CARIACICA: [...pick('VAGAS_CARIACICA', 4), special.multiline, special.filler].filter(Boolean),
  VAGAS_ARACRUZ: [...pick('VAGAS_ARACRUZ', 3), special.blankQty, special.old].filter(Boolean),
  VAGAS_GUARAPARI: pick('VAGAS_GUARAPARI', 3),
};
for (const [name, rows] of Object.entries(files)) {
  writeFileSync(new URL(`../test/fixtures/sinees.${name.toLowerCase()}.csv`, import.meta.url), '﻿' + [header, ...rows].map((r) => r.map(esc).join(',')).join('\r\n') + '\r\n');
}
const trimmed = { ...pkg, result: { id: pkg.result.id, title: pkg.result.title, license_id: pkg.result.license_id, resources: resources.map((r) => ({ id: r.id, name: r.name, format: r.format, url: r.url })) } };
writeFileSync(new URL('../test/fixtures/sinees.package.json', import.meta.url), JSON.stringify(trimmed, null, 1));
console.log(Object.fromEntries(Object.entries(files).map(([k, v]) => [k, v.length])), Object.fromEntries(Object.entries(special).map(([k, v]) => [k, v ? v[1] : null])));
