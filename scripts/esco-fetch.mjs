#!/usr/bin/env node
// Downloads the ESCO occupations (names in every language) into one JSON file that scripts/build-occupations.mjs turns into the app's table.
// European Skills, Competences, Qualifications and Occupations, © European Union, https://esco.ec.europa.eu, CC BY 4.0.
//   node scripts/esco-fetch.mjs <out-dir>
// Resumable: the list (occupations.json) and the details (details.json) are checkpointed every 200 occupations. A saved occupation is
// requested again only when it lacks one of the languages in LANGS (each entry records the languages it was fetched with), so adding a
// language re-reads exactly the occupations that need it.
//
// Pagination (checked against the live API on 2026-10-14): `offset` is a PAGE INDEX, not a row offset (offset=1 is the second page of
// `limit` rows; past the last page the API answers 0 rows), and every page carries `_links.next` until the last. The list follows
// `_links.next` (falling back to offset+1), drops repeated URIs, stops on a page that adds nothing new, and REFUSES to save a list shorter
// than the `total` the API announced: a truncated list never replaces a complete one. Polite on purpose: 4 workers, a pause after every request, retries with growing waits on 429/5xx.
// A handful of occupations answer 500 ("More than one value found for field 'hasSkillType'") on the current version; the same request pinned
// to selectedVersion=v1.1.1 works, so a failure falls back to it.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { listOccupations } from './lib/esco-list.mjs';

const API = 'https://ec.europa.eu/esco/api';
const LANGS = ['en', 'pt', 'es', 'de', 'sv', 'nl', 'fr', 'it', 'da', 'no', 'fi', 'pl', 'cs'];
const dir = process.argv[2];
if (!dir) {
  console.error('usage: node scripts/esco-fetch.mjs <out-dir>');
  process.exit(2);
}
mkdirSync(dir, { recursive: true });
const listFile = join(dir, 'occupations.json');
const detailFile = join(dir, 'details.json');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getJson(url) {
  let last = '';
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      const r = await fetch(url);
      if (r.ok) return await r.json();
      last = String(r.status);
      if (r.status !== 429 && r.status < 500) break;
    } catch (e) {
      last = String(e);
    }
    await sleep(2000 * (attempt + 1));
  }
  throw new Error(`${last} ${url}`);
}

// Large pages (~2 MB) through curl: Node 24's built-in fetch (undici) aborted the whole process on such responses
// ("assert(!this.paused)" in Parser.finish, not catchable) on 2026-10-14. Same retries and waits as getJson.
async function getJsonLarge(url) {
  let last = '';
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      const body = execFileSync('curl', ['-sS', '--fail', '--max-time', '120', url], { maxBuffer: 64 * 1024 * 1024 });
      return JSON.parse(body.toString('utf8'));
    } catch (e) {
      last = String(e).slice(0, 120);
    }
    await sleep(3000 * (attempt + 1));
  }
  throw new Error(`${last} ${url}`);
}

let occupations = existsSync(listFile) ? JSON.parse(readFileSync(listFile, 'utf8')) : null;
if (!occupations) {
  occupations = await listOccupations(API, getJson, () => sleep(400));
  writeFileSync(listFile, JSON.stringify(occupations));
}
console.log(`occupations listed: ${occupations.length}`);

const out = existsSync(detailFile) ? JSON.parse(readFileSync(detailFile, 'utf8')) : {};
const complete = (e) => e && Array.isArray(e.langs) && LANGS.every((l) => e.langs.includes(l));
const pick = (m) => Object.fromEntries(LANGS.filter((l) => m?.[l]).map((l) => [l, m[l]]));
const entry = (j, title) => ({
  en: title ?? j.title,
  pref: pick(j.preferredLabel),
  alt: pick(j.alternativeLabel),
  isco: (j._links?.broaderIscoGroup ?? []).map((g) => g.code || g.title).filter(Boolean),
  code: j.code,
  langs: LANGS,
});

// Bulk pass (2026-10-14): the search endpoint with `full=true` returns whole occupations (every language, the ISCO link) for a page of
// results, so 50 occupations cost one request (~12 s) instead of 50 (~2.5 s each). Pages of 50: the client failed on a 100-row page (~4 MB).
// Only occupations of the list that still lack a language are taken from it; anything the pages miss falls back to one request each below.
const known = new Set(occupations.map((o) => o.uri));
if (occupations.some((o) => !complete(out[o.uri]))) {
  const title = new Map(occupations.map((o) => [o.uri, o.title]));
  let bulkFailures = 0;
  for (let page = 0; page < 200; page++) {
    let j;
    try {
      j = await getJsonLarge(`${API}/search?type=occupation&language=en&limit=50&offset=${page}&full=true`);
    } catch (e) {
      // one bad occupation makes the whole page answer 500 on the current ESCO version: skip the page, its occupations are fetched one by
      // one below (with the v1.1.1 fallback); stop only after several failures in a row
      console.log(`bulk page ${page} failed (${String(e).slice(0, 60)}): its occupations will be fetched one by one`);
      if (++bulkFailures >= 4) break;
      continue;
    }
    const res = j._embedded?.results ?? [];
    if (res.length === 0) break;
    bulkFailures = 0;
    for (const x of res) if (known.has(x.uri) && !complete(out[x.uri])) out[x.uri] = entry(x, title.get(x.uri));
    writeFileSync(detailFile, JSON.stringify(out));
    console.log(`bulk page ${page}: ${occupations.filter((o) => complete(out[o.uri])).length} of ${occupations.length} complete`);
    await sleep(500);
  }
}

const todo = occupations.filter((o) => !complete(out[o.uri]));
console.log(`already saved: ${Object.keys(out).length}, to fetch one by one: ${todo.length}`);
const failed = [];
let done = 0;

async function one(o) {
  const base = `${API}/resource/occupation?uri=${encodeURIComponent(o.uri)}&language=en`;
  let j;
  try {
    j = await getJson(base);
  } catch {
    j = await getJson(`${base}&selectedVersion=v1.1.1`);
  }
  out[o.uri] = {
    en: o.title,
    pref: pick(j.preferredLabel),
    alt: pick(j.alternativeLabel),
    isco: (j._links?.broaderIscoGroup ?? []).map((g) => g.code || g.title).filter(Boolean),
    code: j.code,
    langs: LANGS,
  };
}

async function worker() {
  while (todo.length) {
    const o = todo.shift();
    try {
      await one(o);
    } catch (e) {
      failed.push(o.title);
    }
    if (++done % 200 === 0) {
      writeFileSync(detailFile, JSON.stringify(out));
      console.log(`${done} fetched`);
    }
    await sleep(250);
  }
}
await Promise.all([worker(), worker(), worker(), worker()]);
writeFileSync(detailFile, JSON.stringify(out));
console.log(`saved ${Object.keys(out).length} of ${occupations.length}; failed: ${failed.length ? failed.join(', ') : 'none'}`);
