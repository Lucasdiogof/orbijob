// One-off helper that captured worker/test/fixtures/getonboard.sanitized.json from the live public API (2026-10-13).
// Trims the long text fields and scrubs e-mail addresses; everything else is the real payload.
import { writeFileSync } from 'node:fs';

const UA = { 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)', accept: 'application/json' };
const expand = encodeURIComponent('["company","location_cities"]');
const scrub = (t) => String(t ?? '').replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, 'contact@example.com');
const cut = (t, n) => scrub(t).slice(0, n);
const out = [];
const want = [['mobile-developer', 4], ['programming', 3], ['sales', 1], ['hr', 1], ['education-coaching', 1]];
for (const [cat, n] of want) {
  const r = await fetch(`https://www.getonbrd.com/api/v0/categories/${cat}/jobs?per_page=40&expand=${expand}`, { headers: UA });
  const b = await r.json();
  const seen = new Set();
  for (const j of b.data) {
    const m = j.attributes.remote_modality;
    if (seen.has(m) && out.length > 6) continue;
    seen.add(m);
    for (const k of ['description', 'projects', 'functions', 'benefits', 'desirable']) j.attributes[k] = cut(j.attributes[k], 400);
    if (j.attributes.company?.data?.attributes) {
      const c = j.attributes.company.data.attributes;
      for (const k of ['description', 'long_description', 'projects', 'benefits']) c[k] = cut(c[k], 80);
      for (const k of ['twitter', 'github', 'facebook', 'angellist']) c[k] = null;
    }
    out.push(j);
    if (out.filter((x) => x.attributes.category_name === j.attributes.category_name).length >= n) break;
  }
  await new Promise((s) => setTimeout(s, 2000));
}
writeFileSync(new URL('../test/fixtures/getonboard.sanitized.json', import.meta.url), JSON.stringify({ data: out }, null, 1));
console.log(out.length, out.map((j) => `${j.attributes.remote_modality}|${j.attributes.countries.join('+')}|${j.attributes.lang}`).join('\n'));
