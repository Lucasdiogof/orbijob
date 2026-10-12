import { describe, expect, it } from 'vitest';
import { jobsCoNzConnector, listingStatus, normalizeJobsCoNz } from '../src/connectors/jobsconz';
import { HttpError } from '../src/http';
import { runScheduledSync } from '../src/scheduled';
import { runSync, type JobRow, type JobStore } from '../src/sync';
import fixture from './fixtures/jobsconz.sanitized.json';
import { World } from './helpers/world';

// Real listings of the Jobs.co.nz public API (read 2026-10-12): 8 listings of 8 categories; text trimmed and contacts scrubbed.
const NOW = '2026-10-12T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const json = (body: unknown, status = 200, headers: Record<string, string> = {}) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', ...headers } });
const recs = fixture.data as Record<string, unknown>[];
const ok = (r: ReturnType<typeof normalizeJobsCoNz>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
const base = recs[0]!;

describe('Jobs.co.nz normalizer (real listings)', () => {
  it('maps a listing without inventing anything: New Zealand from the New Zealand board, NZD salary only with its period, no language', () => {
    const jobs = recs.map((r) => ok(normalizeJobsCoNz(r, NOW)));
    expect(jobs).toHaveLength(8);
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'jobsconz', country: 'NZ', language: null, status: 'open', geoRestrictions: [], lastCheckedAt: NOW });
      expect(new URL(j.originalUrl).hostname).toBe('jobs.co.nz');
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.externalId).toMatch(/^[1-9][0-9]*$/);
      expect(j.city).toBeTruthy();
      expect(j.publishedAt).toMatch(/^2026-/);
    }
    expect(jobs[0]).toMatchObject({ title: 'Project Manager.', company: 'Circit', city: 'Howick', workMode: 'onsite', contractType: 'full-time', salaryMin: 85000, salaryMax: 125000, salaryCurrency: 'NZD', salaryPeriod: 'year' });
    expect(jobs[1]!.salaryMin).toBeNull(); // no salary stated: none shown
  });

  it('the work mode and the salary come only from what the listing states', () => {
    const w = (mode: unknown) => ok(normalizeJobsCoNz({ ...base, work_mode: mode }, NOW)).workMode;
    expect(w('remote')).toBe('remote');
    expect(w('hybrid')).toBe('hybrid');
    expect(w('onsite')).toBe('onsite');
    expect(w('flexible')).toBe('unspecified');
    const s = (salary: unknown) => ok(normalizeJobsCoNz({ ...base, salary }, NOW));
    expect(s({ currency: 'NZD', min: 30, max: 40, period: 'hour' })).toMatchObject({ salaryMin: 30, salaryMax: 40, salaryPeriod: 'hour' });
    expect(s({ currency: 'NZD', min: 70000, period: 'year' })).toMatchObject({ salaryMin: 70000, salaryMax: 70000 });
    expect(s({ currency: 'NZD', min: 70000, max: 60000, period: 'year' }).salaryMin).toBeNull(); // upside down
    expect(s({ currency: 'NZD', min: 70000, period: 'week' }).salaryMin).toBeNull(); // unknown period
    expect(s({ min: 70000, period: 'year' }).salaryMin).toBeNull(); // no currency
    expect(s(null).salaryMin).toBeNull();
  });

  it('the listing\'s own expiry is respected', () => {
    expect(normalizeJobsCoNz({ ...base, expires_at: '2026-10-01T00:00:00' }, NOW)).toMatchObject({ ok: false, reason: 'expired' });
    expect(normalizeJobsCoNz({ ...base, expires_at: '2026-11-08T16:08:26' }, NOW).ok).toBe(true);
    expect(normalizeJobsCoNz({ ...base, expires_at: null }, NOW).ok).toBe(true);
  });

  it('rejects what cannot be shown honestly, with a reason and never an exception', () => {
    const r = (over: Record<string, unknown>) => normalizeJobsCoNz({ ...base, ...over }, NOW);
    expect(r({ id: 0 })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ id: '../1' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ title: ' ' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ company: '' })).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(r({ url: 'https://evil.example/jobs/1/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'http://jobs.co.nz/jobs/1/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'https://jobs.co.nz.evil.io/jobs/1/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(normalizeJobsCoNz(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
  });

  it('caps a long description and masks personal e-mail addresses', () => {
    expect(ok(normalizeJobsCoNz({ ...base, description: 'x '.repeat(10000) }, NOW)).description.length).toBeLessThanOrEqual(6001);
    expect(ok(normalizeJobsCoNz({ ...base, description: 'Email jane.doe@example.org' }, NOW)).description).toBe('Email [e-mail]');
  });
});

