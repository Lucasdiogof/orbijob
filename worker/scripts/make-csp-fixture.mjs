// One-off helper that captured worker/test/fixtures/csp.sample.csv from the weekly file of "Les offres diffusées sur Choisir le Service Public"
// (data.gouv.fr, Licence Ouverte 2.0; file offres-datagouv-20260920.csv read 2026-10-14): real offers of different branches, bodies and trades,
// plus the header. E-mail addresses and telephone numbers are REPLACED by placeholders; long texts are trimmed.
//   node scripts/make-csp-fixture.mjs <offres-datagouv-*.csv>
import { readFileSync, writeFileSync } from 'node:fs';

const t = readFileSync(process.argv[2], 'utf8');
const rows = [];
let row = [], f = '', q = false;
for (let i = 0; i < t.length; i++) {
  const c = t[i];
  if (q) { if (c === '"') { if (t[i + 1] === '"') { f += '"'; i++; } else q = false; } else f += c; }
  else if (c === '"' && f === '') q = true;
  else if (c === ';') { row.push(f); f = ''; }
  else if (c === '\n') { row.push(f.replace(/\r$/, '')); rows.push(row); row = []; f = ''; }
  else f += c;
}
const h = rows[0];
const I = (n) => h.indexOf(n);
const open = rows.slice(1).filter((r) => /\/09\/2026$/.test(r[I('Date de première publication')]));
const want = [
  (r) => r[0] === 'Communes' && / - Mairie de /i.test(r[I('Intitulé du poste')]),
  (r) => r[0] === 'Communes' && / - Pantin$/.test(r[I('Intitulé du poste')]),
  (r) => r[I('Versant')] === 'Fonction Publique Hospitalière' && /infirmi/i.test(r[I('Métier')]),
  (r) => /Enseignant/.test(r[I('Métier')]),
  (r) => r[I('Employeur')].includes('\n'),
  (r) => /recrute/i.test(r[I('Employeur')]),
  (r) => r[I('Compétences attendues')].length > 50,
  (r) => r[I('Documents à transmettre')].length > 20,
  (r) => /CEDEX/i.test(r[I("Lieu d'affectation")]),
  (r) => r[I('Nature de contrat')] === 'CDI',
  (r) => /Cuisini/.test(r[I('Métier')]),
  (r) => / /.test(r[1]),
  (r) => r[I('Versant')] === 'Fonction Publique de l\'Etat' && !r[I("Lieu d'affectation")],
];
const picked = [];
for (const w of want) { const r = open.find((x) => w(x) && !picked.includes(x)); if (r) picked.push(r); }
const scrub = (s) => s.replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, 'contact@example.fr').replace(/(?:\+33|\b0)[1-9](?:[\s.-]?\d{2}){4}\b/g, '01 00 00 00 00').slice(0, 900);
const cell = (s) => (/[;"\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s);
writeFileSync(new URL('../test/fixtures/csp.sample.csv', import.meta.url), [h, ...picked.map((r) => r.map(scrub))].map((r) => r.map(cell).join(';')).join('\n') + '\n');
console.log(`picked ${picked.length}`);
