#!/usr/bin/env node
// O QUE O APP VÊ: reproduz, com a chave PUBLISHABLE (a mesma que vai dentro do app, sujeita ao RLS), as consultas que o Flutter faz ao catálogo
// e mais algumas por fonte, país, continente, área, busca e paginação. Somente leitura. Diferencia o total gravado do que o app realmente exibe
// (status aberto + fonte publicada + verificação com menos de 72 h).
//
//   SUPABASE_PUBLISHABLE_KEY=sb_publishable_... node worker/scripts/app-visibility-check.mjs [--json]
//
// Código de saída: 0 tudo respondeu 200; 1 alguma consulta falhou.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const REF = 'rpmlfxwebnlxnwadyvle';
const BASE = `https://${REF}.supabase.co/rest/v1`;
const KEY = (process.env.SUPABASE_PUBLISHABLE_KEY ?? '').trim();
if (!KEY.startsWith('sb_publishable_')) { console.error('PARE: defina SUPABASE_PUBLISHABLE_KEY com a chave PUBLISHABLE (publica)'); process.exit(1); }
const asJson = process.argv.includes('--json');
const sinceIso = new Date(Date.now() - 72 * 3_600_000).toISOString();
const SELECT = 'id,source_id,external_id,company,title,country,city,work_mode,published_at,original_url,job_sources!inner(id,attribution,can_redistribute,status)';
const VISIBLE = `status=eq.open&job_sources.can_redistribute=eq.true&job_sources.status=in.("READY","CONDITIONAL")&last_checked_at=gte.${sinceIso}`;

async function get(qs, { count = true, range } = {}) {
  const r = await fetch(`${BASE}/jobs?${qs}`, { headers: { apikey: KEY, ...(count ? { Prefer: 'count=exact' } : {}), ...(range ? { Range: range } : {}) }, signal: AbortSignal.timeout(30_000) });
  const total = Number((r.headers.get('content-range') ?? '*/0').split('/')[1]);
  const body = r.ok ? await r.json() : [];
  return { status: r.status, total: Number.isFinite(total) ? total : body.length, rows: body };
}
const enc = encodeURIComponent;
const results = [];
const check = async (name, qs, extra = {}) => {
  const r = await get(`select=${enc(SELECT)}&${VISIBLE}&${qs}&limit=${extra.limit ?? 1}`, extra);
  results.push({ name, status: r.status, visible: r.total, sample: r.rows[0] ? `${r.rows[0].title} | ${r.rows[0].company}` : null, rows: r.rows });
  return r;
};

