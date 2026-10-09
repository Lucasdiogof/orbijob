import { describe, expect, it } from 'vitest';
import { normalizeJobicy } from '../src/connectors/jobicy';
import { HttpError } from '../src/http';
import { SupabaseJobStore, chunkRows, isJwt } from '../src/store/supabase';
import { toJobRow } from '../src/sync';
import feed from './fixtures/jobicy-feed.sanitized.json';

const KEY = 'service-role-key-for-tests-only';
const rows = (feed.jobs as unknown[]).map((raw) => { const r = normalizeJobicy(raw, '2026-10-09T23:30:00.000Z'); if (!r.ok) throw new Error(r.reason); return toJobRow(r.job); });

interface Call { url: string; method: string; headers: Record<string, string>; body: unknown }
function recorder(respond: (c: Call) => Response = () => new Response(null, { status: 201 })) {
  const calls: Call[] = [];
  const f = (async (url: string, init: RequestInit) => {
    const c: Call = { url, method: init.method!, headers: init.headers as Record<string, string>, body: init.body ? JSON.parse(init.body as string) : undefined };
    calls.push(c);
    return respond(c);
  }) as unknown as typeof fetch;
  return { calls, store: new SupabaseJobStore('https://example.supabase.co/', KEY, f) };
}

describe('SupabaseJobStore (request contract, no network)', () => {
  it('upserts jobs on (source_id, external_id) with merge-duplicates and the service key', async () => {
    const { calls, store } = recorder();
    await store.upsertJobs(rows);
    expect(calls).toHaveLength(1);
    expect(calls[0]).toMatchObject({ method: 'POST', url: 'https://example.supabase.co/rest/v1/jobs?on_conflict=source_id,external_id' });
    expect(calls[0]!.headers).toMatchObject({ apikey: KEY, Prefer: 'resolution=merge-duplicates,return=minimal' });
    expect(calls[0]!.body).toEqual(rows);
  });

  it('sends at most 100 rows per request', async () => {
    const { calls, store } = recorder();
    await store.upsertJobs(Array.from({ length: 230 }, (_, i) => ({ ...rows[0]!, external_id: String(i) })));
    expect(calls.map((c) => (c.body as unknown[]).length)).toEqual([100, 100, 30]);
  });

  it('lists open ids for one source, page by page', async () => {
    let n = 0;
    const { calls, store } = recorder(() => {
      const page = n++ === 0 ? Array.from({ length: 1000 }, (_, i) => ({ external_id: String(i) })) : [{ external_id: 'last' }];
      return new Response(JSON.stringify(page), { status: 200 });
    });
    const ids = await store.listOpenExternalIds('jobicy');
    expect(ids).toHaveLength(1001);
    expect(calls[0]!.url).toContain('select=external_id&source_id=eq.jobicy&status=eq.open');
    expect(calls[0]!.url).toContain('limit=1000&offset=0');
    expect(calls[1]!.url).toContain('offset=1000');
  });

  it('closes by source and id list with a PATCH', async () => {
    const { calls, store } = recorder();
    await store.markClosed('jobicy', ['1', '22']);
    expect(calls[0]).toMatchObject({ method: 'PATCH' });
    expect(decodeURIComponent(calls[0]!.url)).toContain('source_id=eq.jobicy&external_id=in.("1","22")');
    expect(calls[0]!.body).toMatchObject({ status: 'closed' });
  });

  it('a quote inside an id cannot break out of the filter', async () => {
    const { calls, store } = recorder();
    await store.markClosed('jobicy', ['1"),source_id.neq.x']);
    expect(decodeURIComponent(calls[0]!.url)).toContain('external_id=in.("1),source_id.neq.x")');
  });

  it('records a run as counts only', async () => {
    const { calls, store } = recorder();
    await store.recordRun({ source_id: 'jobicy', scope: '', started_at: 'a', finished_at: 'b', status: 'ok', fetched: 1, upserted: 1, duplicates: 0, closed: 0, http_errors: 0, error_class: null });
    expect(calls[0]).toMatchObject({ method: 'POST', url: 'https://example.supabase.co/rest/v1/sync_runs' });
  });

  it('turns a failure into HttpError with only the status: the response body and the key never surface', async () => {
    const { store } = recorder(() => new Response(JSON.stringify({ message: `bad row ${rows[0]!.title} ${KEY}` }), { status: 403, headers: { 'retry-after': '2' } }));
    const err = await store.upsertJobs(rows).catch((e) => e as HttpError);
    expect(err).toBeInstanceOf(HttpError);
    expect(err).toMatchObject({ status: 403, retryAfterMs: 2000 });
    expect(String((err as Error).message) + JSON.stringify(err)).not.toContain(KEY);
    expect((err as Error).message).toBe('HTTP 403');
  });

  it('refuses a URL that would send the service key in clear text or to a place with credentials', () => {
    const f = (async () => new Response(null, { status: 201 })) as unknown as typeof fetch;
    for (const bad of ['http://example.supabase.co', 'ftp://example.supabase.co', 'https://user:pw@example.supabase.co', 'not a url', '', 'http://localhost.evil.test']) {
      expect(() => new SupabaseJobStore(bad, KEY, f), bad).toThrow(/SupabaseJobStore/);
    }
    for (const ok of ['https://example.supabase.co', 'https://example.supabase.co/', 'http://localhost:3000', 'http://127.0.0.1:54321']) {
      expect(() => new SupabaseJobStore(ok, KEY, f), ok).not.toThrow();
    }
  });

  it('the error for a bad URL never contains the key', () => {
    try { new SupabaseJobStore('http://evil.test', KEY); } catch (e) { expect(String(e)).not.toContain(KEY); }
  });

  it('splits by size as well as by count, keeping order and every row', () => {
    const big = (i: number) => ({ ...rows[0]!, external_id: String(i), description: 'x'.repeat(150_000) });
    const input = [0, 1, 2, 3, 4].map(big);
    const chunks = chunkRows(input);
    expect(chunks.map((c) => c.length)).toEqual([2, 2, 1]);
    expect(chunks.flat().map((r) => r.external_id)).toEqual(['0', '1', '2', '3', '4']);
    expect(chunkRows(rows)).toHaveLength(1); // the real sanitized fixture fits in one request
    expect(chunkRows([])).toEqual([]);
  });

  it('a single row bigger than the limit is still sent (alone), never dropped', () => {
    const huge = { ...rows[0]!, description: 'x'.repeat(900_000) };
    expect(chunkRows([huge, rows[1]!]).map((c) => c.length)).toEqual([1, 1]);
  });

  it('a new-style secret key goes ONLY in apikey; a JWT key also goes in Authorization', async () => {
    const send = async (key: string) => {
      const { calls, store } = (() => {
        const calls: Call[] = [];
        const f = (async (url: string, init: RequestInit) => (calls.push({ url, method: init.method!, headers: init.headers as Record<string, string>, body: undefined }), new Response(null, { status: 201 }))) as unknown as typeof fetch;
        return { calls, store: new SupabaseJobStore('https://example.supabase.co', key, f) };
      })();
      await store.recordRun({ source_id: 'jobicy', scope: '', started_at: 'a', finished_at: 'b', status: 'ok', fetched: 0, upserted: 0, duplicates: 0, closed: 0, http_errors: 0, error_class: null });
      return calls[0]!.headers;
    };
    const secret = await send('sb_secret_abcdefghijklmnopqrstuvwxyz0123456789');
    expect(secret.apikey).toBe('sb_secret_abcdefghijklmnopqrstuvwxyz0123456789');
    expect(Object.keys(secret)).not.toContain('Authorization');
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.c2ln';
    const legacy = await send(jwt);
    expect(legacy).toMatchObject({ apikey: jwt, Authorization: `Bearer ${jwt}` });
    expect(isJwt(jwt)).toBe(true);
    expect(isJwt('sb_secret_x')).toBe(false);
    expect(isJwt('eyJhbGci.only.two')).toBe(true); // shape check only: PostgREST/Supabase verify the signature
    expect(isJwt('not-a-jwt')).toBe(false);
  });
});
