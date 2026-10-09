import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { classify, parseInspection, MIGRATIONS } from './classify_state.mjs';

const load = (n) => JSON.parse(readFileSync(new URL(`./fixtures/${n}.json`, import.meta.url), 'utf8'));
const V = MIGRATIONS.map((m) => m.version);

test('fresh project is EMPTY and all five migrations are pending', () => {
  const r = classify(load('empty'));
  assert.equal(r.state, 'EMPTY');
  assert.equal(r.pending.length, 5);
  assert.equal(r.safeToPlan, true);
});

test('database that stops at migration 4 needs only the corrective fifth', () => {
  const r = classify(load('after-1-to-4'));
  assert.equal(r.state, 'CONSISTENT_PARTIAL');
  assert.deepEqual(r.pending, ['20261012000000_quota_upsert_fix']);
});

test('fully migrated database has nothing pending', () => {
  const r = classify(load('after-1-to-5'));
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
