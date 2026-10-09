import { describe, expect, it } from 'vitest';
import { jobicyConnector } from '../src/connectors/jobicy';
import { runSync, toJobRow, type JobRow, type JobStore, type SyncRunRow } from '../src/sync';
import feed from './fixtures/jobicy-feed.sanitized.json';

const NOW = new Date('2026-10-09T23:30:00.000Z');
const jobs = feed.jobs as Record<string, unknown>[];

/** In-memory JobStore with the same upsert semantics as the table (unique source_id + external_id). */
class MemoryStore implements JobStore {
  rows = new Map<string, JobRow>();
  runs: SyncRunRow[] = [];
  calls = { upsert: 0, listOpen: 0, markClosed: 0 };
  failRecord = false;
  failUpsert = false;
  async upsertJobs(rows: JobRow[]) {
    this.calls.upsert++;
    if (this.failUpsert) throw new Error('db down');
    for (const r of rows) this.rows.set(`${r.source_id}:${r.external_id}`, { ...r });
  }
  async listOpenExternalIds(source: string) {
    this.calls.listOpen++;
    return [...this.rows.values()].filter((r) => r.source_id === source && r.status === 'open').map((r) => r.external_id);
  }
  async markClosed(source: string, ids: string[]) {
    this.calls.markClosed++;
    for (const id of ids) { const r = this.rows.get(`${source}:${id}`); if (r) r.status = 'closed'; }
  }
  async recordRun(run: SyncRunRow) {
    if (this.failRecord) throw new Error('db down');
    this.runs.push(run);
  }
}

const res = (status: number, body: unknown = {}, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers });
const feedPage = (js: unknown[], next: string | null) => ({ success: true, statusCode: 200, jobs: js, nextCursor: next, hasMore: !!next });
const statusBody = (m: Record<string, string>) => ({ success: true, jobs: Object.entries(m).map(([id, status]) => ({ id: Number(id), status })) });

const noSleep = { sleep: async () => {}, retry: { retries: 3, baseMs: 1, maxMs: 1, random: () => 1 } };

/** Router over fake fetch: feed pages by cursor, status endpoint, with a call log. */
function fakeApi(opts: { pages?: unknown[][]; status?: (ids: string[]) => Response; feedError?: (call: number, cursor: string | null) => Response | null } = {}) {
  const pages = opts.pages ?? [jobs.slice(0, 5), jobs.slice(5)];
  const log: string[] = [];
  let feedCalls = 0;
  const f = (async (u: string) => {
    const url = new URL(u);
    log.push(url.pathname + (url.searchParams.get('cursor') ? `?cursor=${url.searchParams.get('cursor')}` : ''));
    if (url.pathname.endsWith('/status')) return opts.status ? opts.status(url.searchParams.get('ids')!.split(',')) : res(200, statusBody({}));
    const cursor = url.searchParams.get('cursor');
    const err = opts.feedError?.(feedCalls++, cursor);
    if (err) return err;
    const i = cursor ? Number(cursor.replace('C', '')) : 0;
    return res(200, feedPage(pages[i] ?? [], i + 1 < pages.length ? `C${i + 1}` : null));
  }) as unknown as typeof fetch;
  return { f, log };
}

const sync = (store: MemoryStore, f: typeof fetch, extra: Record<string, unknown> = {}) =>
  runSync({ connector: jobicyConnector(f, () => NOW), store, now: () => NOW, ...noSleep, ...extra });

describe('runSync: happy path and pagination', () => {
  it('walks every page in order, stores each job once and records the run', async () => {
    const api = fakeApi(); const store = new MemoryStore();
    const s = await sync(store, api.f);
    expect(api.log).toEqual(['/api/v2/remote-jobs', '/api/v2/remote-jobs?cursor=C1']);
    expect(s).toMatchObject({ status: 'ok', pages: 2, fetched: 10, upserted: 10, duplicates: 0, rejected: 0, closed: 0, http_errors: 0, error_class: null, runRecorded: true });
    expect(store.rows.size).toBe(10);
    expect(store.runs).toEqual([{ source_id: 'jobicy', scope: '', started_at: NOW.toISOString(), finished_at: NOW.toISOString(), status: 'ok', fetched: 10, upserted: 10, duplicates: 0, closed: 0, http_errors: 0, error_class: null }]);
  });

  it('paces consecutive page requests with the connector interval', async () => {
    const sleeps: number[] = [];
    await sync(new MemoryStore(), fakeApi().f, { sleep: async (ms: number) => void sleeps.push(ms) });
    expect(sleeps.some((ms) => ms > 900 && ms <= 1000)).toBe(true);
  });

  it('passes the scope to the source and records it', async () => {
    const store = new MemoryStore(); let seen = '';
    const f = (async (u: string) => (seen = u, res(200, feedPage([], null)))) as unknown as typeof fetch;
    await sync(store, f, { scope: 'geo=usa' });
    expect(seen).toContain('geo=usa');
    expect(store.runs[0]!.scope).toBe('geo=usa');
  });

  it('stops at the page cap and reports a partial pass instead of looping', async () => {
    const f = (async () => res(200, feedPage([jobs[0]], 'MORE'))) as unknown as typeof fetch;
    const store = new MemoryStore();
    const s = await sync(store, f, { maxPages: 3 });
    expect(s).toMatchObject({ status: 'partial', pages: 3, error_class: 'max_pages' });
    expect(store.calls.listOpen).toBe(0); // an incomplete traversal never reaches closure
  });
});