describe('Jobs.co.nz status by id', () => {
  const t = Date.parse(NOW);
  it('404 and 410 are gone; 200 is open unless its own expiry passed; anything else is unknown', () => {
    expect(listingStatus(404, null, t)).toBe('closed');
    expect(listingStatus(410, null, t)).toBe('closed');
    expect(listingStatus(200, { data: { id: 1, expires_at: '2026-11-08T16:08:26' } }, t)).toBe('open');
    expect(listingStatus(200, { data: { id: 1, expires_at: '2026-10-11T16:08:26' } }, t)).toBe('closed');
    expect(listingStatus(200, { data: { id: 1 } }, t)).toBe('open');
    expect(listingStatus(200, { nothing: true }, t)).toBe('unknown');
    expect(listingStatus(200, null, t)).toBe('unknown');
    expect(listingStatus(403, null, t)).toBe('unknown');
  });

  it('asks /api/v1/jobs/{id} once per id, only for plain numeric ids; 429 and 5xx are thrown with Retry-After', async () => {
    const asked: string[] = [];
    const c = jobsCoNzConnector(async (u) => {
      const id = new URL(String(u)).pathname.split('/').pop()!;
      asked.push(id);
      return id === '2' ? json({ error: { code: 'not_found' } }, 404) : json({ data: { id: Number(id), expires_at: '2999-01-01T00:00:00' } });
    }, nowFn, { statusPauseMs: 0 });
    expect(await c.checkStatuses!(['1', '2', '../3', '4'])).toEqual({ '1': 'open', '2': 'closed', '4': 'open' });
    expect(asked.sort()).toEqual(['1', '2', '4']);
    const limited = jobsCoNzConnector(async () => json({}, 429, { 'retry-after': '9' }), nowFn, { statusPauseMs: 0 });
    await expect(limited.checkStatuses!(['1'])).rejects.toMatchObject({ status: 429, retryAfterMs: 9000 });
  });
});

describe('Jobs.co.nz connector', () => {
  it('pages by offset with the API\'s own has_more, 100 at a time', async () => {
    const urls: string[] = [];
    const c = jobsCoNzConnector(async (u) => {
      urls.push(String(u));
      const offset = Number(new URL(String(u)).searchParams.get('offset'));
      return json({ data: offset === 0 ? Array.from({ length: 100 }, (_, i) => ({ ...base, id: 1000 + i })) : recs, pagination: { has_more: offset === 0, limit: 100, offset, total: 108 } });
    }, nowFn);
    const p1 = await c.fetchPage(null, '');
    expect(p1.nextCursor).toBe('100');
    expect(p1.jobs).toHaveLength(100);
    const p2 = await c.fetchPage('100', '');
    expect(p2.nextCursor).toBeNull();
    expect(urls[0]).toBe('https://jobs.co.nz/api/v1/jobs?limit=100&offset=0');
  });

  it('refuses a malformed cursor and an unexpected body; a non-JSON answer is a non-retryable 403', async () => {
    const c = jobsCoNzConnector(async () => json({ nothing: true }), nowFn);
    for (const bad of ['x', '50', '-100', '999900']) await expect(c.fetchPage(bad, '')).rejects.toThrow(/invalid cursor/);
    await expect(c.fetchPage(null, '')).rejects.toThrow(/unexpected response/);
    const gate = jobsCoNzConnector(async () => new Response('<html>nope</html>', { status: 200 }), nowFn);
    await expect(gate.fetchPage(null, '')).rejects.toBeInstanceOf(HttpError);
  });
});

describe('Jobs.co.nz through the pipeline', () => {
  it('discover imports once, stamps on the next pass; revalidate closes what the API says is gone and confirms the rest', async () => {
    const w = new World();
    const gone = new Set<string>();
    w.hosts['jobs.co.nz'] = (u) => {
      if (u.pathname === '/api/v1/jobs') return json({ data: recs, pagination: { has_more: false, limit: 100, offset: 0, total: recs.length } });
      const id = u.pathname.split('/').pop()!;
      return gone.has(id) ? json({ error: { code: 'not_found' } }, 404) : json({ data: { id: Number(id), expires_at: '2999-01-01T00:00:00' } });
    };
    const discover = w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'jobsconz' });
    expect(await runScheduledSync(discover, w.deps())).toMatchObject({ status: 'ok', summary: { upserted: 8 } });
    expect([...w.jobs.values()].filter((j) => j.source_id === 'jobsconz')).toHaveLength(8);
    w.clock = new Date(w.clock.getTime() + 2 * 3_600_000);
    expect(await runScheduledSync(discover, w.deps())).toMatchObject({ status: 'ok', summary: { upserted: 0, confirmed: 8 } });

    // two of the eight disappear from the source
    const ids = [...w.jobs.values()].map((j) => String(j.external_id));
    gone.add(ids[0]!); gone.add(ids[1]!);
    w.clock = new Date(w.clock.getTime() + 2 * 3_600_000);
    const out = await runScheduledSync(w.env({ SYNC_MODE: 'revalidate', SYNC_SOURCE: 'jobsconz' }), w.deps());
    expect(out).toMatchObject({ status: 'ok', summary: { closed: 2, confirmed: 6 } });
    expect([...w.jobs.values()].filter((j) => j.status === 'closed')).toHaveLength(2);
  });

  it('discover keeps the per-pass and ceiling caps', async () => {
    const store: JobStore = {
      upsertJobs: async () => { throw new Error('no'); }, listOpenExternalIds: async () => [], markClosed: async () => {}, listKnownKeys: async () => [],
      insertNewJobs: async (rows: JobRow[]) => rows.length, recordRun: async () => {},
    };
    const c = jobsCoNzConnector(async () => json({ data: recs, pagination: { has_more: false } }), nowFn);
    const out = await runSync({ connector: c, store, mode: 'discover', now: nowFn, sleep: async () => {}, retry: { retries: 0, baseMs: 1, maxMs: 1 }, recordRun: async () => {}, maxNewJobs: 3 });
    expect(out.upserted).toBe(3);
    expect(out.skippedNew).toBe(5);
  });
});
