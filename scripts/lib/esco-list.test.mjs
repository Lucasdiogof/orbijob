import assert from 'node:assert/strict';
import { test } from 'node:test';
import { listOccupations } from './esco-list.mjs';

const API = 'https://esco.test/api';
/** A fake ESCO search: `offset` is a page index; pages carry _links.next until the last (the contract observed on 2026-10-14). */
function fakeApi({ total = 250, limit = 100, repeatPage = null, lie = null, noNext = false } = {}) {
  const calls = [];
  const get = async (url) => {
    calls.push(url);
    const page = Number(new URL(url).searchParams.get('offset'));
    const shown = repeatPage !== null && page === repeatPage + 1 ? repeatPage : page;
    const from = shown * limit;
    const results = Array.from({ length: Math.max(0, Math.min(limit, total - from)) }, (_, i) => ({ uri: `u${from + i}`, title: `t${from + i}` }));
    const last = from + limit >= total;
    return {
      total: lie ?? total,
      _embedded: { results },
      _links: last || noNext ? {} : { next: { href: `/search?type=occupation&limit=${limit}&offset=${page + 1}&full=false` } },
    };
  };
  return { get, calls };
}

test('follows the pages by index until the last one and returns every occupation once', async () => {
  const api = fakeApi({ total: 250 });
  const list = await listOccupations(API, api.get);
  assert.equal(list.length, 250);
  assert.equal(new Set(list.map((o) => o.uri)).size, 250);
  assert.deepEqual(api.calls.map((u) => new URL(u).searchParams.get('offset')), ['0', '1', '2']);
});

test('a page that repeats the previous one ends the walk and the short result is refused', async () => {
  const api = fakeApi({ total: 300, repeatPage: 0 });
  await assert.rejects(listOccupations(API, api.get), /truncated: 100 of 300/);
});

test('a list shorter than the announced total is refused (a missing next link)', async () => {
  const api = fakeApi({ total: 250, noNext: true });
  await assert.rejects(listOccupations(API, api.get), /truncated: 100 of 250/);
});

test('the old row-offset loop would have read one page: the guard catches any truncation', async () => {
  const api = fakeApi({ total: 2942 });
  const list = await listOccupations(API, api.get);
  assert.equal(list.length, 2942);
  assert.equal(api.calls.length, 30);
});
