/**
 * Streams the records of a delimited text file (RFC 4180 quoting: a quoted field may hold the delimiter, line breaks and doubled quotes)
 * without holding the file in memory: the open data files read here are over 100 MB. Yields one array of fields per record; a trailing
 * carriage return is dropped, an empty last line is ignored.
 */
export async function* csvRecords(body: ReadableStream<Uint8Array>, delimiter = ','): AsyncGenerator<string[]> {
  const decoder = new TextDecoder('utf-8');
  const reader = body.getReader();
  let row: string[] = [];
  let field = '';
  let quoted = false;
  let fieldStarted = false;
  let pendingQuote = false; // a quote seen inside a quoted field: either the end of the field or the first half of a doubled quote
  let first = true;
  const endField = () => { row.push(field); field = ''; fieldStarted = false; };
  for (;;) {
    const { value, done } = await reader.read();
    let text = done ? decoder.decode() : decoder.decode(value, { stream: true });
    if (first && text) { if (text.charCodeAt(0) === 0xfeff) text = text.slice(1); first = false; }
    const out: string[][] = [];
    for (let i = 0; i < text.length; i++) {
      const c = text[i]!;
      if (pendingQuote) {
        pendingQuote = false;
        if (c === '"') { field += '"'; continue; }
        quoted = false; // the quote closed the field: fall through to read c unquoted
      }
      if (quoted) {
        if (c === '"') pendingQuote = true;
        else field += c;
        continue;
      }
      if (c === '"' && !fieldStarted) { quoted = true; fieldStarted = true; continue; }
      if (c === delimiter) { endField(); continue; }
      if (c === '\n') {
        if (field.endsWith('\r')) field = field.slice(0, -1);
        endField();
        out.push(row);
        row = [];
        continue;
      }
      field += c;
      fieldStarted = true;
    }
    for (const r of out) yield r;
    if (done) break;
  }
  if (pendingQuote) quoted = false;
  if (field !== '' || row.length) {
    if (field.endsWith('\r')) field = field.slice(0, -1);
    endField();
    yield row;
  }
}
