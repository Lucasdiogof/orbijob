#!/usr/bin/env node
// Downloads the ESCO occupations (names in every language) into one JSON file that scripts/build-occupations.mjs turns into the app's table.
// European Skills, Competences, Qualifications and Occupations, © European Union, https://esco.ec.europa.eu, CC BY 4.0.
//   node scripts/esco-fetch.mjs <out-dir>
// Resumable: the list (occupations.json) and the details (details.json) are checkpointed every 200 occupations, and what is already saved
// is never requested again. Polite on purpose: 4 workers, a pause after every request, retries with growing waits on 429/5xx.
// A handful of occupations answer 500 ("More than one value found for field 'hasSkillType'") on the current version; the same request pinned
// to selectedVersion=v1.1.1 works, so a failure falls back to it.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

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

let occupations = existsSync(listFile) ? JSON.parse(readFileSync(listFile, 'utf8')) : null;
if (!occupations) {
  occupations = [];
  for (let off = 0; ; off += 100) {
    const j = await getJson(`${API}/search?type=occupation&language=en&limit=100&offset=${off}&full=false`);
    const res = j._embedded?.results ?? [];
    for (const x of res) occupations.push({ uri: x.uri, title: x.title });
    if (res.length < 100) break;
    await sleep(400);
  }
  writeFileSync(listFile, JSON.stringify(occupations));
}
console.log(`occupations listed: ${occupations.length}`);

const out = existsSync(detailFile) ? JSON.parse(readFileSync(detailFile, 'utf8')) : {};
const todo = occupations.filter((o) => !out[o.uri]);
console.log(`already saved: ${Object.keys(out).length}, to fetch: ${todo.length}`);
const pick = (m) => Object.fromEntries(LANGS.filter((l) => m?.[l]).map((l) => [l, m[l]]));
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
