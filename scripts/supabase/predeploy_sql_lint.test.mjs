import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (f) => readFileSync(new URL(f, import.meta.url), 'utf8');
const stripComments = (sql) => sql.replace(/--[^\n]*/g, '');

/** All calls of has_*_privilege()/pg_has_role() with their arguments split at depth 0. */
function privilegeCalls(sql) {
  const calls = [];
  const re = /\b(has_(?:schema|table|function|database)_privilege|pg_has_role)\s*\(/g;
  let m;
  while ((m = re.exec(sql))) {
    let depth = 1, i = re.lastIndex, cur = '', args = [], q = false;
    for (; i < sql.length && depth > 0; i++) {
      const c = sql[i];
      if (c === "'") q = !q;
      if (!q) {
        if (c === '(') depth++;
        if (c === ')') { depth--; if (depth === 0) break; }
        if (c === ',' && depth === 1) { args.push(cur.trim()); cur = ''; continue; }
      }
      cur += c;
    }
    args.push(cur.trim());
    calls.push({ fn: m[1], args });
  }
  return calls;
}

// The object argument (2nd) must be an OID taken from a catalog row or from to_reg*(), never a text name that could
// be '$user', a missing schema, or any value whose evaluation order the planner is free to choose.
const OID_ARG = /^(?:\w+\.oid|to_regclass\(.*\)|to_regprocedure\(.*\)|current_database\(\)|c\.relowner)$/;

test('inspect_predeploy_details.sql passes only OIDs (never text names) as the object of privilege functions', () => {
  const calls = privilegeCalls(stripComments(read('./inspect_predeploy_details.sql')));
  assert.ok(calls.length >= 8, 'the scan must actually find the calls');
  const bad = calls.filter((c) => !OID_ARG.test(c.args[1]));
  assert.deepEqual(bad.map((c) => `${c.fn}(${c.args.join(', ')})`), []);
});

test('the lint catches the original defective snippet', () => {
  const calls = privilegeCalls(stripComments(read('./fixtures/old_search_path_snippet.sql')));
  assert.equal(calls.length, 1);
  assert.equal(OID_ARG.test(calls[0].args[1]), false);
});

test('the role argument is resolved to an OID (NULL when the role is missing) instead of a literal name', () => {
  const calls = privilegeCalls(stripComments(read('./inspect_predeploy_details.sql')));
  for (const c of calls) {
    const role = c.args[0];
    assert.equal(/^'[^']+'$/.test(role), false, `${c.fn} receives the literal role ${role}`);
  }
});

test('no ::regclass/::regnamespace cast of an object that may be missing (casts are folded at plan time, CASE does not protect)', () => {
  for (const f of ['./inspect_predeploy_details.sql', './inspect_readonly.sql']) {
    const casts = [...stripComments(read(f)).matchAll(/'([\w.]+)'::reg(?:class|namespace)/g)].map((m) => m[1]);
    assert.deepEqual(casts.filter((n) => !['pg_proc', 'public'].includes(n)), [], f);
  }
});

test('search_path is read through current_schemas() and pg_namespace, never by splitting the setting text', () => {
  const sql = stripComments(read('./inspect_predeploy_details.sql'));
  assert.match(sql, /current_schemas\(false\)\s*\)?\s*with ordinality/i);
  assert.equal(/string_to_array\s*\(\s*replace\s*\(\s*current_setting\('search_path'\)/i.test(sql), false);
});
