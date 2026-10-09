// Reproducible reachability + schema probe for the candidate first sources. Records ONLY what real HTTP calls
// returned; a source is never promoted to READY by this script (that needs live validation of a real response
// AND a reviewed licence/terms decision, see docs/SOURCES_VALIDATION.md).
// Usage: node scripts/probe-sources.mjs [--out docs/evidence/source-probe-<date>.json]
// Optional env: USAJOBS_KEY + USAJOBS_EMAIL, ADZUNA_APP_ID + ADZUNA_APP_KEY, FT_CLIENT_ID + FT_CLIENT_SECRET,
//               GREENHOUSE_BOARD, LEVER_SITE, ASHBY_BOARD (public company boards to probe; defaults are public demo boards).
import { writeFileSync } from 'node:fs';

const out = process.argv.includes('--out') ? process.argv[process.argv.indexOf('--out') + 1] : null;
const env = process.env;

async function get(url, { headers = {}, method = 'GET', body } = {}) {
  try {
    const r = await fetch(url, { method, headers, body, signal: AbortSignal.timeout(15000) });
    const text = await r.text();
    // A sandbox/corporate egress allowlist answers 403 with this text; that says nothing about the source itself.
    if (r.status === 403 && /Host not in allowlist/i.test(text)) return { egressBlocked: text.slice(0, 120) };
    let json; try { json = JSON.parse(text); } catch { /* not JSON */ }
    return { http: r.status, ok: r.ok, json, contentType: r.headers.get('content-type') };
  } catch (e) {
    return { network: String(e.cause?.code ?? e.cause?.message ?? e.message) };
  }
}
const verdict = (r, check) => r.egressBlocked ? { state: 'EGRESS_BLOCKED', detail: r.egressBlocked } : r.network ? { state: 'NETWORK_BLOCKED', detail: r.network }
  : !r.ok ? { state: `HTTP_${r.http}` }
  : check(r.json) ? { state: 'SCHEMA_OK' } : { state: 'SCHEMA_MISMATCH' };

const probes = [
  { id: 'himalayas', auth: 'none', scope: 'remote, global', run: async () => verdict(await get('https://himalayas.app/jobs/api?limit=1'), (j) => Array.isArray(j?.jobs)) },
  { id: 'jobicy', auth: 'none', scope: 'remote, global', run: async () => verdict(await get('https://jobicy.com/api/v2/remote-jobs?count=1'), (j) => Array.isArray(j?.jobs)) },
  { id: 'greenhouse', auth: 'none (public board token)', scope: 'per company board', run: async () => verdict(await get(`https://boards-api.greenhouse.io/v1/boards/${env.GREENHOUSE_BOARD || 'greenhouse'}/jobs?content=false`), (j) => Array.isArray(j?.jobs)) },
  { id: 'lever', auth: 'none (public site)', scope: 'per company site', run: async () => verdict(await get(`https://api.lever.co/v0/postings/${env.LEVER_SITE || 'leverdemo'}?mode=json&limit=1`), Array.isArray) },
  { id: 'ashby', auth: 'none (public board)', scope: 'per company board', run: async () => verdict(await get(`https://api.ashbyhq.com/posting-api/job-board/${env.ASHBY_BOARD || 'Ashby'}`), (j) => Array.isArray(j?.jobs)) },
  { id: 'usajobs', auth: 'free API key + registered email', scope: 'US federal jobs', run: async () => {
    if (!env.USAJOBS_KEY || !env.USAJOBS_EMAIL) return { state: 'SKIPPED_NO_KEY', detail: 'register at developer.usajobs.gov' };
    return verdict(await get('https://data.usajobs.gov/api/search?Keyword=nurse&ResultsPerPage=1', { headers: { 'Authorization-Key': env.USAJOBS_KEY, 'User-Agent': env.USAJOBS_EMAIL, Host: 'data.usajobs.gov' } }), (j) => j?.SearchResult?.SearchResultItems !== undefined);
  } },
  { id: 'france-travail', auth: 'OAuth2 client credentials (free account)', scope: 'France', run: async () => {
    if (!env.FT_CLIENT_ID || !env.FT_CLIENT_SECRET) { const r = await get('https://api.francetravail.io/'); return { state: 'SKIPPED_NO_KEY', detail: r.egressBlocked ? 'egress blocked by this environment; credentials also needed' : r.network ? `host unreachable: ${r.network}` : `host reachable (HTTP ${r.http}); credentials needed` }; }
    const t = await get('https://entreprise.francetravail.io/connexion/oauth2/access_token?realm=%2Fpartenaire', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ grant_type: 'client_credentials', client_id: env.FT_CLIENT_ID, client_secret: env.FT_CLIENT_SECRET, scope: 'api_offresdemploiv2 o2dsoffre' }) });
    if (!t.json?.access_token) return verdict(t, () => false);
    return verdict(await get('https://api.francetravail.io/partenaire/offresdemploi/v2/offres/search?range=0-0', { headers: { Authorization: `Bearer ${t.json.access_token}` } }), (j) => Array.isArray(j?.resultats));
  } },
  { id: 'adzuna', auth: 'app_id + app_key (free tier)', scope: 'multi-country aggregator', run: async () => {
    if (!env.ADZUNA_APP_ID || !env.ADZUNA_APP_KEY) { const r = await get('https://api.adzuna.com/'); return { state: 'SKIPPED_NO_KEY', detail: r.egressBlocked ? 'egress blocked by this environment; credentials also needed' : r.network ? `host unreachable: ${r.network}` : `host reachable (HTTP ${r.http}); credentials needed` }; }
    return verdict(await get(`https://api.adzuna.com/v1/api/jobs/gb/search/1?app_id=${env.ADZUNA_APP_ID}&app_key=${env.ADZUNA_APP_KEY}&results_per_page=1`), (j) => Array.isArray(j?.results));
  } },
];

const results = [];
for (const p of probes) {
  const v = await p.run();
  results.push({ source: p.id, auth: p.auth, scope: p.scope, ...v, licence: 'UNVERIFIED (review terms before READY)', promotedToReady: false });
  console.log(p.id.padEnd(15), v.state.padEnd(16), v.detail ?? '');
}
const report = { probedAt: new Date().toISOString(), node: process.version, note: 'Only observed HTTP outcomes. No sample job content is stored.', results };
if (out) writeFileSync(out, JSON.stringify(report, null, 2) + '\n');
