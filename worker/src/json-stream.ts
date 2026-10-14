/**
 * Reads ONE big JSON array of objects without ever holding the whole document: yields the raw text of each element of the array stored under
 * [key] of the top-level object (`{ "polozky": [ {...}, {...} ] }`), one at a time, so a 190 MB file costs a few MB of memory. Braces and
 * brackets inside strings (with escapes) are ignored; UTF-8 sequences split across chunks are decoded correctly.
 *
 * It is a splitter, not a validator: every yielded string is passed to JSON.parse by the caller, which decides what a broken element means.
 * Anything before the array and after it is skipped. Throws when the key is never found or the document ends inside an element.
 */
export async function* arrayItems(body: ReadableStream<Uint8Array>, key: string): AsyncGenerator<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder('utf-8');
  const marker = JSON.stringify(key);
  let tail = ''; // while searching for the key: the last characters seen
  let sawKey = false;
  let inArray = false;
  let finished = false; // the array was closed: ignore the rest of the document
  let depth = 0; // nesting inside the element being read (0 = between elements)
  let inString = false;
  let escaped = false;
  let item = '';

  function* feed(text: string): Generator<string> {
    for (let i = 0; i < text.length && !finished; i++) {
      const c = text[i]!;
      if (!inArray) {
        if (!sawKey) {
          tail = (tail + c).slice(-marker.length);
          if (tail === marker) sawKey = true;
        } else if (c === '[') {
          inArray = true;
        } else if (c !== ':' && c !== ' ' && c !== '\n' && c !== '\r' && c !== '\t') {
          sawKey = false; // the key named something that is not an array: keep looking
          tail = '';
        }
        continue;
      }
      if (depth === 0) {
        if (c === '{' || c === '[') {
          depth = 1;
          item = c;
        } else if (c === ']') {
          finished = true;
        }
        continue;
      }
      item += c;
      if (inString) {
        if (escaped) escaped = false;
        else if (c === '\\') escaped = true;
        else if (c === '"') inString = false;
      } else if (c === '"') {
        inString = true;
      } else if (c === '{' || c === '[') {
        depth++;
      } else if (c === '}' || c === ']') {
        depth--;
        if (depth === 0) {
          const done = item;
          item = '';
          yield done;
        }
      }
    }
  }

  try {
    while (!finished) {
      const { value, done } = await reader.read();
      if (done) break;
      yield* feed(decoder.decode(value, { stream: true }));
    }
    if (!finished) yield* feed(decoder.decode());
  } finally {
    await reader.cancel().catch(() => undefined);
  }
  if (!sawKey) throw new Error(`json-stream: key ${key} not found`);
  if (!finished) throw new Error('json-stream: the document ended before the array was closed');
}
