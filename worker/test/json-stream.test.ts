import { describe, expect, it } from 'vitest';
import { arrayItems } from '../src/json-stream';

/** A ReadableStream of [text] split into chunks of [size] BYTES (so multi-byte characters are cut in the middle). */
function stream(text: string, size: number): ReadableStream<Uint8Array> {
  const bytes = new TextEncoder().encode(text);
  let pos = 0;
  return new ReadableStream({
    pull(controller) {
      if (pos >= bytes.length) return controller.close();
      controller.enqueue(bytes.slice(pos, pos + size));
      pos += size;
    },
  });
}
const collect = async (s: ReadableStream<Uint8Array>, key = 'polozky') => {
  const out: string[] = [];
  for await (const it of arrayItems(s, key)) out.push(it);
  return out;
};

describe('arrayItems (streaming split of one big JSON array)', () => {
  const doc = JSON.stringify({ polozky: [{ a: 1, s: 'x}y{"z\\"]' }, { nested: { b: [1, { c: 'ř' }] } }, { t: 'Svářeč €' }], other: [1, 2] }, null, 2);

  it('yields each element, whatever the chunk size, including chunks that cut a multi-byte character', async () => {
    for (const size of [1, 2, 3, 7, 64, 100000]) {
      const items = await collect(stream(doc, size));
      expect(items.map((x) => JSON.parse(x))).toEqual([{ a: 1, s: 'x}y{"z\\"]' }, { nested: { b: [1, { c: 'ř' }] } }, { t: 'Svářeč €' }]);
    }
  });

  it('ignores braces and brackets inside strings and escaped quotes', async () => {
    const items = await collect(stream('{"polozky":[{"s":"}]\\"{["},{"s":"\\\\"}]}', 5));
    expect(items.map((x) => JSON.parse(x).s)).toEqual(['}]"{[', '\\']);
  });

  it('skips what comes before and after the array, and an empty array yields nothing', async () => {
    expect(await collect(stream('{"meta":{"polozky_count":2},"polozky":[],"x":[{"no":1}]}', 4))).toEqual([]);
    expect((await collect(stream('{"a":[{"x":1}],"polozky":[{"y":2}],"b":[{"z":3}]}', 4))).map((x) => JSON.parse(x))).toEqual([{ y: 2 }]);
  });

  it('stops reading as soon as the array is closed', async () => {
    let pulls = 0;
    const s = new ReadableStream<Uint8Array>({
      pull(c) {
        pulls++;
        c.enqueue(new TextEncoder().encode(pulls === 1 ? '{"polozky":[{"a":1}]}' : 'garbage'));
        if (pulls > 5) c.close();
      },
    });
    expect(await collect(s)).toEqual(['{"a":1}']);
    expect(pulls).toBeLessThanOrEqual(2);
  });

  it('fails loudly on a document without the key and on one cut inside an element', async () => {
    await expect(collect(stream('{"other":[{"a":1}]}', 8))).rejects.toThrow(/not found/);
    await expect(collect(stream('{"polozky":[{"a":1},{"b":', 8))).rejects.toThrow(/before the array was closed/);
  });

  it('handles a large array in bounded memory (200,000 elements)', async () => {
    const chunk = '{"id":1,"t":"Řidič","d":"abc"},';
    let n = 0;
    const s = new ReadableStream<Uint8Array>({
      start(c) {
        c.enqueue(new TextEncoder().encode('{"polozky":['));
      },
      pull(c) {
        if (n < 2000) {
          c.enqueue(new TextEncoder().encode(chunk.repeat(100)));
          n++;
        } else {
          c.enqueue(new TextEncoder().encode('{"id":0}]}'));
          c.close();
        }
      },
    });
    let count = 0;
    for await (const it of arrayItems(s, 'polozky')) {
      if (count === 0) expect(JSON.parse(it).id).toBe(1);
      count++;
    }
    expect(count).toBe(200_001);
  });
});
