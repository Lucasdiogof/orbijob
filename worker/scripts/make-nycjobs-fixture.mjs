// One-off helper that captured worker/test/fixtures/nycjobs.sanitized.json from the live NYC Open Data API (2026-10-13): real postings (8 External
// of different categories and salary frequencies, 1 Internal), long texts trimmed and e-mail addresses / phone numbers scrubbed.
import { writeFileSync } from 'node:fs';

const UA = { 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)', accept: 'application/json' };
const scrub = (t) => String(t ?? '').replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, 'contact@example.com').replace(/\(?\b\d{3}\)?[-. ]\d{3}[-. ]\d{4}\b/g, '000-000-0000');
const cut = (t, n) => scrub(t).slice(0, n);
const base = 'https://data.cityofnewyork.us/resource/kpav-sd4t.json';
const ext = await (await fetch(`${base}?$where=${encodeURIComponent("posting_type='External'")}&$order=job_id&$limit=400`, { headers: UA })).json();
const int = await (await fetch(`${base}?$where=${encodeURIComponent("posting_type='Internal'")}&$limit=1`, { headers: UA })).json();
const seen = new Set();
const out = [];
for (const j of ext) {
  const k = `${j.job_category}|${j.salary_frequency}`;
  if (seen.has(k) || out.length >= 8) continue;
  seen.add(k);
  out.push(j);
}
out.push(...int);
for (const j of out) {
  for (const f of ['job_description', 'minimum_qual_requirements', 'preferred_skills', 'additional_information', 'to_apply', 'recruitment_contact']) j[f] = cut(j[f], 400);
}
writeFileSync(new URL('../test/fixtures/nycjobs.sanitized.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(out.map((j) => `${j.posting_type}|${j.job_category}|${j.salary_frequency}|${j.salary_range_from}-${j.salary_range_to}|${j.post_until}|${j.agency}`).join('\n'));
