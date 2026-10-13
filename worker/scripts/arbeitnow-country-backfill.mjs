#!/usr/bin/env node
// Builds the apply/undo SQL that gives a country to STORED Arbeitnow jobs whose location states one (or names a place only one country has),
// using the very function the connector uses (`arbeitnowStatedCountry`). READ-ONLY against the database (one SELECT through the linked CLI);
// it only writes two files. Usage:  node scripts/arbeitnow-country-backfill.mjs <outDir>
import { build } from 'esbuild';
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

const outDir = process.argv[2];
if (!outDir) { console.error('uso: node scripts/arbeitnow-country-backfill.mjs <pasta de saida>'); process.exit(2); }
const root = fileURLToPath(new URL('..', import.meta.url));
const work = mkdtempSync(join(tmpdir(), 'orbijob-backfill-'));
const bundle = join(work, 'feeds.mjs');
await build({ entryPoints: [join(root, 'src/connectors/feeds.ts')], bundle: true, format: 'esm', platform: 'node', outfile: bundle, logLevel: 'error' });
const { arbeitnowStatedCountry } = await import(pathToFileURL(bundle).href);

const sqlFile = join(work, 'q.sql');
writeFileSync(sqlFile, "select id, city, original_url from public.jobs where source_id = 'arbeitnow' and country is null and city is not null and status = 'open'");
const raw = execFileSync('npx', ['supabase', 'db', 'query', '--linked', '-o', 'json', '-f', sqlFile], { cwd: join(root, '..'), encoding: 'utf8', shell: process.platform === 'win32', maxBuffer: 64 * 1024 * 1024 });
const rows = JSON.parse(raw.slice(raw.indexOf('{'))).rows;

const byCountry = new Map();
const byPlace = new Map();
for (const r of rows) {
  const code = arbeitnowStatedCountry(r.city, r.original_url);
  if (!code) continue;
  if (!byCountry.has(code)) byCountry.set(code, []);
  byCountry.get(code).push(r.id);
  const k = `${r.city.toLowerCase()} -> ${code}`;
  byPlace.set(k, (byPlace.get(k) ?? 0) + 1);
}
const q = (ids) => ids.map((i) => `'${i}'`).join(',');
let apply = 'begin;\n';
let undo = 'begin;\n';
for (const [code, ids] of byCountry) {
  apply += `update public.jobs set country = '${code}' where source_id = 'arbeitnow' and country is null and id in (${q(ids)});\n`;
  undo += `update public.jobs set country = null where source_id = 'arbeitnow' and country = '${code}' and id in (${q(ids)});\n`;
}
apply += 'commit;\n';
undo += 'commit;\n';
mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'apply.sql'), apply);
writeFileSync(join(outDir, 'undo.sql'), undo);
const total = [...byCountry.values()].reduce((n, a) => n + a.length, 0);
console.log(`candidatas=${rows.length} recuperadas=${total}`, Object.fromEntries([...byCountry].map(([c, a]) => [c, a.length])));
console.log([...byPlace].sort((a, b) => b[1] - a[1]).slice(0, 60).map(([k, n]) => `${n}  ${k}`).join('\n'));
void readFileSync;