describe('runSync: stored rows', () => {
  it('keeps source, attribution URL and only documented values', async () => {
    const store = new MemoryStore();
    await sync(store, fakeApi().f);
    for (const r of store.rows.values()) {
      expect(r.source_id).toBe('jobicy');
      expect(new URL(r.original_url).hostname).toBe('jobicy.com');
      expect(r.apply_url).toBe(r.original_url);
      expect(r.work_mode).toBe('remote');
      expect(r.status).toBe('open');
      expect(r.fingerprint.length).toBeGreaterThan(0);
      expect(r.canonical_url).toMatch(/^https:\/\/jobicy\.com\/jobs\//);
    }
    const r = store.rows.get('jobicy:154956')!;
    expect(r).toMatchObject({ company: 'Juniper Square', country: 'US', salary_min: 120000, salary_max: 145000, salary_currency: 'USD', salary_period: 'year', geo_restrictions: ['US'] });
  });

  it('is idempotent: running the same pass again leaves identical rows and the same count', async () => {
    const store = new MemoryStore();
    await sync(store, fakeApi().f);
    const first = JSON.stringify([...store.rows.entries()].sort());
    const s2 = await sync(store, fakeApi().f);
    expect(store.rows.size).toBe(10);
    expect(JSON.stringify([...store.rows.entries()].sort())).toBe(first);
    expect(s2).toMatchObject({ status: 'ok', upserted: 10, duplicates: 0, closed: 0 });
  });

  it('an update on the source overwrites the stored row (same id)', async () => {
    const store = new MemoryStore();
    await sync(store, fakeApi().f);
    const changed = jobs.map((j) => (j.id === 154956 ? { ...j, jobTitle: 'Renamed role' } : j));
    await sync(store, fakeApi({ pages: [changed] }).f);
    expect(store.rows.get('jobicy:154956')!.title).toBe('Renamed role');
    expect(store.rows.size).toBe(10);
  });

  it('a job that was closed and shows up in the feed again is reopened', async () => {
    const store = new MemoryStore();
    await sync(store, fakeApi().f);
    store.rows.get('jobicy:154956')!.status = 'closed';
    await sync(store, fakeApi().f);
    expect(store.rows.get('jobicy:154956')!.status).toBe('open');
  });
});

describe('runSync: duplicates and invalid records', () => {
  it('the same id on two pages is stored once and counted as a duplicate', async () => {
    const store = new MemoryStore();
    const s = await sync(store, fakeApi({ pages: [jobs.slice(0, 5), [jobs[0], ...jobs.slice(5)]] }).f);
    expect(s).toMatchObject({ fetched: 11, upserted: 10, duplicates: 1 });
    expect(store.rows.size).toBe(10);
  });

  it('two different ids for the same company, title and place are one job', async () => {
    const twin = { ...jobs[0], id: 999001, url: 'https://jobicy.com/jobs/999001-twin' };
    const s = await sync(new MemoryStore(), fakeApi({ pages: [[jobs[0], twin]] }).f);
    expect(s).toMatchObject({ upserted: 1, duplicates: 1 });
  });

  it('listings without a company are never merged just because the title matches', async () => {
    const a = { id: 1, jobTitle: 'Barista', url: 'https://jobicy.com/jobs/1-barista', companyName: '' };
    const b = { id: 2, jobTitle: 'Barista', url: 'https://jobicy.com/jobs/2-barista', companyName: '' };
    const store = new MemoryStore();
    const s = await sync(store, fakeApi({ pages: [[a, b]] }).f);
    expect(s).toMatchObject({ upserted: 2, duplicates: 0 });
  });

  it('counts and skips invalid records without failing the pass', async () => {
    const bad = [{ id: 5, jobTitle: 'x', url: 'https://evil.example/5' }, { id: 6, jobTitle: '', url: 'https://jobicy.com/jobs/6' }, { nope: true }];
    const store = new MemoryStore();
    const s = await sync(store, fakeApi({ pages: [[...bad, jobs[0]]] }).f);
    expect(s).toMatchObject({ status: 'ok', fetched: 4, upserted: 1, rejected: 3 });
    expect([...store.rows.keys()]).toEqual(['jobicy:154956']);
  });
});

describe('runSync: removed and expired jobs', () => {
  const seed = (store: MemoryStore, ids: number[]) => {
    for (const id of ids) {
      store.rows.set(`jobicy:${id}`, { ...toJobRow({
        source: 'jobicy', externalId: String(id), company: `Old ${id}`, title: `Old role ${id}`, description: '', country: null, city: null,
        language: null, workMode: 'remote', contractType: null, salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
        publishedAt: null, lastCheckedAt: '2026-09-01T00:00:00.000Z', requirements: [], skills: [], originalUrl: `https://jobicy.com/jobs/${id}-old`,
        applyUrl: `https://jobicy.com/jobs/${id}-old`, status: 'open', geoRestrictions: [],
      }) });
    }
  };

  it('a stored job missing from the 7-day feed is NOT closed just for being missing', async () => {
    const store = new MemoryStore(); seed(store, [111]);
    const api = fakeApi({ status: () => res(200, statusBody({ 111: 'active' })) });
    const s = await sync(store, api.f);
    expect(s.closed).toBe(0);
    expect(store.rows.get('jobicy:111')!.status).toBe('open');
    expect(api.log.filter((l) => l.endsWith('/status'))).toHaveLength(1); // it asked the source instead of guessing
  });

  it('closes only what the source reports as closed; "unknown" stays open', async () => {
    const store = new MemoryStore(); seed(store, [111, 222, 333]);
    const api = fakeApi({ status: () => res(200, statusBody({ 111: 'closed', 222: 'unknown', 333: 'active' })) });
    const s = await sync(store, api.f);
    expect(s.closed).toBe(1);
    expect(['111', '222', '333'].map((id) => store.rows.get(`jobicy:${id}`)!.status)).toEqual(['closed', 'open', 'open']);
  });

  it('jobs seen in this pass are not even asked about', async () => {
    const store = new MemoryStore(); seed(store, [111]);
    let asked: string[] = [];
    const api = fakeApi({ status: (ids) => (asked = ids, res(200, statusBody({ 111: 'closed' }))) });
    await sync(store, api.f);
    expect(asked).toEqual(['111']); // none of the 10 feed ids
  });

  it('asks in batches of 100 and respects the per-pass cap', async () => {
    const store = new MemoryStore(); seed(store, Array.from({ length: 250 }, (_, i) => 1000 + i));
    const sizes: number[] = [];
    const api = fakeApi({ status: (ids) => (sizes.push(ids.length), res(200, statusBody(Object.fromEntries(ids.map((id) => [id, 'closed']))))) });
    const s = await sync(store, api.f);
    expect(sizes).toEqual([100, 100, 50]);
    expect(s.closed).toBe(250);
  });

  it('a failing status check closes nothing and marks the pass partial', async () => {
    const store = new MemoryStore(); seed(store, [111]);
    const api = fakeApi({ status: () => res(500) });
    const s = await sync(store, api.f);
    expect(s).toMatchObject({ status: 'partial', closed: 0, error_class: 'http_500' });
    expect(store.rows.get('jobicy:111')!.status).toBe('open');
    expect(store.calls.markClosed).toBe(0);
  });

  it('with no stored jobs, no status request is made at all', async () => {
    const api = fakeApi();
    await sync(new MemoryStore(), api.f);
    expect(api.log.some((l) => l.endsWith('/status'))).toBe(false);
  });
});

describe('runSync: failures never close jobs and are always recorded', () => {
  const seedOne = (store: MemoryStore) => store.rows.set('jobicy:111', { ...toJobRow({ source: 'jobicy', externalId: '111', company: 'c', title: 't', description: '', country: null, city: null, language: null, workMode: 'remote', contractType: null, salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null, publishedAt: null, lastCheckedAt: 'x', requirements: [], skills: [], originalUrl: 'https://jobicy.com/jobs/111', applyUrl: null, status: 'open', geoRestrictions: [] }) });

  it('HTTP 429 with Retry-After: waits the requested time, then succeeds', async () => {
    const sleeps: number[] = [];
    const api = fakeApi({ feedError: (n) => (n === 0 ? res(429, {}, { 'retry-after': '2' }) : null) });
    const s = await sync(new MemoryStore(), api.f, { sleep: async (ms: number) => void sleeps.push(ms) });
    expect(s.status).toBe('ok');
    expect(sleeps).toContain(2000);
  });

  it('HTTP 500 on every attempt of the first page: failed, nothing stored, run recorded', async () => {
    const store = new MemoryStore(); seedOne(store);
    const s = await sync(store, fakeApi({ feedError: () => res(500) }).f);
    expect(s).toMatchObject({ status: 'failed', pages: 0, upserted: 0, closed: 0, error_class: 'http_500', runRecorded: true });
    expect(store.rows.get('jobicy:111')!.status).toBe('open');
    expect(store.calls.listOpen).toBe(0);
    expect(store.runs[0]).toMatchObject({ status: 'failed', error_class: 'http_500', http_errors: 1 });
  });

  it('HTTP 500 on the second page: partial, first page kept, no closure', async () => {
    const store = new MemoryStore(); seedOne(store);
    const s = await sync(store, fakeApi({ feedError: (_n, cursor) => (cursor ? res(500) : null) }).f);
    expect(s).toMatchObject({ status: 'partial', pages: 1, upserted: 5, closed: 0, error_class: 'http_500' });
    expect(store.rows.size).toBe(6);
    expect(store.calls.listOpen).toBe(0);
    expect(store.calls.markClosed).toBe(0);
  });

  it('retries a transient 503 and still finishes', async () => {
    const api = fakeApi({ feedError: (n) => (n < 2 ? res(503) : null) });
    const s = await sync(new MemoryStore(), api.f);
    expect(s).toMatchObject({ status: 'ok', upserted: 10 });
  });

  it('timeout: classified as such, retried, then reported', async () => {
    const f = (async () => { throw Object.assign(new Error('The operation timed out'), { name: 'TimeoutError' }); }) as unknown as typeof fetch;
    const store = new MemoryStore();
    const s = await sync(store, f);
    expect(s).toMatchObject({ status: 'failed', error_class: 'timeout', closed: 0 });
    expect(store.runs[0]!.error_class).toBe('timeout');
  });

  it('a client error such as 404 is not retried', async () => {
    let calls = 0;
    const f = (async () => (calls++, res(404))) as unknown as typeof fetch;
    const s = await sync(new MemoryStore(), f);
    expect(calls).toBe(1);
    expect(s).toMatchObject({ status: 'failed', error_class: 'http_404' });
  });

  it('a database error while saving stops the pass and is reported, not thrown', async () => {
    const store = new MemoryStore(); store.failUpsert = true;
    const s = await sync(store, fakeApi().f);
    expect(s).toMatchObject({ status: 'failed', error_class: 'network_or_parse', upserted: 0 });
  });

  it('failing to record the run does not throw and is visible in the summary', async () => {
    const store = new MemoryStore(); store.failRecord = true;
    const logs: string[] = [];
    const s = await sync(store, fakeApi().f, { log: (e: string) => logs.push(e) });
    expect(s).toMatchObject({ status: 'ok', runRecorded: false });
    expect(logs).toContain('sync.run_not_recorded');
  });

  it('expired cursor (HTTP 400) restarts the traversal once, without duplicating rows', async () => {
    const store = new MemoryStore();
    let page2Calls = 0;
    const api = fakeApi({ feedError: (_n, cursor) => (cursor === 'C1' && page2Calls++ === 0 ? res(400, { success: false, error: 'cursor expired' }) : null) });
    const s = await sync(store, api.f);
    expect(s).toMatchObject({ status: 'ok', restarted: true, http_errors: 1 });
    expect(api.log).toEqual(['/api/v2/remote-jobs', '/api/v2/remote-jobs?cursor=C1', '/api/v2/remote-jobs', '/api/v2/remote-jobs?cursor=C1']);
    expect(store.rows.size).toBe(10);
    expect(s.duplicates).toBe(5); // page 1 came back a second time
  });

  it('a persistent 400 restarts only once and then gives up', async () => {
    const api = fakeApi({ feedError: (_n, cursor) => (cursor ? res(400) : null) });
    const s = await sync(new MemoryStore(), api.f);
    expect(s).toMatchObject({ status: 'partial', error_class: 'http_400' });
  });

  it('never logs job content, URLs or keys', async () => {
    const lines: string[] = [];
    await sync(new MemoryStore(), fakeApi().f, { log: (e: string, d: Record<string, unknown>) => lines.push(e + JSON.stringify(d)) });
    const all = lines.join('\n');
    expect(all).not.toMatch(/Juniper|jobicy\.com\/jobs|http/i);
  });
});
