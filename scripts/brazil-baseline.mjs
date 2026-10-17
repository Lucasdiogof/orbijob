// OrbiJob 14.1 read-only baseline of what the app shows for Brazil (PUBLISHABLE key, same visibility as the app). Counts and short classifications only.
//   node scripts/brazil-baseline.mjs            (key read from app/dart_defines.web.json unless SUPABASE_PUBLISHABLE_KEY is set)
import { readFileSync } from 'node:fs';

const KEY = process.env.SUPABASE_PUBLISHABLE_KEY ?? JSON.parse(readFileSync(new URL('../app/dart_defines.web.json', import.meta.url), 'utf8')).SUPABASE_PUBLISHABLE_KEY;
const BASE = 'https://rpmlfxwebnlxnwadyvle.supabase.co/rest/v1/jobs';
const since = new Date(Date.now() - 72 * 3_600_000).toISOString();
const SELECT = 'id,source_id,title,company,city,country,work_mode,geo_restrictions,original_url,description,job_sources!inner(can_redistribute)';

async function all(extra) {
  const rows = [];
  let after = '00000000-0000-0000-0000-000000000000';
  for (;;) {
    const u = new URL(BASE);
    u.searchParams.set('select', SELECT);
    u.searchParams.set('status', 'eq.open');
    u.searchParams.set('job_sources.can_redistribute', 'eq.true');
    u.searchParams.set('last_checked_at', `gte.${since}`);
    u.searchParams.set('id', `gt.${after}`);
    u.searchParams.set('order', 'id');
    u.searchParams.set('limit', '1000');
    for (const [k, v] of Object.entries(extra)) u.searchParams.set(k, v);
    const r = await fetch(u, { headers: { apikey: KEY } });
    if (!r.ok) throw new Error(`HTTP ${r.status} ${await r.text()}`);
    const page = await r.json();
    if (!page.length) break;
    after = page[page.length - 1].id;
    rows.push(...page);
  }
  return rows;
}

const fold = (s) => (s ?? '').toLowerCase().normalize('NFD').replace(/\p{M}/gu, '');
// Flutter/Dart: the word Flutter or Dart as a word in the TITLE (a title is what the person searches); description-only mentions are counted apart.
const FLUTTER_T = /\b(flutter|dart)\b/i;
const MOBILE_T = /\b(mobile|mobil|android|ios|react native|kotlin|swift|aplicativo|app)\b|desenvolvedor(a)? (de )?(app|aplicativo)/i;
// pelvic physiotherapy: explicit mentions only
const PELVIC = /(pelvic|pelvico|pelvica|assoalho|uroginecolog|obstetric|saude da mulher|perine|incontinencia|uro-?gineco)/;
const PHYSIO_T = /(fisioterap|physiotherap|physical therap)/;

