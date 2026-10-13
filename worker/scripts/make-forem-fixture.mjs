// One-off helper that captured worker/test/fixtures/forem.sanitized.json from the live Open Data Wallonie-Bruxelles portal (2026-10-13): 12 real offers of Le Forem
// (different contracts, sources, an upper-case locality, one outside Belgium when present). Only structured facts; nothing to scrub.
import { writeFileSync } from 'node:fs';

const UA = { 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)', accept: 'application/json' };
const base = 'https://www.odwb.be/api/explore/v2.1/catalog/datasets/offres-d-emploi-forem/records';
const get = async (q) => (await (await fetch(`${base}?${q}`, { headers: UA })).json()).results;
const where = encodeURIComponent('datefindiffusion >= now()');
const pick = [
  ...(await get(`limit=6&where=${where}&order_by=datedebutdiffusion%20desc`)),
  ...(await get(`limit=2&where=${where}%20and%20source%3D%27Via%20site%20Forem%27&order_by=datedebutdiffusion%20desc`)),
  ...(await get(`limit=2&where=${where}%20and%20typecontrat%3D%27Dur%C3%A9e%20d%C3%A9termin%C3%A9e%27&order_by=datedebutdiffusion%20desc`)),
  ...(await get(`limit=100&where=${where}&order_by=datedebutdiffusion%20desc&offset=300`)).filter((j) => j.lieuxtravailregion?.[0] !== 'Belgique').slice(0, 2),
];
const seen = new Set();
const out = pick.filter((j) => (seen.has(j.numerooffreforem) ? false : (seen.add(j.numerooffreforem), true)));
writeFileSync(new URL('../test/fixtures/forem.sanitized.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(out.length, out.map((j) => `${j.numerooffreforem}|${j.lieuxtravailregion?.[0]}|${j.lieuxtravaillocalite?.join('+')}|${j.typecontrat}|${j.source}|${j.datefindiffusion}`).join('\n'));
