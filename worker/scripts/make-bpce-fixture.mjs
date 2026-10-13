// One-off helper that captured worker/test/fixtures/bpce.sanitized.json from the live Opendatasoft portal of Groupe BPCE (2026-10-13): 12 real offers (France and
// International, upper-case cities, a duplicated reference), long texts trimmed, the recruiter's name and e-mail removed, e-mail addresses and telephone numbers scrubbed.
import { writeFileSync } from 'node:fs';

const UA = { 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)', accept: 'application/json' };
const base = 'https://bpce.opendatasoft.com/api/explore/v2.1/catalog/datasets/groupe-bpce-offres-emploi/records';
const get = async (q) => (await (await fetch(`${base}?${q}`, { headers: UA })).json()).results;
const scrub = (t) => String(t ?? '').replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, 'contact@example.com').replace(/(?<!\d)(?:\+33|0)[\d .]{9,14}(?!\d)/g, '00 00 00 00 00');
const pick = [
  ...(await get('limit=5&where=country%3D%27France%27%20and%20jobindustry%3D%27Informatique%27&order_by=referencenumber')),
  ...(await get('limit=3&where=country%3D%27France%27%20and%20jobtype%3D%27Stage%27&order_by=referencenumber')),
  ...(await get('limit=3&where=country%3D%27International%27&order_by=referencenumber')),
  ...(await get('limit=2&where=country%20is%20null&order_by=referencenumber')),
];
const out = pick.map((j) => {
  j.description = scrub(j.description).slice(0, 700);
  j.nom_recruteur_principal = null;
  j.email_recruteur_principal = null;
  return j;
});
writeFileSync(new URL('../test/fixtures/bpce.sanitized.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(out.length, out.map((j) => `${j.country}|${j.state}|${j.city}|${j.jobtype}|${j.organization}|${j.url.split('/').pop().slice(0, 40)}`).join('\n'));
