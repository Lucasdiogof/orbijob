import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { FILES, toPaste } from './build_paste_variants.mjs';

const read = (f) => readFileSync(new URL(f, import.meta.url), 'utf8');

for (const [src, dst] of FILES) {
  test(`${dst} is up to date with ${src}`, () => assert.equal(read(`./${dst}`), toPaste(read(`./${src}`))));
  test(`${dst} is ONE plain statement: no comments, no transaction control, single trailing semicolon`, () => {
    const t = read(`./${dst}`);
    assert.equal(/--/.test(t), false);
    assert.equal(/\b(begin|rollback|commit|start transaction)\b/i.test(t), false);
    assert.equal((t.match(/;/g) ?? []).length, 1);
    assert.equal(t.trimEnd().endsWith(';'), true);
    assert.equal(/^select /.test(t), true);
    assert.equal(/\b(insert|update|delete|create|drop|alter|grant|revoke|truncate)\s/i.test(t.replace(/'[^']*'/g, "''")), false);
  });
}

test('the builder refuses a query that would be cut by a naive splitter', () => {
  assert.throws(() => toPaste('select 1; select 2;'), /exactly one statement/);
  assert.throws(() => toPaste('select 1 -- inline\n;'), /inline comment/);
});
