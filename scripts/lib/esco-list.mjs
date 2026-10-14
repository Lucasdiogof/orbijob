// The ESCO occupation list, paginated the way the live API works (see scripts/esco-fetch.mjs). Pure: the HTTP getter is injected.
export async function listOccupations(API, get, pause = async () => {}) {
  const seen = new Map();
  let total = null;
  let url = `${API}/search?type=occupation&language=en&limit=100&offset=0&full=false`;
  for (let page = 0; url && page < 200; page++) {
    const j = await get(url);
    total ??= Number(j.total);
    const res = j._embedded?.results ?? [];
    const before = seen.size;
    for (const x of res) if (x?.uri && !seen.has(x.uri)) seen.set(x.uri, { uri: x.uri, title: x.title });
    if (res.length === 0 || seen.size === before) break; // past the end, or a page repeating the previous one
    const next = j._links?.next?.href;
    url = next ? (next.startsWith('http') ? next : `${API}${next.startsWith('/') ? '' : '/'}${next}`) : null;
    await pause();
  }
  const list = [...seen.values()];
  if (!Number.isFinite(total) || list.length < total) throw new Error(`occupation list truncated: ${list.length} of ${total}`);
  return list;
}

