// One-off helper that captured worker/test/fixtures/karrierenrw.sanitized.json from the live Open.NRW interface (2026-10-13): 10 real postings (job offers and
// apprenticeships of different authorities), long texts trimmed, contact persons and e-mail addresses / phone numbers removed.
import { writeFileSync } from 'node:fs';

const UA = { 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)', accept: 'application/json' };
const all = await (await fetch('https://api.karriere.nrw/v1.0/opennrw/stellenausschreibungen/', { headers: UA })).json();
const scrub = (t) => String(t ?? '').replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, 'kontakt@example.com').replace(/(?<!\d)(?:\+49|0)[\d /-]{8,14}(?!\d)/g, '0000 000000');
const seen = new Set();
const out = [];
const ordered = [...all.filter((j) => j.type === 'joboffer').slice(0, 400), ...all.filter((j) => j.type === 'apprenticeship')];
for (const j of ordered) {
  const k = `${j.type}|${j.behoerde}`;
  if (seen.has(k) || out.filter((o) => o.type === j.type).length >= (j.type === 'joboffer' ? 7 : 3)) continue;
  seen.add(k);
  j.stellenbeschreibung = scrub(j.stellenbeschreibung).slice(0, 700);
  j.ansprechpartner = [];
  out.push(j);
}
writeFileSync(new URL('../test/fixtures/karrierenrw.sanitized.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(out.length, out.map((j) => `${j.type}|${j.behoerde}|${j.ort}|${j.bewerbungsfrist}|${(j.besoldung_entgelt ?? []).join('+')}`).join('\n'));
