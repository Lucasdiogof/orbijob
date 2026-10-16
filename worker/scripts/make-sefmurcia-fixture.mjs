// One-off helper that captured worker/test/fixtures/sefmurcia.sample.json from the live SEF Murcia open-data feed (2026-10-16): 10 real offers of different
// sectors. The feed is public data of the Región de Murcia (reuse authorised by its legal notice); nothing is scrubbed because the normalizer drops the
// registration section and masks personal addresses, and the tests check exactly that.
import { writeFileSync } from 'node:fs';

const res = await fetch('https://sefapps.carm.es/sefApps/rest/ofertas/ofertas', { headers: { accept: 'application/json', 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)' } });
const all = await res.json();
const bySector = new Map();
for (const o of all) {
  const k = o.sectorProfesional?.denominacion ?? '';
  if (!bySector.has(k)) bySector.set(k, o);
}
const want = ['TRANSPORTES Y COMUNICACIONES', 'EDIFICACIÓN Y OBRAS PÚBLICAS', 'SANIDAD', 'TURISMO Y HOSTELERÍA', 'DOCENCIA E INVESTIGACIÓN', 'AGRARIO', 'MONTAJE E INSTALACIÓN', 'ADMINISTRACIÓN Y OFICINAS', 'COMERCIO', 'INDUSTRIA PESADA Y CONSTRUCCIONES METÁLICAS'];
const out = want.map((k) => bySector.get(k)).filter(Boolean);
writeFileSync(new URL('../test/fixtures/sefmurcia.sample.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(out.length, out.map((o) => `${o.numeroOferta}|${o.descripcion}|${o.municipio?.municipio}|${o.fechaDeInicio}-${o.fechaDeFin}`).join('\n'));