const out = {};
// 1. based in Brazil
const br = await all({ country: 'eq.BR' });
// 2. explicit eligibility for Brazil/LATAM or anywhere (remote), not based in Brazil
const elig = await all({ or: '(geo_restrictions.cs.{BR},geo_restrictions.cs.{LATAM},geo_restrictions.cs.{Anywhere},geo_restrictions.cs.{Brazil},geo_restrictions.cs.{Latin America},geo_restrictions.cs.{Worldwide})' });
const eligOnly = elig.filter((r) => r.country !== 'BR');
out.visible_country_BR = br.length;
out.by_source_BR = Object.fromEntries([...br.reduce((m, r) => m.set(r.source_id, (m.get(r.source_id) ?? 0) + 1), new Map())]);
out.by_work_mode_BR = Object.fromEntries([...br.reduce((m, r) => m.set(r.work_mode, (m.get(r.work_mode) ?? 0) + 1), new Map())]);
out.by_state_BR_city_top = [...br.reduce((m, r) => m.set(r.city ?? '(none)', (m.get(r.city ?? '(none)') ?? 0) + 1), new Map())].sort((a, b) => b[1] - a[1]).slice(0, 8);
const geoValues = new Map();
for (const r of eligOnly) for (const g of r.geo_restrictions ?? []) geoValues.set(g, (geoValues.get(g) ?? 0) + 1);
out.eligible_not_based_in_BR = eligOnly.length;
out.eligibility_values = [...geoValues].sort((a, b) => b[1] - a[1]).slice(0, 15);
const pool = [...br, ...eligOnly];
const classify = (r) => {
  const t = fold(r.title), d = fold(r.description);
  return {
    flutterTitle: FLUTTER_T.test(r.title ?? ''),
    flutterDescOnly: !FLUTTER_T.test(r.title ?? '') && FLUTTER_T.test(r.description ?? ''),
    mobileTitle: MOBILE_T.test(r.title ?? ''),
    physioTitle: PHYSIO_T.test(t),
    pelvicTitle: PHYSIO_T.test(t) && PELVIC.test(t),
    pelvicDesc: PHYSIO_T.test(t) && !PELVIC.test(t) && PELVIC.test(d),
  };
};
const tally = (rows) => {
  const o = { flutter_in_title: 0, flutter_in_description_only: 0, mobile_in_title: 0, physio_title: 0, physio_pelvic_in_title: 0, physio_pelvic_in_description_only: 0 };
  for (const r of rows) {
    const c = classify(r);
    if (c.flutterTitle) o.flutter_in_title++;
    if (c.flutterDescOnly) o.flutter_in_description_only++;
    if (c.mobileTitle) o.mobile_in_title++;
    if (c.physioTitle) o.physio_title++;
    if (c.pelvicTitle) o.physio_pelvic_in_title++;
    if (c.pelvicDesc) o.physio_pelvic_in_description_only++;
  }
  return o;
};
out.tally_based_in_BR = tally(br);
out.tally_eligible_elsewhere = tally(eligOnly);
const samples = (rows, f, n = 12) => rows.filter(f).slice(0, n).map((r) => `${r.source_id} | ${r.title} | ${r.company} | ${r.country ?? '-'}/${r.city ?? '-'} | ${r.work_mode} | ${(r.geo_restrictions ?? []).join(',')}`);
out.flutter_titles = samples(pool, (r) => classify(r).flutterTitle, 40);
out.physio_titles_BR = samples(br, (r) => classify(r).physioTitle, 40);
// duplicates inside the Brazilian set: same url or same title+company
const seen = new Set(); let dupUrl = 0, dupTc = 0; const seenTc = new Set();
for (const r of br) { if (seen.has(r.original_url)) dupUrl++; seen.add(r.original_url); const k = `${fold(r.title)}|${fold(r.company)}`; if (seenTc.has(k)) dupTc++; seenTc.add(k); }
// eligibility classes of the remote listings that are not based in Brazil (explicit evidence only: a listing that says "remote" and nothing else is not counted)
const geo = (r) => (r.geo_restrictions ?? []).map((g) => g.toLowerCase());
const cls = { explicit_BR: 0, explicit_LATAM: 0, worldwide_anywhere: 0, other_regions_only: 0 };
const bySourceElig = {};
for (const r of eligOnly) {
  const g = geo(r);
  const k = g.includes('br') || g.includes('brazil') ? 'explicit_BR' : g.some((x) => x === 'latam' || x === 'latin america') ? 'explicit_LATAM' : g.some((x) => x === 'anywhere' || x === 'worldwide') && r.work_mode === 'remote' ? 'worldwide_anywhere' : 'other_regions_only';
  cls[k]++;
  bySourceElig[r.source_id] = (bySourceElig[r.source_id] ?? 0) + 1;
}
out.eligibility_classes_not_based_in_BR = cls;
out.eligible_by_source = bySourceElig;
out.duplicates_BR = { same_url: dupUrl, same_title_and_company: dupTc };
console.log(JSON.stringify(out, null, 1));
