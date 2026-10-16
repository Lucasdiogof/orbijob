// One-off helper that captured worker/test/fixtures/ecyl.sample.json from the live ECYL open-data feed (2026-10-16): 12 real offers of different kinds (an
// office offer with an e-mail and a telephone in the text, an offer through the press, a EURES offer abroad, an offer on the public host, one without a locality).
// The e-mail addresses and telephone numbers in the sampled texts are public contact points of the offices; the tests check that the normalizer masks them.
import { writeFileSync } from 'node:fs';

const res = await fetch('https://datosabiertos.jcyl.es/web/jcyl/risp/es/empleo/ofertas-empleo/1284354353012.json', { headers: { accept: 'application/json', 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)' } });
const all = await res.json();
const txt = (r) => (r.descripcion ?? '').replace(/<[^>]+>/g, ' ');
const pick = (pred, n = 1) => all.filter(pred).slice(0, n);
const chosen = [
  ...pick((r) => r.fuente_contenido === 'ECYL' && /@/.test(txt(r)) && /[6-9]\d{8}/.test(txt(r)), 2),
  ...pick((r) => r.fuente_contenido === 'ECYL' && /ENFERM/i.test(r.titulo), 1),
  ...pick((r) => r.fuente_contenido === 'ECYL' && /CONDUCTOR|CAMION/i.test(r.titulo), 1),
  ...pick((r) => r.fuente_contenido === 'ECYL' && /ELECTRIC/i.test(r.titulo), 1),
  ...pick((r) => r.fuente_contenido === 'Internet / Prensa', 1),
  ...pick((r) => r.fuente_contenido === 'Red EURES' && r.provincia === 'Otra', 2),
  ...pick((r) => r.fuente_contenido === 'Organismo oficial', 1),
  ...pick((r) => /^https:\/\/empleo\.jcyl\.es\//.test(r.enlace_al_contenido ?? ''), 1),
  ...pick((r) => !r.localidad_asset0 && r.provincia !== 'Otra', 1),
];
const seen = new Set();
const out = chosen.filter((r) => (seen.has(r.identificador) ? false : (seen.add(r.identificador), true)));
writeFileSync(new URL('../test/fixtures/ecyl.sample.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(out.length, out.map((r) => `${r.identificador}|${r.titulo.slice(0, 40)}|${r.provincia}|${r.localidad_asset0}|${r.fuente_contenido}|${r.fecha_publicacion}|${new URL(r.enlace_al_contenido).host}`).join('\n'));
