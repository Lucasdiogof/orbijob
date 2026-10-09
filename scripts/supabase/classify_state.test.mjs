import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { classify, parseInspection, MIGRATIONS } from './classify_state.mjs';

const load = (n) => JSON.parse(readFileSync(new URL(`./fixtures/${n}.json`, import.meta.url), 'utf8'));
const V = MIGRATIONS.map((m) => m.version);

test('fresh project is EMPTY and all six migrations are pending', () => {
  const r = classify(load('empty'));
  assert.equal(r.state, 'EMPTY');
  assert.equal(r.pending.length, 6);
  assert.equal(r.safeToPlan, true);
});

test('database that stops at migration 4 needs the corrective fifth and the service_role grants', () => {
  const r = classify(load('after-1-to-4'));
  assert.equal(r.state, 'CONSISTENT_PARTIAL');
  assert.deepEqual(r.pending, ['20261012000000_quota_upsert_fix', '20261013000000_service_role_grants']);
});

test('fully migrated database has nothing pending', () => {
  const r = classify(load('after-1-to-6'));
  assert.equal(r.state, 'CONSISTENT_UP_TO_DATE');
  assert.deepEqual(r.pending, []);
});

test('objects present but history empty (applied by hand) is DRIFT, not EMPTY', () => {
  const d = load('after-1-to-4');
  d.migration_versions = null;
  const r = classify(d);
  assert.equal(r.state, 'DRIFT');
  assert.equal(r.pending, null);
  assert.match(r.problems.join('\n'), /history does not list it/);
});

test('history claims a migration whose objects are missing is DRIFT', () => {
  const d = load('empty');
  d.migration_versions = V.slice(0, 2);
  const r = classify(d);
  assert.equal(r.state, 'DRIFT');
  assert.match(r.problems.join('\n'), /objects are missing/);
});

test('a foreign table in public makes the project non-empty', () => {
  const d = load('empty');
  d.public_tables.push({ name: 'someones_notes', rls: false, owner: 'postgres' });
  const r = classify(d);
  assert.equal(r.state, 'DRIFT');
  assert.match(r.problems.join('\n'), /someones_notes/);
});

test('unknown migration versions and out-of-order history are DRIFT', () => {
  const a = load('after-1-to-4');
  a.migration_versions = [...V.slice(0, 4), '20250101000000'];
  assert.equal(classify(a).state, 'DRIFT');
  const b = load('after-1-to-4');
  b.migration_versions = [V[1], V[0], V[2], V[3]];
  assert.equal(classify(b).state, 'DRIFT');
});

test('a pre-existing pg_trgm and old PostgreSQL only warn', () => {
  const d = load('empty');
  d.extensions.push({ name: 'pg_trgm', schema: 'public', version: '1.6' });
  d.server_version = '14.9';
  const r = classify(d);
  assert.equal(r.state, 'EMPTY');
  assert.equal(r.warnings.length >= 2, true);
});

test('only the quota function without the key argument counts as migration 4, not 5', () => {
  const d = load('after-1-to-4');
  assert.equal(d.public_functions.find((f) => f.name === 'enforce_row_quota').quota_has_key_arg, false);
});

// ── input shapes people really end up with after copying the SQL Editor result on Windows ──
const raw = () => readFileSync(new URL('./fixtures/after-1-to-5.json', import.meta.url), 'utf8');
const doc = () => JSON.parse(raw());

test('parseInspection accepts bare JSON, BOM, CRLF and surrounding whitespace', () => {
  assert.equal(parseInspection(raw()).format, 1);
  assert.equal(parseInspection('\uFEFF' + raw().replace(/\n/g, '\r\n') + '\r\n\r\n').format, 1);
});

