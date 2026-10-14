// One-off helper that captured worker/test/fixtures/mpsvcz.sanitized.json (+ mpsvcz.codes.json) from the live Czech open data (read 2026-10-14):
// real vacancies of different trades, place types and salary kinds. The contact people, e-mail addresses and phone numbers of the employers are
// REPLACED by placeholders (the connector never reads them; the fixture keeps their shape to prove it), long texts are trimmed.
import { writeFileSync } from 'node:fs';

const UA = { 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; fixture capture)' };
const base = 'https://data.mpsv.cz/od/soubory';
const all = (await (await fetch(`${base}/volna-mista/volna-mista.json`, { headers: UA })).json()).polozky;
const id = (v) => v?.id ?? '';
const scrub = (t) => String(t ?? '').replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, 'kontakt@example.cz').replace(/(\+?\d[\d ]{7,}\d)/g, '000 000 000').slice(0, 700);
const want = [
  (r) => /sváře/i.test(r.pozadovanaProfese?.cs) && id(r.typMzdy) === 'TypMzdy/mesic',
  (r) => /kuchař/i.test(r.pozadovanaProfese?.cs) && id(r.zverejnovat) === 'ZverejnovatVpm/ano',
  (r) => /číšn|servír/i.test(r.pozadovanaProfese?.cs) && id(r.typMzdy) === 'TypMzdy/hod' && r.mesicniMzdaOd < 2000,
  (r) => /řidič/i.test(r.pozadovanaProfese?.cs),
  (r) => id(r.mistoVykonuPrace?.typMistaVykonuPrace) === 'TypMistaVykonuPrace/okres',
  (r) => id(r.mistoVykonuPrace?.typMistaVykonuPrace) === 'TypMistaVykonuPrace/obec' && r.upresnujiciInformace?.cs,
  (r) => id(r.mistoVykonuPrace?.typMistaVykonuPrace) === 'TypMistaVykonuPrace/adrvolna',
  (r) => id(r.mistoVykonuPrace?.typMistaVykonuPrace) === 'TypMistaVykonuPrace/neurceno',
  (r) => id(r.typMzdy) === 'TypMzdy/hod' && r.mesicniMzdaOd > 5000, // the source mixes monthly figures into hourly entries
  (r) => id(r.zverejnovat) === 'ZverejnovatVpm/anoeu',
  (r) => id(r.zverejnovat) === 'ZverejnovatVpm/anosp',
  (r) => !!r.expirace,
  (r) => /uklíz/i.test(r.pozadovanaProfese?.cs) && !r.upresnujiciInformace?.cs,
  (r) => (r.mistoVykonuPrace?.pracoviste?.length ?? 0) > 1,
];
const recent = all.filter((r) => Date.parse(r.datumZmeny) > Date.now() - 10 * 86400e3);
const picked = [];
for (const w of want) {
  const r = recent.find((x) => w(x) && !picked.includes(x)) ?? all.find((x) => w(x) && !picked.includes(x));
  if (r) picked.push(r);
}
for (const r of picked) {
  if (r.upresnujiciInformace?.cs) r.upresnujiciInformace.cs = scrub(r.upresnujiciInformace.cs);
  if (r.prvniKontaktSeZamestnavatelem) r.prvniKontaktSeZamestnavatelem = { komuSeHlasit: { email: 'kontakt@example.cz', telefon: '000 000 000', jmeno: 'Jméno', prijmeni: 'Příjmení' }, kdeSeHlasit: { email: null, telefon: '000 000 000' } };
  for (const w of r.mistoVykonuPrace?.pracoviste ?? []) { w.email = w.email ? 'kontakt@example.cz' : null; w.telefon = w.telefon ? '000 000 000' : null; }
}
const need = new Set(picked.flatMap((r) => [id(r.mistoVykonuPrace?.obec), ...(r.mistoVykonuPrace?.pracoviste ?? []).map((w) => id(w.adresa?.obec))]).filter(Boolean));
const list = async (n, keep) => { const d = (await (await fetch(`${base}/ciselniky/${n}.json`, { headers: UA })).json()).polozky; return { polozky: keep ? d.filter(keep) : d }; };
writeFileSync(new URL('../test/fixtures/mpsvcz.sanitized.json', import.meta.url), JSON.stringify({ polozky: picked }, null, 1));
writeFileSync(new URL('../test/fixtures/mpsvcz.codes.json', import.meta.url), JSON.stringify({
  obce: await list('obce', (o) => need.has(o.id)), smennosti: await list('smennosti'), 'pracovnepravni-vztahy': await list('pracovnepravni-vztahy'),
}, null, 1));
console.log(picked.map((r) => `${r.portalId}|${r.pozadovanaProfese?.cs}|${id(r.zverejnovat)}|${id(r.mistoVykonuPrace?.typMistaVykonuPrace)}|${id(r.typMzdy)} ${r.mesicniMzdaOd}-${r.mesicniMzdaDo}|exp ${r.expirace}`).join('\n'));
