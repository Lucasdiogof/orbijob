// Backfill of the 13.0 personal-data guard (src/description.ts protectPersonalData) over the descriptions already stored: every source, every status that still
// has a text. Run from worker/ with the Supabase CLI linked to rpmlfxwebnlxnwadyvle. Applied on 2026-10-16 (1,519 descriptions); a re-run changes nothing.
//   npx vite-node scripts/backfill-personal-data.ts            dry run: counts per source, masked/kept samples (masked text only, never an original number)
//   npx vite-node scripts/backfill-personal-data.ts --apply    writes the masked descriptions in batches of 200 (one transaction each)
// No copy of the original texts is kept: the official listing (always linked) still has them, and a re-read of the source restores any text.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { protectPersonalData } from '../src/description';
import { MASKED_PHONE } from '../src/phones';

const apply = process.argv.includes('--apply');
const cli = (args: string[]) => execFileSync(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', 'npx', 'supabase', 'db', 'query', '--linked', ...args], { cwd: '..', encoding: 'utf8', maxBuffer: 1e9 });
const rowsOf = (out: string) => JSON.parse(out.slice(out.indexOf('{'))).rows as { id: string; source_id: string; country: string | null; description: string }[];

const FILTER = `coalesce(description,'') ~ '(\\+|\\m00|\\m0[1-9]|\\(\\d{3}\\)|\\m\\d{3}[.-]\\d{3}[.-]\\d{4}|@)'`;
const work = mkdtempSync(join(tmpdir(), 'orbijob-backfill-'));
const query = (sql: string) => { const f = join(work, 'q.sql'); writeFileSync(f, sql); return rowsOf(cli(['-o', 'json', '-f', f])); };

const changed: { id: string; source: string; text: string }[] = [];
const perSource = new Map<string, { rows: number; changed: number; masked: number }>();
const maskedSamples = new Map<string, string[]>();
let read = 0;
for (let last = '00000000-0000-0000-0000-000000000000'; ;) {
  const page = query(`select id::text, source_id, country, description from public.jobs where ${FILTER} and id > '${last}' order by id limit 400`);
  if (!page.length) break;
  last = page[page.length - 1]!.id;
  read += page.length;
  for (const r of page) {
    const s = perSource.get(r.source_id) ?? { rows: 0, changed: 0, masked: 0 };
    s.rows++;
    const out = protectPersonalData(r.description ?? '', r.country ?? null);
    if (out !== r.description) {
      s.changed++;
      const before = (r.description.match(/\[tel\.\]/g) ?? []).length;
      s.masked += (out.match(/\[tel\.\]/g) ?? []).length - before;
      changed.push({ id: r.id, source: r.source_id, text: out });
      const list = maskedSamples.get(r.source_id) ?? [];
      const k = out.indexOf(MASKED_PHONE);
      if (list.length < 3 && k >= 0) list.push(out.slice(Math.max(0, k - 60), k + 10).replace(/\s+/g, ' '));
      maskedSamples.set(r.source_id, list);
    }
    perSource.set(r.source_id, s);
  }
}
console.log(`candidate rows read: ${read}`);
for (const [src, s] of [...perSource].sort()) {
  console.log(`${src.padEnd(18)} rows=${s.rows} changed=${s.changed} numbers_masked=${s.masked}`);
  for (const x of maskedSamples.get(src) ?? []) console.log(`    … ${x}`);
}
console.log(`total rows to change: ${changed.length}`);

if (apply) {
  const lit = (s: string) => `'${s.replace(/'/g, "''")}'`;
  const dir = work;
  try {
    for (let i = 0; i < changed.length; i += 200) {
      const sql = `begin;\n${changed.slice(i, i + 200).map((c) => `update public.jobs set description = ${lit(c.text)} where id = '${c.id}';`).join('\n')}\ncommit;\n`;
      const f = join(dir, 'batch.sql');
      writeFileSync(f, sql); // masked texts only; deleted right after
      cli(['-f', f]);
      console.log(`applied ${Math.min(i + 200, changed.length)} / ${changed.length}`);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
} else {
  rmSync(work, { recursive: true, force: true });
}
