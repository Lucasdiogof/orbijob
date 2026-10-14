#!/usr/bin/env node
// Search benchmark against the titles of ONE source, read with the owner connection (works for a source that is stored but not yet published,
// such as mpsvcz). READ-ONLY. Prints SQL to stdout; run it with the Supabase CLI:
//   node scripts/search-benchmark-source.mjs <alternatives.json> <source_id> > bench.sql
//   npx supabase db query --linked -o csv -f bench.sql
// For each query: open jobs of the source whose title contains the query itself, and those whose title matches the query OR one of its
// alternatives (every part of an alternative inside the title, as in the app and in ops.alert_matches), plus three sample titles.
import { readFileSync } from 'node:fs';

const [, , altsFile, source] = process.argv;
if (!altsFile || !/^[a-z0-9_]+$/.test(source ?? '')) {
  console.error('usage: node scripts/search-benchmark-source.mjs <alternatives.json> <source_id>');
  process.exit(2);
}
const table = JSON.parse(readFileSync(altsFile, 'utf8'));
const lit = (s) => `'${String(s).replace(/'/g, "''")}'`;
const like = (p) => `title ilike ${lit(`%${p.replace(/[\\%_]/g, (c) => `\\${c}`)}%`)}`;
const alt = (a) => `(${a.map(like).join(' and ')})`;
const parts = [];
for (const [q, v] of Object.entries(table)) {
  const own = like(q.toLowerCase());
  const all = [own, ...(v.after ?? []).map(alt)].join(' or ');
  parts.push(`select ${lit(q)} as query,
    count(*) filter (where ${own}) as by_term,
    count(*) filter (where ${all}) as with_alternatives,
    (array_agg(title order by published_at desc nulls last) filter (where ${all}))[1:3] as samples
  from public.jobs where source_id = ${lit(source)} and status = 'open'`);
}
console.log(parts.join('\nunion all\n') + ';');
