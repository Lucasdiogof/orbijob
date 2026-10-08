// Reproducible acceptance run for the 8 owner-defined searches.
// Prints/records ONLY what real HTTP calls returned. Never invents results.
// Usage: node scripts/acceptance.mjs [--out docs/evidence/acceptance-<date>.json]
// Optional env: USAJOBS_KEY, USAJOBS_EMAIL, ADZUNA_APP_ID, ADZUNA_APP_KEY
import { readFileSync, writeFileSync } from 'node:fs';

const cat = JSON.parse(readFileSync(new URL('../data/sources.catalog.json', import.meta.url), 'utf8'));
const adzunaCountries = new Set(cat.sources.find((s) => s.id === 'adzuna').countries.map((c) => c.toLowerCase()));
const CASES = [
  { country: 'US', q: 'Flutter Developer' }, { country: 'DE', q: 'Physiotherapeut Beckenboden' },
  { country: 'PT', q: 'Pedreiro' }, { country: 'AU', q: 'House painter' },
  { country: 'CA', q: 'Registered nurse' }, { country: 'ZA', q: 'Electrician' },
  { country: 'SG', q: 'Teacher' }, { country: 'AE', q: 'Driver' },
];
const indeed = { US: 'www', DE: 'de', PT: 'pt', AU: 'au', CA: 'ca', ZA: 'za', SG: 'sg', AE: 'ae' };

async function get(url, headers = {}) {
  try {
    const r = await fetch(url, { headers, signal: AbortSignal.timeout(15000) });
    if (!r.ok) return { state: `HTTP_${r.status}` };
    return { state: 'OK', json: await r.json() };
  } catch (e) {
    return { state: 'NETWORK_ERROR', detail: String(e.cause?.code ?? e.message) };
  }
}

const results = [];
for (const c of CASES) {
  const attempts = [];
  // Remotive: global remote jobs only; filtered client-side by country text is NOT done (no guessing).
  const r = await get(`https://remotive.com/api/remote-jobs?search=${encodeURIComponent(c.q)}&limit=5`);
  attempts.push({ source: 'remotive', scope: 'remote only, global', state: r.state, detail: r.detail, count: r.json?.jobs?.length });
  if (c.country === 'US') {
    if (process.env.USAJOBS_KEY && process.env.USAJOBS_EMAIL) {
      const u = await get(`https://data.usajobs.gov/api/search?Keyword=${encodeURIComponent(c.q)}&ResultsPerPage=5`,
        { 'Authorization-Key': process.env.USAJOBS_KEY, 'User-Agent': process.env.USAJOBS_EMAIL, Host: 'data.usajobs.gov' });
      attempts.push({ source: 'usajobs', state: u.state, detail: u.detail, count: u.json?.SearchResult?.SearchResultCount });
    } else attempts.push({ source: 'usajobs', state: 'SKIPPED_NO_KEY' });
  }
  if (adzunaCountries.has(c.country.toLowerCase())) {
    if (process.env.ADZUNA_APP_ID && process.env.ADZUNA_APP_KEY) {
      const a = await get(`https://api.adzuna.com/v1/api/jobs/${c.country.toLowerCase()}/search/1?app_id=${process.env.ADZUNA_APP_ID}&app_key=${process.env.ADZUNA_APP_KEY}&results_per_page=5&what=${encodeURIComponent(c.q)}`);
      attempts.push({ source: 'adzuna', state: a.state, detail: a.detail, count: a.json?.results?.length });
    } else attempts.push({ source: 'adzuna', state: 'SKIPPED_NO_KEY' });
  }
  const got = attempts.filter((a) => a.state === 'OK' && a.count > 0);
  results.push({
    ...c, attempts,
    verdict: got.length ? 'RESULTS_FROM_REAL_SOURCE' : 'NO_INTEGRATED_SOURCE',
    externalAlternative: `https://${indeed[c.country]}.indeed.com/jobs?q=${encodeURIComponent(c.q)}`,
  });
}
const out = { ranAt: new Date().toISOString(), node: process.version, results };
const i = process.argv.indexOf('--out');
if (i > 0) writeFileSync(process.argv[i + 1], JSON.stringify(out, null, 2) + '\n');
for (const r of results) console.log(`${r.country} | ${r.q} | ${r.verdict} | ${r.attempts.map((a) => `${a.source}:${a.state}${a.detail ? '(' + a.detail + ')' : ''}`).join(', ')}`);