test('parseInspection unwraps a CSV-quoted cell', () => {
  const csvCell = '"' + JSON.stringify(doc()).replace(/"/g, '""') + '"';
  assert.equal(parseInspection(csvCell).public_tables.length, doc().public_tables.length);
});

test('parseInspection unwraps the editor JSON export (string or object value)', () => {
  assert.equal(parseInspection(JSON.stringify([{ inspection: JSON.stringify(doc()) }])).format, 1);
  assert.equal(parseInspection(JSON.stringify([{ inspection: doc() }])).format, 1);
  assert.equal(parseInspection(JSON.stringify({ inspection: doc() })).format, 1);
});

test('parseInspection rejects anything that is not an inspection instead of guessing', () => {
  assert.throws(() => parseInspection('{"hello": 1}'), /not an OrbiJob inspection/);
  assert.throws(() => parseInspection('not json at all'));
  assert.throws(() => parseInspection(JSON.stringify([{ a: 1 }, { b: 2 }])), /not an OrbiJob inspection/);
});

test('the inspection document carries no credentials or row data (names and flags only)', () => {
  const text = raw();
  for (const needle of ['password', 'postgres://', 'eyJ', 'sb_secret', 'sb_publishable', '@']) {
    assert.equal(text.includes(needle), false, `fixture unexpectedly contains ${needle}`);
  }
});

// ── the first REAL inspection (owner-reported summary, 2026-10-09) ──
const real = () => JSON.parse(readFileSync(new URL('./fixtures/owner-reported-2026-10-09.json', import.meta.url), 'utf8'));

test('real project (PostgreSQL 17.11, no OrbiJob objects, null history) is EMPTY with its justification', () => {
  const r = classify(real());
  assert.equal(r.state, 'EMPTY');
  assert.equal(r.pending.length, 6);
  assert.match(r.evidence.join('\n'), /history table .* does not exist/);
  assert.match(r.evidence.join('\n'), /public tables: 0, policies: 0, triggers: 0, buckets: 0/);
});

test('the platform function rls_auto_enable is reported as an exception AND blocks "ready" until verified', () => {
  const r = classify(real());
  assert.equal(r.safeToPlan, true);
  assert.equal(r.problems.length, 0);
  assert.match(r.exceptions.join('\n'), /rls_auto_enable/);
  assert.match(r.blockers.join('\n'), /inspect_predeploy_details/);
});

test('the SQL Editor export of the real result (array with an "inspection" JSON string) is accepted', () => {
  const editorExport = JSON.stringify([{ inspection: JSON.stringify(real(), null, 4) }]);
  const r = classify(parseInspection(editorExport));
  assert.equal(r.state, 'EMPTY');
});

test('an unknown function in public is DRIFT, not silently accepted', () => {
  const d = real();
  d.public_functions.push({ name: 'someones_helper', security_definer: false, anon_can_execute: false, authenticated_can_execute: false, quota_has_key_arg: false });
  const r = classify(d);
  assert.equal(r.state, 'DRIFT');
  assert.match(r.problems.join('\n'), /someones_helper/);
});

test('null history is never read as "nothing applied" when OrbiJob objects exist', () => {
  const d = load('after-1-to-4');
  d.migration_versions = null;
  const r = classify(d);
  assert.equal(r.state, 'DRIFT');
});

test('unexpected default-privilege owners are surfaced as warnings', () => {
  const d = real();
  d.default_privileges_public.push({ owner: 'some_role', object_type: 'r', acl: 'x' });
  assert.match(classify(d).warnings.join('\n'), /some_role/);
});

test('an old PostgreSQL major version only warns, PostgreSQL 17 does not', () => {
  assert.equal(classify(real()).warnings.some((w) => /PostgreSQL/.test(w)), false);
  const d = real(); d.server_version = '14.2';
  assert.equal(classify(d).warnings.some((w) => /PostgreSQL 14/.test(w)), true);
});

// ── the REAL inspection taken right after migrations 1-5 were applied (2026-10-09, transcribed from the SQL Editor) ──
test('real project after migrations 1-5: consistent, only the service_role grants are pending', () => {
  const r = classify(JSON.parse(readFileSync(new URL('./fixtures/real-after-1-to-5-2026-10-09.json', import.meta.url), 'utf8')));
  assert.equal(r.state, 'CONSISTENT_PARTIAL');
  assert.deepEqual(r.pending, ['20261013000000_service_role_grants']);
  assert.deepEqual(r.problems, []);
});

test('service_role already reading the catalogue while the history lacks migration 6 is DRIFT (grant applied by hand)', () => {
  const d = JSON.parse(readFileSync(new URL('./fixtures/real-after-1-to-5-2026-10-09.json', import.meta.url), 'utf8'));
  d.public_grants.find((g) => g.role === 'service_role' && g.table === 'jobs').privileges.push('SELECT');
  const r = classify(d);
  assert.equal(r.state, 'DRIFT');
  assert.match(r.problems.join('\n'), /service_role_grants .* history does not list it/);
});
