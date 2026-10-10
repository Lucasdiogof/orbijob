#!/usr/bin/env node
// Plano de correção dos registros do Jobicy já gravados (descrições). SOMENTE LEITURA: lê as linhas pela CLI do Supabase já logada
// (um SELECT), calcula o plano com as mesmas regras da importação e GERA um arquivo SQL para revisão. Nunca executa o SQL.
//
//   node scripts/jobicy-quality-plan.mjs [--out DIR] [--source-geo arquivo.json]
//
// --out         pasta de saída (padrão: <tmp>/orbijob-quality-plan). Fora do repositório; contém o texto novo das descrições.
// --source-geo  {"<external_id>": "<jobGeo publicado pela fonte>"}: evidência para marcar "Anywhere". Sem ela, nenhuma linha de
//               localização é alterada.
// Salários NUNCA são alterados: os suspeitos só são listados (o valor certo tem de vir da fonte).
import { build } from 'esbuild';
import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const opt = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : undefined; };
const outDir = opt('--out') ?? join(tmpdir(), 'orbijob-quality-plan');
const sourceGeo = opt('--source-geo') ? JSON.parse(readFileSync(opt('--source-geo'), 'utf8')) : {};
const SOURCE_ID = 'jobicy';

// Rows come from the CLI that is already logged in (read-only SELECT; no key is read or printed).
const SELECT = `select external_id, description, md5(description) as description_md5, geo_restrictions, country,
  salary_min::float8 as salary_min, salary_max::float8 as salary_max, salary_currency, salary_period
  from public.jobs where source_id = '${SOURCE_ID}' order by external_id`;
mkdirSync(outDir, { recursive: true });
const selectFile = join(outDir, 'select-rows.sql'); // a file instead of an argument: no shell quoting involved
writeFileSync(selectFile, SELECT);
const cli = spawnSync('npx', ['supabase', 'db', 'query', '--linked', '-f', selectFile], { cwd: fileURLToPath(new URL('../../', import.meta.url)), encoding: 'utf8', shell: process.platform === 'win32', maxBuffer: 256 * 1024 * 1024 });
if (cli.status !== 0) { console.error('PARE: a CLI do Supabase não conseguiu ler (login/vínculo).'); process.exit(1); }
const text = cli.stdout.slice(cli.stdout.indexOf('{'));
const rows = JSON.parse(text).rows.map((r) => ({ ...r, geo_restrictions: r.geo_restrictions ?? [] }));

const bundle = await build({
  entryPoints: [fileURLToPath(new URL('../src/quality-plan.ts', import.meta.url))],
  bundle: true, write: false, format: 'esm', platform: 'node', target: 'node20',
});
const mod = await import('data:text/javascript;base64,' + Buffer.from(bundle.outputFiles[0].text).toString('base64'));

const plan = mod.buildPlan(rows, sourceGeo);
mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'quality-fix.sql'), mod.renderSql(plan, SOURCE_ID));
writeFileSync(join(outDir, 'quality-plan.json'), JSON.stringify({ ...plan, description: plan.description.map(({ after, ...c }) => c) }, null, 1));
console.log(mod.renderReport(plan));
console.log(`\nSQL para revisão (NÃO executado): ${join(outDir, 'quality-fix.sql')}`);