// 1. the requests the app sends (golden file replayed with the app's own 72 h window)
const golden = JSON.parse(readFileSync(fileURLToPath(new URL('../../app/test/supabase/catalog_requests.golden.json', import.meta.url)), 'utf8'));
for (const sc of golden.scenarios) {
  for (const [i, rq] of sc.requests.entries()) {
    if (rq.method !== 'GET' || !rq.path.endsWith('/jobs')) continue;
    const q = rq.query.replace(/last_checked_at=gte\.[^&]+/, `last_checked_at=gte.${enc(sinceIso)}`).replace(/&limit=\d+/, '&limit=1').replace(/&offset=\d+/, '&offset=0');
    const r = await get(q);
    results.push({ name: `app:${sc.name}${sc.requests.length > 1 ? `#${i}` : ''}`, status: r.status, visible: r.total, sample: r.rows[0]?.title ?? null });
  }
}

// 2. per source: stored vs visible
const sources = ['jobicy', 'jobtech', 'arbeitnow', 'remoteok', 'remotive', 'twjobs', 'jobsconz', 'getonboard', 'teachingvacancies', 'nycjobs', 'karrierenrw', 'bpce', 'forem', 'mpsvcz', 'csp', 'sefmurcia', 'feinaactiva', 'ecyl', 'lanbide'];
const stored = {};
for (const s of sources) {
  stored[s] = (await get(`select=id&source_id=eq.${s}&status=eq.open`, { range: '0-0' })).total;
  await check(`source:${s}`, `source_id=eq.${s}`);
}
const storedOpen = (await get('select=id&status=eq.open', { range: '0-0' })).total;

// 3. filters
await check('country:SE', 'or=(country.eq.SE,geo_restrictions.cs.{SE},and(work_mode.eq.remote,geo_restrictions.cs.{Anywhere}))');
await check('country:US', 'or=(country.eq.US,geo_restrictions.cs.{US},and(work_mode.eq.remote,geo_restrictions.cs.{Anywhere}))');
const cont = {
  europe: 'AD,AL,AT,BA,BE,BG,BY,CH,CY,CZ,DE,DK,EE,ES,FI,FO,FR,GB,GI,GR,GG,HR,HU,IE,IM,IS,IT,JE,LI,LT,LU,LV,MC,MD,ME,MK,MT,NL,NO,PL,PT,RO,RS,RU,SE,SI,SK,SM,UA,VA,XK',
  oceania: 'AS,AU,CK,FJ,FM,GU,KI,MH,MP,NC,NF,NR,NU,NZ,PF,PG,PN,PW,SB,TK,TO,TV,VU,WF,WS',
  asia: 'AE,AF,AM,AZ,BD,BH,BN,BT,CN,GE,HK,ID,IL,IN,IQ,IR,JO,JP,KG,KH,KP,KR,KW,KZ,LA,LB,LK,MM,MN,MO,MV,MY,NP,OM,PH,PK,PS,QA,SA,SG,SY,TH,TJ,TL,TM,TR,TW,UZ,VN,YE',
  africa: 'AO,BF,BI,BJ,BW,CD,CF,CG,CI,CM,CV,DJ,DZ,EG,EH,ER,ET,GA,GH,GM,GN,GQ,GW,KE,KM,LR,LS,LY,MA,MG,ML,MR,MU,MW,MZ,NA,NE,NG,RE,RW,SC,SD,SL,SN,SO,SS,ST,SZ,TD,TG,TN,TZ,UG,YT,ZA,ZM,ZW',
  northAmerica: 'AG,AI,AW,BB,BL,BM,BS,BZ,CA,CR,CU,CW,DM,DO,GD,GL,GP,GT,HN,HT,JM,KN,KY,LC,MF,MQ,MS,MX,NI,PA,PM,PR,SV,SX,TC,TT,US,VC,VG,VI',
  southAmerica: 'AR,BO,BR,CL,CO,EC,FK,GF,GY,PE,PY,SR,UY,VE',
};
for (const [k, codes] of Object.entries(cont)) await check(`continent:${k}`, `or=(country.in.(${codes}),geo_restrictions.ov.{${codes}${k === 'europe' ? ',Europe' : ''}})`);
await check('country:unknown (no country, no eligibility)', 'country=is.null&geo_restrictions=eq.{}');

// 4. search, in several languages (title substring, as the app does, plus the websearch column)
const term = (t, extra = '') => `or=(search.wfts(simple).${enc(t)},title.ilike.*${enc(t)}*${extra})`;
await check('search:physiotherapist (+synonyms)', term('physiotherapist', ',title.ilike.*fisioterap*,title.ilike.*fysioterapeut*,title.ilike.*sjukgymnast*'));
await check('search:fysioterapeut', term('fysioterapeut'));
await check('search:flutter', term('flutter'));
await check('search:mobil/android/ios (title)', 'or=(title.ilike.*flutter*,title.ilike.*android*,title.ilike.*ios*,title.ilike.*mobil*,title.ilike.*kotlin*,title.ilike.*swift*)');
await check('search:sjuksköterska (nurse, Swedish)', term('sjuksköterska', ',title.ilike.*nurse*'));
await check('search:pelvic', 'or=(title.ilike.*pelvic*,title.ilike.*pélvic*,title.ilike.*bäckenbotten*,title.ilike.*beckenboden*,title.ilike.*uroginecol*)');
await check('search:Berlin (city)', 'city=ilike.*Berlin*');

// 5. professional areas by title (a subset of the app's keywords) and health specialties
await check('area:health (title)', 'or=(title.ilike.*nurse*,title.ilike.*sjuksköterska*,title.ilike.*fysioterapeut*,title.ilike.*physio*,title.ilike.*läkare*,title.ilike.*fisioterap*)');
await check('area:education (title)', 'or=(title.ilike.*teacher*,title.ilike.*lärare*,title.ilike.*lehrer*,title.ilike.*professor*)');
await check('area:logistics (title)', 'or=(title.ilike.*driver*,title.ilike.*chaufför*,title.ilike.*lager*,title.ilike.*logistic*)');

// 6. pagination: pages do not overlap and the last page is short
const p1 = await check('page 1', 'order=published_at.desc.nullslast,id.desc', { limit: 20, count: true });
const p2 = await get(`select=${enc(SELECT)}&${VISIBLE}&order=published_at.desc.nullslast,id.desc&limit=20&offset=20`);
const overlap = p1.rows.filter((a) => p2.rows.some((b) => b.id === a.id)).length;
results.push({ name: 'pagination: page 1 vs page 2 overlap', status: p2.status, visible: overlap, sample: overlap === 0 ? 'no overlap' : 'OVERLAP' });
const last = await get(`select=${enc(SELECT)}&${VISIBLE}&order=published_at.desc.nullslast,id.desc&limit=20&offset=${Math.max(0, Math.floor((p1.total - 1) / 20) * 20)}`);
results.push({ name: 'pagination: last page size', status: last.status, visible: last.rows.length, sample: `total ${p1.total}` });

// 7. links and attribution of what is visible
const sample = await get(`select=${enc(SELECT)}&${VISIBLE}&limit=1000`, { range: '0-999' });
const hostOk = { jobicy: /(^|\.)jobicy\.com$/, jobtech: /(^|\.)arbetsformedlingen\.se$/, arbeitnow: /(^|\.)arbeitnow\.(com|co\.uk|fr|ch)$/, remoteok: /(^|\.)remoteok\.com$/, remotive: /(^|\.)remotive\.com$/, twjobs: /(^|\.)taiwanjobs\.gov\.tw$/, jobsconz: /(^|\.)jobs\.co\.nz$/, getonboard: /(^|\.)getonbrd\.com$/, teachingvacancies: /(^|\.)teaching-vacancies\.service\.gov\.uk$/, nycjobs: /(^|\.)cityjobs\.nyc\.gov$/, karrierenrw: /(^|\.)karriere\.nrw$/, bpce: /(^|\.)bpce\.fr$/, forem: /(^|\.)leforem\.be$/, mpsvcz: /(^|\.)up\.gov\.cz$/, csp: /(^|\.)choisirleservicepublic\.gouv\.fr$/, sefmurcia: /(^|\.)carm\.es$/, feinaactiva: /(^|\.)gencat\.cat$/, ecyl: /(^|\.)jcyl\.es$/, lanbide: /(^|\.)lanbide\.eus$/ };
let badUrl = 0, noAttr = 0;
for (const r of sample.rows) {
  try { const u = new URL(r.original_url); if (u.protocol !== 'https:' || !hostOk[r.source_id]?.test(u.hostname)) badUrl++; } catch { badUrl++; }
  if (!r.job_sources?.attribution || !/^https?:\/\//.test(String(r.job_sources.attribution).match(/\(([^)]+)\)/)?.[1] ?? '')) noAttr++;
}
results.push({ name: `links: ${sample.rows.length} visible rows checked`, status: sample.status, visible: badUrl, sample: `bad original_url=${badUrl}, attribution without link=${noAttr}` });

const failed = results.filter((r) => r.status !== 200 && r.status !== 206);
if (asJson) console.log(JSON.stringify({ at: new Date().toISOString(), storedOpen, stored, results: results.map(({ rows, ...r }) => r) }, null, 1));
else {
  console.log(`vagas abertas gravadas: ${storedOpen}  (por fonte: ${sources.map((s) => `${s}=${stored[s]}`).join(' ')})`);
  for (const r of results) console.log(`${r.status}  ${String(r.visible).padStart(5)}  ${r.name}${r.sample ? `   [${r.sample}]` : ''}`);
}
process.exit(failed.length ? 1 : 0);
