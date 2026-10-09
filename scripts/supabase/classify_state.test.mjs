import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { classify, MIGRATIONS } from './classify_state.mjs';

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
