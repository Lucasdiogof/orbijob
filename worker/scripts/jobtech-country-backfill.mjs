#!/usr/bin/env node
// Builds the apply/undo SQL that gives a country to STORED Platsbanken jobs whose own ad names one (`workplace_address.country`, in Swedish).
// The stored row does not keep the raw country, so each ad is read again from the official API (`/ad/{id}`, one request a second) and normalised with
// the connector's own function. READ-ONLY against the database (one SELECT through the linked CLI); it writes two files.
//   node scripts/jobtech-country-backfill.mjs <outDir>
import { build } from 'esbuild';
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

const outDir = process.argv[2];
if (!outDir) { console.error('uso: node scripts/jobtech-country-backfill.mjs <pasta de saida>'); process.exit(2); }
const root = fileURLToPath(new URL('..', import.meta.url));
const work = mkdtempSync(join(tmpdir(), 'orbijob-jt-'));
const bundle = join(work, 'jobtech.mjs');
await build({ entryPoints: [join(root, 'src/connectors/jobtech.ts')], bundle: true, format: 'esm', platform: 'node', outfile: bundle, logLevel: 'error' });
const { normalizeJobtech } = await import(pathToFileURL(bundle).href);

const sqlFile = join(work, 'q.sql');
writeFileSync(sqlFile, "select id, external_id from public.jobs where source_id = 'jobtech' and country is null and status = 'open' order by external_id");
const raw = execFileSync('npx', ['supabase', 'db', 'query', '--linked', '-o', 'json', '-f', sqlFile], { cwd: join(root, '..'), encoding: 'utf8', shell: process.platform === 'win32', maxBuffer: 64 * 1024 * 1024 });
const rows = JSON.parse(raw.slice(raw.indexOf('{'))).rows;

const UA = { 'user-agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)', accept: 'application/json' };
const byCountry = new Map();
let unreadable = 0;
for (const r of rows) {
  const res = await fetch(`https://jobsearch.api.jobtechdev.se/ad/${encodeURIComponent(r.external_id)}`, { headers: UA, signal: AbortSignal.timeout(20_000) });
  if (res.status !== 200) { unreadable++; await res.arrayBuffer().catch(() => {}); await new Promise((s) => setTimeout(s, 1000)); continue; }
  const n = normalizeJobtech(await res.json(), new Date().toISOString());
  if (n.ok && n.job.country) {
    if (!byCountry.has(n.job.country)) byCountry.set(n.job.country, []);
    byCountry.get(n.job.country).push(r.id);
  }
  await new Promise((s) => setTimeout(s, 1000));
}
const q = (ids) => ids.map((i) => `'${i}'`).join(',');
let apply = 'begin;\n';
let undo = 'begin;\n';
for (const [code, ids] of byCountry) {
  apply += `update public.jobs set country = '${code}' where source_id = 'jobtech' and country is null and id in (${q(ids)});\n`;
  undo += `update public.jobs set country = null where source_id = 'jobtech' and country = '${code}' and id in (${q(ids)});\n`;
}
apply += 'commit;\n';
undo += 'commit;\n';
mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'apply.sql'), apply);
writeFileSync(join(outDir, 'undo.sql'), undo);
console.log(`candidatas=${rows.length} recuperadas=${[...byCountry.values()].reduce((n, a) => n + a.length, 0)} ilegiveis=${unreadable}`, Object.fromEntries([...byCountry].map(([c, a]) => [c, a.length])));
