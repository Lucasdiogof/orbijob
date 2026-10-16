// One-off helper that captured worker/test/fixtures/feinaactiva.sample.xml from the live Feina Activa open-data feed (2026-10-16): 14 real offers chosen to
// cover the cases the normalizer handles (different sectors, the SICAS origin, an offer abroad, a disability-specific offer, no city, a commercial contract,
// no salary, part-time). The employer of the two offers whose author typed a person's name is replaced by a made-up name of the same shape, so the fixture
// holds no real person's name; everything else is the feed's own text.
import { writeFileSync } from 'node:fs';

const res = await fetch('https://feinaactiva.gencat.cat/api/offers/offers-xml', { headers: { accept: 'application/xml', 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)' } });
const xml = await res.text();
const ads = [...xml.matchAll(/<ad>[\s\S]*?<\/ad>/g)].map((m) => m[0]);
const get = (a, t) => (new RegExp(`<${t}>([\\s\\S]*?)</${t}>`).exec(a) ?? [, ''])[1];
const pick = (pred, n = 1) => ads.filter(pred).slice(0, n);
const chosen = [
  ...pick((a) => /CAMBRER|COCINER|CUINER/i.test(get(a, 'title')) && get(a, 'salaryMin') && get(a, 'origin') === 'FA', 1),
  ...pick((a) => /ENFERMER|INFERMER/i.test(get(a, 'title')), 1),
  ...pick((a) => /CONDUCTOR|CAMIONER|CHÓFER|XOFER/i.test(get(a, 'title')), 1),
  ...pick((a) => /ELECTRICISTA|ELECTRIC/i.test(get(a, 'title')), 1),
  ...pick((a) => /SOLDADOR/i.test(get(a, 'title')), 1),
  ...pick((a) => /FISIOTERAP/i.test(get(a, 'title')), 1),
  ...pick((a) => get(a, 'origin') === 'SICAS', 1),
  ...pick((a) => get(a, 'region') === 'PAÏSOS BAIXOS', 1),
  ...pick((a) => get(a, 'disability') === 'Sí' || get(a, 'disability') === 'Si', 1),
  ...pick((a) => !get(a, 'city'), 1),
  ...pick((a) => /mercantil/i.test(get(a, 'contract')), 1),
  ...pick((a) => /^(ALBERT VERDAGUER)$/.test(get(a, 'company').trim()), 1),
  ...pick((a) => /Pedro Piera/.test(get(a, 'company')), 1),
];
const seen = new Set();
const out = chosen.filter((a) => (seen.has(get(a, 'id')) ? false : (seen.add(get(a, 'id')), true)))
  .map((a) => a.replace(/<company>ALBERT VERDAGUER<\/company>/, '<company>JOAN GARCIA PUIG</company>').replace(/<company>Pedro Piera López - Alpha Disseny<\/company>/, '<company>Josep Pons Mas - Estudi Pons</company>'));
writeFileSync(new URL('../test/fixtures/feinaactiva.sample.xml', import.meta.url), `<ofertes><feinaactiva>${out.join('')}</feinaactiva></ofertes>`);
console.log(out.length, out.map((a) => `${get(a, 'id')}|${get(a, 'title').slice(0, 40)}|${get(a, 'company').slice(0, 25)}|${get(a, 'city')}|${get(a, 'region')}|${get(a, 'origin')}|${get(a, 'date')}`).join('\n'));
