#!/usr/bin/env node
// Builds the "paste" variants of the read-only inspection queries for the Supabase SQL Editor:
// the same single SELECT, without comments, blank lines or BEGIN/ROLLBACK. Reason: the editor reported
// "42601: syntax error at end of input" for the commented, transaction-wrapped file; a single plain statement leaves
// nothing for a client-side splitter or a partial selection to cut in the wrong place.
//   node scripts/supabase/build_paste_variants.mjs           writes inspect_*.paste.sql
//   node scripts/supabase/build_paste_variants.mjs --check   fails if the committed files are stale
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const here = (f) => fileURLToPath(new URL(f, import.meta.url));
export const FILES = [
  ['inspect_readonly.sql', 'inspect_readonly.paste.sql'],
  ['inspect_predeploy_details.sql', 'inspect_predeploy_details.paste.sql'],
];

// 01_audit.sql is a DO block plus one SELECT (two statements) and starts with a psql meta-command the SQL Editor cannot
// parse (\set ON_ERROR_STOP). The paste variant drops that line and the comments; it must stay strictly read-only.
export const AUDIT = ['../../supabase/tests/01_audit.sql', '../../supabase/tests/01_audit.paste.sql'];
export function toAuditPaste(sql) {
  const out = sql.split('\n')
    .filter((l) => !l.trim().startsWith('--') && !l.trim().startsWith('\\') && l.trim() !== '')
    .join('\n') + '\n';
  if (/--/.test(out)) throw new Error('inline comment left in the audit: refusing to build a paste variant');
  const code = out.replace(/'[^']*'/g, "''");
  if (/\b(insert|update|delete|create|drop|alter|grant|revoke|truncate|copy|set|reset)\b/i.test(code.replace(/\bset_limit\b/g, ''))) throw new Error('the audit must stay read-only');
  return out;
}

export function toPaste(sql) {
  const lines = sql.split('\n')
    .filter((l) => !l.trim().startsWith('--'))
    .filter((l) => l.trim() !== '')
    .filter((l) => !/^\s*(begin read only|rollback);\s*$/i.test(l));
  const out = lines.join('\n') + '\n';
  if (/--/.test(out)) throw new Error('inline comment left in the query: refusing to build a paste variant');
  if ((out.match(/;/g) ?? []).length !== 1 || !out.trimEnd().endsWith(';')) throw new Error('paste variant must be exactly one statement');
  return out;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  let stale = false;
  {
    const built = toAuditPaste(readFileSync(here(AUDIT[0]), 'utf8'));
    if (process.argv.includes('--check')) {
      let cur = ''; try { cur = readFileSync(here(AUDIT[1]), 'utf8'); } catch { /* missing */ }
      if (cur !== built) { console.error(`STALE: ${AUDIT[1]}`); stale = true; }
    } else { writeFileSync(here(AUDIT[1]), built); console.log(`wrote ${AUDIT[1]}`); }
  }
  for (const [src, dst] of FILES) {
    const built = toPaste(readFileSync(here(src), 'utf8'));
    if (process.argv.includes('--check')) {
      let cur = ''; try { cur = readFileSync(here(dst), 'utf8'); } catch { /* missing */ }
      if (cur !== built) { console.error(`STALE: ${dst} (run build_paste_variants.mjs)`); stale = true; }
    } else { writeFileSync(here(dst), built); console.log(`wrote ${dst} (${built.length} bytes, ${built.split('\n').length - 1} lines)`); }
  }
  process.exit(stale ? 1 : 0);
}
