// One-off helper that captured worker/test/fixtures/teachingvacancies.sanitized.json from the live open API (2026-10-13).
// Keeps a spread of real listings (pages 1, 20 and 60), trims long texts and scrubs e-mail addresses and phone numbers.
import { writeFileSync } from 'node:fs';

const UA = { 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)', accept: 'application/json' };
const scrub = (t) => String(t ?? '').replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, 'contact@example.com').replace(/(?<!\d)(?:\+44|0)[\d ]{9,12}(?!\d)/g, '0000 000 0000');
const out = [];
for (const page of [1, 20, 60]) {
  const r = await fetch(`https://teaching-vacancies.service.gov.uk/api/v1/jobs.json?page=${page}`, { headers: UA });
  const b = await r.json();
  const seen = new Set();
  for (const j of b.data) {
    if (seen.has(j.occupationalCategory) || out.length >= 14) continue;
    seen.add(j.occupationalCategory);
    j.description = scrub(j.description).slice(0, 500);
    if (j.jobBenefits) j.jobBenefits = scrub(j.jobBenefits).slice(0, 200);
    out.push(j);
  }
  await new Promise((s) => setTimeout(s, 2000));
}
writeFileSync(new URL('../test/fixtures/teachingvacancies.sanitized.json', import.meta.url), JSON.stringify({ meta: { totalPages: 68, count: 6718 }, data: out }, null, 1));
console.log(out.length, out.map((j) => `${j.occupationalCategory}|${j.validThrough}|${JSON.stringify(j.baseSalary?.value?.value)}`).join('\n'));
