import { describe, expect, it } from 'vitest';
import { adStatus, jobtechConnector } from '../src/connectors/jobtech';
import { HttpError } from '../src/http';
import { runScheduledSync } from '../src/scheduled';
import { runSync, type JobRow, type JobStore } from '../src/sync';
import { World } from './helpers/world';

// Freshness of stored Platsbanken ads: they are verified one by one through /ad/{id} (200 = still published, 404 = gone), oldest
// verification first, so an ad that left the "newest 1 200" window stays visible while the source still publishes it.
const HOST = 'jobsearch.api.jobtechdev.se';
const NOW = new Date('2026-10-12T12:00:00.000Z');
const nowFn = () => NOW;
const future = '2026-11-01T23:59:59';

const ad = (id: string, over: Record<string, unknown> = {}) => ({ id, removed: false, last_publication_date: future, ...over });
const json = (body: unknown, status = 200, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', ...headers } });

const stored = (id: string, checked: string, status: 'open' | 'closed' = 'open') => ({
  source_id: 'jobtech', external_id: id, company: 'c', title: `t ${id}`, status, description: 'd', last_checked_at: checked,
  original_url: `https://arbetsformedlingen.se/platsbanken/annonser/${id}`, canonical_url: `https://arbetsformedlingen.se/platsbanken/annonser/${id}`, fingerprint: `fp-${id}`,
});

describe('adStatus: only the source\'s own evidence decides', () => {
  const t = NOW.getTime();
  it('404 and 410 are closed; removed=true is closed; an ended publication window (> 36 h) is closed', () => {
    expect(adStatus(404, null, t)).toBe('closed');
    expect(adStatus(410, null, t)).toBe('closed');
    expect(adStatus(200, ad('1', { removed: true }), t)).toBe('closed');
    expect(adStatus(200, ad('1', { last_publication_date: '2026-10-10T08:00:00' }), t)).toBe('closed');
  });
  it('a published ad is open, also on the last day of its window', () => {
    expect(adStatus(200, ad('1'), t)).toBe('open');
    expect(adStatus(200, ad('1', { last_publication_date: '2026-10-12T23:59:59' }), t)).toBe('open');
    expect(adStatus(200, ad('1', { last_publication_date: '2026-10-11T23:59:59' }), t)).toBe('open'); // 12 h past: inside the 36 h grace
  });
  it('anything else is unknown: a 403, an unreadable answer, an answer without an id', () => {
    expect(adStatus(403, null, t)).toBe('unknown');
    expect(adStatus(200, null, t)).toBe('unknown');
    expect(adStatus(200, { removed: false }, t)).toBe('unknown');
    expect(adStatus(204, null, t)).toBe('unknown');
  });
});

describe('Platsbanken checkStatuses', () => {
  it('asks /ad/{id} once per id and maps 200 / 404 / 403 to open / closed / unknown', async () => {
    const asked: string[] = [];
    const c = jobtechConnector(async (u) => {
      const id = new URL(String(u)).pathname.split('/').pop()!;
      asked.push(id);
      return id === '2' ? json({ message: 'Ad not found' }, 404) : id === '3' ? json({}, 403) : json(ad(id));
    }, nowFn, { statusPauseMs: 0 });
    const r = await c.checkStatuses!(['1', '2', '3', '4']);
    expect(r).toEqual({ '1': 'open', '2': 'closed', '3': 'unknown', '4': 'open' });
    expect(asked.sort()).toEqual(['1', '2', '3', '4']);
  });

  it('never builds a URL from an id that is not a plain number', async () => {
    const asked: string[] = [];
    const c = jobtechConnector(async (u) => { asked.push(String(u)); return json(ad('9')); }, nowFn, { statusPauseMs: 0 });
    expect(await c.checkStatuses!(['../x', '9', '9?x=1', ''])).toEqual({ '9': 'open' });
    expect(asked).toHaveLength(1);
  });

  it('429 and 5xx are thrown (with Retry-After), never read as open or closed', async () => {
    const c429 = jobtechConnector(async () => json({}, 429, { 'retry-after': '7' }), nowFn, { statusPauseMs: 0 });
    await expect(c429.checkStatuses!(['1'])).rejects.toMatchObject({ status: 429, retryAfterMs: 7000 });
    const c500 = jobtechConnector(async () => json({}, 503), nowFn, { statusPauseMs: 0 });
    await expect(c500.checkStatuses!(['1'])).rejects.toBeInstanceOf(HttpError);
  });

  it('a network timeout propagates (the batch is retried), it is not an answer', async () => {
    const c = jobtechConnector(async () => { throw new DOMException('timeout', 'TimeoutError'); }, nowFn, { statusPauseMs: 0 });
    await expect(c.checkStatuses!(['1'])).rejects.toThrow();
  });
});

// A store that keeps the verification order and counts writes, for thousands of rows.
class Store implements JobStore {
  rows = new Map<string, ReturnType<typeof stored>>();
  closedCalls = 0;
  stampCalls = 0;
  constructor(n: number) { for (let i = 1; i <= n; i++) this.rows.set(String(i), stored(String(i), new Date(Date.UTC(2026, 9, 1) + i * 1000).toISOString())); }
  async upsertJobs() { throw new Error('revalidate must never upsert'); }
  async listOpenExternalIds() {
    return [...this.rows.values()].filter((r) => r.status === 'open').sort((a, b) => a.last_checked_at.localeCompare(b.last_checked_at)).map((r) => r.external_id);
  }
  async markClosed(_s: string, ids: string[]) { this.closedCalls++; for (const id of ids) this.rows.get(id)!.status = 'closed'; }
  async confirmOpen(_s: string, ids: string[]) { this.stampCalls++; for (const id of ids) this.rows.get(id)!.last_checked_at = '2026-10-12T12:00:00.000Z'; }
  async recordRun() {}
}
const revalidate = (store: Store, fetchImpl: typeof fetch, over: Partial<Parameters<typeof runSync>[0]> = {}) =>
  runSync({ connector: jobtechConnector(fetchImpl, nowFn, { statusPauseMs: 0 }), store, mode: 'revalidate', now: nowFn, sleep: async () => {}, retry: { retries: 1, baseMs: 1, maxMs: 1 }, recordRun: async () => {}, ...over });

describe('Platsbanken revalidation at scale (3 500 stored ads)', () => {
  // every 10th ad is gone from the source; the rest is still published although none of them is in the newest window
  const fetchLive = (calls: { n: number }) => (async (u) => {
    calls.n++;
    const id = new URL(String(u)).pathname.split('/').pop()!;
    return Number(id) % 10 === 0 ? json({ message: 'Ad not found' }, 404) : json(ad(id));
  }) as typeof fetch;

  it('verifies the 3 000 least recently verified ads per pass, closes only what the source says is gone, and the next pass starts with the 500 left', async () => {
    const s = new Store(3500);
    const calls = { n: 0 };
    const out = await revalidate(s, fetchLive(calls));
    expect(out).toMatchObject({ status: 'ok', closed: 300, confirmed: 2700, unverified: 0 });
    expect(calls.n).toBe(3000);
    // ids 1..3000 were the oldest; 3001..3500 were not asked about and keep their old date and status
    const untouched = [...s.rows.values()].filter((r) => Number(r.external_id) > 3000);
    expect(untouched.every((r) => r.status === 'open' && r.last_checked_at.startsWith('2026-10-01'))).toBe(true);
    expect([...s.rows.values()].filter((r) => r.status === 'closed').every((r) => Number(r.external_id) % 10 === 0)).toBe(true);

    const calls2 = { n: 0 };
    const out2 = await revalidate(s, fetchLive(calls2));
    // second pass: 500 never-verified ads first (those older than the stamped ones), then the rest
    expect(out2).toMatchObject({ status: 'ok' });
    expect([...s.rows.values()].filter((r) => r.status === 'open').every((r) => r.last_checked_at === '2026-10-12T12:00:00.000Z')).toBe(true);
    expect([...s.rows.values()].filter((r) => r.status === 'closed')).toHaveLength(350);
  }, 60_000);

  it('is idempotent: closed ads are not asked about again and nothing is reopened', async () => {
    const s = new Store(300);
    const calls = { n: 0 };
    await revalidate(s, fetchLive(calls));
    const first = JSON.stringify([...s.rows.entries()]);
    const calls2 = { n: 0 };
    const out = await revalidate(s, fetchLive(calls2));
    expect(calls2.n).toBe(270); // only the open ones
    expect(out.closed).toBe(0);
    expect([...s.rows.values()].filter((r) => r.status === 'closed')).toHaveLength(30);
    expect(JSON.stringify([...s.rows.entries()])).toBe(first); // the open ones were stamped with the same instant; closed ones are untouched
    expect([...s.rows.values()].filter((r) => r.status === 'closed').every((r) => Number(r.external_id) % 10 === 0)).toBe(true);
  });

  it('a failure in the middle keeps what earlier batches proved and closes nothing because of the failure', async () => {
    const s = new Store(1000);
    let n = 0;
    const flaky = (async (u) => {
      n++;
      const id = new URL(String(u)).pathname.split('/').pop()!;
      if (n > 450) return json({ message: 'boom' }, 503); // batches 1-4 succeed, batch 5 dies
      return Number(id) % 10 === 0 ? json({}, 404) : json(ad(id));
    }) as typeof fetch;
    const out = await revalidate(s, flaky);
    expect(out.status).toBe('partial');
    const closed = [...s.rows.values()].filter((r) => r.status === 'closed');
    expect(closed.length).toBeGreaterThan(0);
    expect(closed.length).toBeLessThanOrEqual(45);
    expect(closed.every((r) => Number(r.external_id) % 10 === 0)).toBe(true);
    // the ads the failing batch should have judged are still open and keep their OLD verification date
    expect([...s.rows.values()].filter((r) => Number(r.external_id) > 500).every((r) => r.status === 'open' && r.last_checked_at.startsWith('2026-10-01'))).toBe(true);
  });

  it('a whole outage (403/timeouts on every id) closes nothing and stamps nothing', async () => {
    const s = new Store(250);
    const out = await revalidate(s, (async () => json({}, 403)) as typeof fetch);
    expect(out.unverified).toBe(250);
    expect(out.closed).toBe(0);
    expect(s.closedCalls + s.stampCalls).toBe(0);
    expect([...s.rows.values()].every((r) => r.status === 'open' && r.last_checked_at.startsWith('2026-10-01'))).toBe(true);
  });

  it('a 429 with Retry-After is waited out and the batch is repeated', async () => {
    const s = new Store(20);
    let first = true;
    const slept: number[] = [];
    const f = (async (u) => {
      if (first) { first = false; return json({}, 429, { 'retry-after': '3' }); }
      return json(ad(new URL(String(u)).pathname.split('/').pop()!));
    }) as typeof fetch;
    const out = await revalidate(s, f, { retry: { retries: 2, baseMs: 1, maxMs: 1, sleep: async (ms) => { slept.push(ms); } } });
    expect(out).toMatchObject({ status: 'ok', confirmed: 20, closed: 0 });
    expect(slept).toContain(3000);
  });

  it('an ad that left the newest-ads window but is still published stays open and is stamped (the case that used to vanish after 72 h)', async () => {
    const s = new Store(5);
    const out = await revalidate(s, (async (u) => json(ad(new URL(String(u)).pathname.split('/').pop()!))) as typeof fetch);
    expect(out).toMatchObject({ status: 'ok', closed: 0, confirmed: 5 });
    expect([...s.rows.values()].every((r) => r.status === 'open' && r.last_checked_at === '2026-10-12T12:00:00.000Z')).toBe(true);
  });

  it('listing order and deadline: when the time budget ends the pass is partial and unchecked ads are left alone', async () => {
    const s = new Store(400);
    let t = NOW.getTime();
    const clock = () => new Date(t);
    const f = (async (u) => { t += 1_000; return json(ad(new URL(String(u)).pathname.split('/').pop()!)); }) as typeof fetch;
    const out = await runSync({
      connector: jobtechConnector(f, nowFn, { statusPauseMs: 0 }), store: s, mode: 'revalidate', now: clock, sleep: async () => {}, retry: { retries: 0, baseMs: 1, maxMs: 1 },
      recordRun: async () => {}, deadlineAt: NOW.getTime() + 150_000,
    });
    expect(out.status).toBe('partial');
    expect(out.error_class).toBe('deadline');
    expect([...s.rows.values()].some((r) => r.last_checked_at.startsWith('2026-10-01'))).toBe(true);
    expect([...s.rows.values()].every((r) => r.status === 'open')).toBe(true);
  });
});

describe('Platsbanken scheduled revalidation (lease, scope, discover interplay)', () => {
  const host = (w: World, handler: (id: string) => Response) => { w.hosts[HOST] = (u) => handler(u.pathname.split('/').pop()!); };
  const seed = (w: World, n: number) => { for (let i = 1; i <= n; i++) w.jobs.set(`jobtech:${i}`, stored(String(i), '2026-10-01T00:00:00.000Z')); };
  const env = (w: World, over: Record<string, string> = {}) => w.env({ SYNC_MODE: 'revalidate', SYNC_SOURCE: 'jobtech', ...over });

  it('closes the gone, stamps the live, never imports, and records its own run row', async () => {
    const w = new World();
    seed(w, 12);
    host(w, (id) => (Number(id) % 4 === 0 ? json({}, 404) : json(ad(id))));
    const out = await runScheduledSync(env(w), w.deps());
    expect(out).toMatchObject({ status: 'ok', summary: { closed: 3, confirmed: 9, upserted: 0 } });
    expect(w.runs[0]).toMatchObject({ source_id: 'jobtech', scope: 'revalidate', status: 'ok', closed: 3 });
    expect(w.jobPosts).toHaveLength(0);
    expect([...w.jobs.values()].filter((j) => j.status === 'closed').map((j) => j.external_id).sort()).toEqual(['12', '4', '8']);
  });

  it('two simultaneous revalidations: exactly one runs, the other is refused by the database lease', async () => {
    const w = new World();
    seed(w, 8);
    host(w, (id) => json(ad(id)));
    const [a, b] = await Promise.all([runScheduledSync(env(w), w.deps()), runScheduledSync(env(w), w.deps())]);
    const outcomes = [a, b].map((o) => o.status).sort();
    expect(outcomes).toEqual(['ok', 'skipped']);
    expect(w.runs).toHaveLength(1);
  });

  it('a discover pass in the same hour blocks the revalidation (one pass per hour per source) and it runs once the hour is over', async () => {
    const w = new World();
    seed(w, 4);
    host(w, (id) => json(ad(id)));
    w.runs.push({ id: 'prev', source_id: 'jobtech', scope: 'discover', started_at: new Date(w.clock.getTime() - 10 * 60_000).toISOString(), finished_at: w.clock.toISOString(), status: 'ok', fetched: 1, upserted: 0, duplicates: 0, closed: 0, http_errors: 0, error_class: null });
    expect(await runScheduledSync(env(w), w.deps())).toEqual({ status: 'skipped', reason: 'too_soon' });
    w.clock = new Date(w.clock.getTime() + 61 * 60_000);
    expect((await runScheduledSync(env(w), w.deps())).status).toBe('ok');
  });

  it('a source outage (every answer 503) is a failed pass: nothing closed, nothing stamped, no ad judged', async () => {
    const w = new World();
    seed(w, 6);
    host(w, () => json({}, 503));
    const out = await runScheduledSync(env(w), w.deps({ retry: { retries: 1, baseMs: 1, maxMs: 1 } }));
    expect(out.status).not.toBe('ok');
    expect([...w.jobs.values()].every((j) => j.status === 'open' && String(j.last_checked_at).startsWith('2026-10-01'))).toBe(true);
  });
});

describe('discover no longer asks the status endpoint about ads the listing just returned', () => {
  it('new ads from the search are inserted without a single /ad request (the listing is the evidence)', async () => {
    const asked: string[] = [];
    const base = { id: '5', headline: 'Fysioterapeut', employer: { name: 'X' }, webpage_url: 'https://arbetsformedlingen.se/platsbanken/annonser/5', workplace_address: { country: 'Sverige' } };
    const f = (async (u) => {
      asked.push(new URL(String(u)).pathname);
      return json({ total: { value: 1 }, hits: [base] });
    }) as typeof fetch;
    const inserted: JobRow[] = [];
    const store: JobStore = {
      upsertJobs: async () => { throw new Error('no'); }, listOpenExternalIds: async () => [], markClosed: async () => {},
      listKnownKeys: async () => [], insertNewJobs: async (rows) => { inserted.push(...rows); return rows.length; }, recordRun: async () => {},
    };
    const out = await runSync({ connector: jobtechConnector(f, nowFn, { statusPauseMs: 0 }), store, mode: 'discover', now: nowFn, sleep: async () => {}, retry: { retries: 0, baseMs: 1, maxMs: 1 }, recordRun: async () => {}, maxPages: 2, pageWindow: true });
    expect(out.upserted).toBe(1);
    expect(inserted).toHaveLength(1);
    expect(asked.some((p) => p.startsWith('/ad/'))).toBe(false);
  });
});

describe('an unknown ad that is listed again comes back (presence is the evidence); a closed one never does', () => {
  it('discover revives status unknown with the listing\'s own content, leaves closed alone, and counts it as confirmed', async () => {
    const w = new World();
    const hit = (id: string, title: string) => ({ id, headline: title, employer: { name: 'Acme' }, webpage_url: `https://arbetsformedlingen.se/platsbanken/annonser/${id}`, workplace_address: { country: 'Sverige', municipality: 'Lund' }, description: { text: 'Full text again' }, publication_date: '2026-10-11T08:00:00' });
    w.hosts[HOST] = () => json({ total: { value: 3 }, hits: [hit('11', 'Fysioterapeut A'), hit('12', 'Fysioterapeut B'), hit('13', 'Fysioterapeut C')] });
    w.jobs.set('jobtech:11', { ...stored('11', '2026-09-20T00:00:00.000Z'), status: 'unknown', description: '' });       // compacted + unknown: returns with text
    w.jobs.set('jobtech:12', { ...stored('12', '2026-09-20T00:00:00.000Z'), status: 'closed', description: '' });        // closed: stays closed
    w.jobs.set('jobtech:13', { ...stored('13', '2026-10-12T00:00:00.000Z'), status: 'open' });                          // open: only stamped
    const out = await runScheduledSync(w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'jobtech' }), w.deps());
    expect(out).toMatchObject({ status: 'ok', summary: { upserted: 0 } });
    expect(w.jobs.get('jobtech:11')).toMatchObject({ status: 'open', description: 'Full text again', title: 'Fysioterapeut A' });
    expect(w.jobs.get('jobtech:12')).toMatchObject({ status: 'closed', description: '' });
    expect(w.jobs.get('jobtech:13')!.status).toBe('open');
    expect((out as { summary: { confirmed: number } }).summary.confirmed).toBeGreaterThanOrEqual(2); // the revived one and the stamped one (the stubbed host repeats the same page for every stream)
  });
});
