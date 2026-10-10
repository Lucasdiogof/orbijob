#!/usr/bin/env node
// Replays the EXACT requests the Flutter catalogue repository sends (app/test/supabase/catalog_requests.golden.json)
// against a REAL PostgREST running on the REAL migrated schema, with the seed supabase/tests/09_catalog_seed.sql, and
// checks status codes, which rows come back, their order and the JSON types the app parses.
//
//   POSTGREST_URL=http://localhost:3000 node scripts/supabase/catalog_postgrest_contract.mjs
//
// Read-only: only GET. Intended for a disposable database (CI job `catalog-postgrest`); it refuses anything else it
// cannot recognise because the seed ids are checked in the answers.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const BASE = (process.env.POSTGREST_URL ?? 'http://localhost:3000').replace(/\/+$/, '');
const golden = JSON.parse(readFileSync(fileURLToPath(new URL('../../app/test/supabase/catalog_requests.golden.json', import.meta.url)), 'utf8'));

// What the seed must answer for each recorded search: external ids, in order. Page requests ask for limit + 1 rows
// (the extra row tells the app there is a next page).
const VISIBLE_NEWEST_FIRST = ['1', '4', '2', '8', '3', '11', '5'];
const EXPECT = {
  browse: VISIBLE_NEWEST_FIRST,
  text_flutter: ['1'],
  text_partial_title: ['3'], // only the title substring matches "engin" (the text-search column has no stemming)
  text_hostile: [], // sanitised to plain words: no extra filter, no error, nothing leaks
  country_us: ['1', '2', '8'], // country US, listed as eligible, or remote marked Anywhere (job 11 has an EMPTY list = unknown: never matches)
  country_pt: ['4', '2'],
  country_de: ['2', '5'],
  mode_onsite: ['4'],
  mode_remote_hybrid: ['1', '2', '8', '3', '11', '5'],
  published_7d: ['1', '4', '2', '8'], // 3 is 20 days old; 5 has no date
  only_with_salary: ['1', '4', '3'],
  text_and_country_two_or_groups: [], // text matches only 1; country PT matches 4 and 2: two `or` params must be ANDed
  text_and_country_overlap: ['2'],
  all_filters: ['1'],
  page_1: ['1', '4', '2', '8'], // limit 3 + 1
  page_2: ['8', '3', '11', '5'], // offset 3
};
const HIDDEN = new Set(['6', '7', '9', '10', '12']); // 12: open but not verified for more than 72 h
const SOURCES_OK = new Set(['jobicy', 'lever']);

const failures = [];
const fail = (scenario, msg) => failures.push(`${scenario}: ${msg}`);
const isIso = (s) => typeof s === 'string' && !Number.isNaN(Date.parse(s));

function checkRow(scenario, r) {
  if (HIDDEN.has(r.external_id)) fail(scenario, `returned hidden job ${r.external_id}`);
  if (r.status !== 'open') fail(scenario, `job ${r.external_id} has status ${r.status}`);
  const src = r.job_sources;
  if (!src || Array.isArray(src) || typeof src !== 'object') return fail(scenario, `job ${r.external_id}: job_sources is not an object`);
  if (src.can_redistribute !== true || !['READY', 'CONDITIONAL'].includes(src.status) || !SOURCES_OK.has(src.id)) {
    fail(scenario, `job ${r.external_id}: unauthorised source ${JSON.stringify(src)}`);
  }
  // types the Dart mapper depends on
  if (typeof r.title !== 'string' || typeof r.original_url !== 'string') fail(scenario, `job ${r.external_id}: title/url types`);
  if (!Array.isArray(r.geo_restrictions) || r.geo_restrictions.some((g) => typeof g !== 'string')) fail(scenario, `job ${r.external_id}: geo_restrictions type`);
  if (r.published_at !== null && !isIso(r.published_at)) fail(scenario, `job ${r.external_id}: published_at ${r.published_at}`);
  for (const k of ['salary_min', 'salary_max']) if (r[k] !== null && typeof r[k] !== 'number') fail(scenario, `job ${r.external_id}: ${k} is ${typeof r[k]}`);
  if (r.country !== null && !/^[A-Z]{2}$/.test(r.country)) fail(scenario, `job ${r.external_id}: country ${JSON.stringify(r.country)}`);
}

let replayed = 0;
const seenJobRows = new Set();
for (const s of golden.scenarios) {
  for (const req of s.requests) {
    if (req.method !== 'GET') { fail(s.name, `non-GET request ${req.method}`); continue; }
    const path = req.path.replace(/^\/rest\/v1/, '');
    const url = `${BASE}${path}?${req.query}`;
    let res;
    try { res = await fetch(url, { headers: { Accept: 'application/json' } }); } catch (e) { fail(s.name, `network error ${e.message}`); continue; }
    const text = await res.text();
    replayed++;
    if (res.status !== 200) { fail(s.name, `HTTP ${res.status} for ${path}: ${text.slice(0, 300)}`); continue; }
    let rows;
    try { rows = JSON.parse(text); } catch { fail(s.name, 'response is not JSON'); continue; }
    if (!Array.isArray(rows)) { fail(s.name, 'response is not an array'); continue; }

    if (path === '/jobs') {
      rows.forEach((r) => { checkRow(s.name, r); seenJobRows.add(r.external_id); });
      const want = EXPECT[s.name];
      if (want === undefined) {
        // the source-check scenario: the catalogue answer itself is not asserted here
        if (s.name !== 'empty_catalogue_source_check') fail(s.name, 'no expectation defined');
      } else {
        const got = rows.map((r) => r.external_id);
        if (JSON.stringify(got) !== JSON.stringify(want)) fail(s.name, `expected [${want}] but got [${got}]`);
      }
    } else if (path === '/job_sources') {
      if (rows.length !== 1) fail(s.name, `expected exactly one authorised source (limit 1), got ${rows.length}`);
      else if (!SOURCES_OK.has(rows[0].id)) fail(s.name, `unexpected source ${JSON.stringify(rows[0])}`);
    } else {
      fail(s.name, `unexpected path ${path}`);
    }
  }
}

// Sanity: the seed really exercised what the checks claim (a seed that returned nothing would "pass" every filter).
for (const id of VISIBLE_NEWEST_FIRST) if (!seenJobRows.has(id)) failures.push(`seed: visible job ${id} never returned by any query`);
for (const name of Object.keys(EXPECT)) if (!golden.scenarios.some((s) => s.name === name)) failures.push(`golden file has no scenario ${name}`);

if (failures.length) {
  console.error(`CATALOGUE CONTRACT FAILED (${failures.length}):\n - ${failures.join('\n - ')}`);
  process.exit(1);
}
console.log(`catalogue contract OK: ${replayed} requests replayed against PostgREST at ${BASE}`);
