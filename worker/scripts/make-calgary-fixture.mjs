// One-off helper that captured worker/test/fixtures/calgary.sample.json from the live City of Calgary open-data dataset (2026-10-16): one listing per area.
// Open Government Licence - City of Calgary; the listings hold no personal data, nothing is scrubbed.
import { writeFileSync } from 'node:fs';

const res = await fetch('https://data.calgary.ca/resource/5fsi-n9xm.json?$limit=500', { headers: { accept: 'application/json', 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)' } });
const all = await res.json();
const byArea = new Map();
for (const o of all) if (!byArea.has(o.area)) byArea.set(o.area, o);
const out = [...byArea.values()].slice(0, 10);
writeFileSync(new URL('../test/fixtures/calgary.sample.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(all.length, out.map((o) => `${o.job_opening_id}|${o.title}|${o.area}|${o.closing_date}`).join('\n'));
