import { describe, expect, it } from 'vitest';
import { JOBTECH_PASS_PAGES, JOBTECH_STREAMS, jobtechConnector, normalizeJobtech, stockholmToIso } from '../src/connectors/jobtech';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';
import { runSync, type JobRow, type JobStore, type KnownKey } from '../src/sync';
import fixture from './fixtures/jobtech-search.sanitized.json';

// The fixture is a real JobSearch payload (read 2026-10-12): 3 physiotherapy ads, 3 other professions, 4 mobile ads; text trimmed, contacts scrubbed.
const NOW = '2026-10-12T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (r: ReturnType<typeof normalizeJobtech>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
const base = fixture.hits[0] as Record<string, unknown>;

describe('Platsbanken (JobTech) normalizer', () => {
  it('maps a real ad without inventing anything: Swedish country by name, no salary, no language, no eligibility', () => {
    const rows = fixture.hits.map((h) => ok(normalizeJobtech(h, NOW)));
    expect(rows).toHaveLength(10);
    for (const j of rows) {
      expect(j.source).toBe('jobtech');
      expect(j).toMatchObject({ country: 'SE', salaryMin: null, salaryMax: null, salaryCurrency: null, language: null, status: 'open', geoRestrictions: [], lastCheckedAt: NOW });
      expect(new URL(j.originalUrl).hostname).toBe('arbetsformedlingen.se');
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.company).not.toBe('');
      expect(j.description).not.toMatch(/<[a-z/][^>]*>/i);
      expect(j.publishedAt).toMatch(/^2026-/);
    }
    expect(rows[0]!.title).toMatch(/fysioterapeut/i);
  });

  it('keeps the original Swedish words (nothing is translated) and labels the contract from the ad', () => {
    const j = ok(normalizeJobtech({ ...base, employment_type: { label: 'Tillsvidareanställning' }, working_hours_type: { label: 'Heltid' } }, NOW));
    expect(j.contractType).toBe('Tillsvidareanställning, Heltid');
    expect(ok(normalizeJobtech({ ...base, employment_type: null, working_hours_type: null }, NOW)).contractType).toBeNull();
  });

  it("the work mode comes only from the ad's workplace model", () => {
    const mode = (label: string | null) => ok(normalizeJobtech({ ...base, workplace_model: label ? { label } : null }, NOW)).workMode;
    expect(mode('Distansarbete')).toBe('remote');
    expect(mode('Arbete på plats')).toBe('onsite');
    expect(mode('Hybridarbete')).toBe('hybrid');
    expect(mode(null)).toBe('unspecified');
  });

  it('an ad abroad is placed by the country it names in Swedish; a name that is not in the table stays unknown', () => {
    const c = (country: unknown) => ok(normalizeJobtech({ ...base, workplace_address: { country, municipality: null } }, NOW)).country;
    expect(c('Malta')).toBe('MT');
    expect(c('Norge')).toBe('NO');
    expect(c('Spanien')).toBe('ES');
    expect(c('Grekland')).toBe('GR');
    expect(c('Cypern')).toBe('CY');
    expect(c('  DANMARK ')).toBe('DK');
    expect(c('Österrike')).toBe('AT');
    expect(c('Sverige')).toBe('SE');
    for (const unknown of ['Albanien', 'Narnia', '', null, undefined, 199, 'Sweden']) expect(c(unknown), String(unknown)).toBeNull();
  });
  it('a country other than Sweden is not guessed: Albania stays unknown, never SE', () => {
    const j = ok(normalizeJobtech({ ...base, workplace_address: { country: 'Albanien', municipality: 'Tirana' } }, NOW));
    expect(j.country).toBeNull();
    expect(j.city).toBe('Tirana');
    expect(ok(normalizeJobtech({ ...base, workplace_address: null }, NOW))).toMatchObject({ country: null, city: null });
  });

  it('turns Swedish local publication time into UTC with the EU summer-time rule', () => {
    expect(stockholmToIso('2026-10-12T08:03:50')).toBe('2026-10-12T06:03:50.000Z'); // CEST, checked against the API's own epoch field
    expect(stockholmToIso('2026-01-15T08:00:00')).toBe('2026-01-15T07:00:00.000Z'); // CET
    expect(stockholmToIso('2026-03-29T04:00:00')).toBe('2026-03-29T02:00:00.000Z'); // after the switch (last Sunday of March)
    expect(stockholmToIso('2026-10-25T04:00:00')).toBe('2026-10-25T03:00:00.000Z'); // after the switch back (last Sunday of October)
    expect(stockholmToIso('not a date')).toBeNull();
    expect(stockholmToIso(undefined)).toBeNull();
  });

  it('caps a very long description and masks personal e-mail addresses', () => {
    const long = `${'Vi söker dig. '.repeat(1000)} Kontakt: anna.svensson@example.org`;
    expect(ok(normalizeJobtech({ ...base, description: { text: long } }, NOW)).description.length).toBeLessThanOrEqual(6001);
    expect(ok(normalizeJobtech({ ...base, description: { text: 'Skicka till anna.svensson@example.org' } }, NOW)).description).toBe('Skicka till [e-mail]');
  });

  it('rejects what cannot be shown honestly, with a reason and never an exception', () => {
    const r = (over: Record<string, unknown>) => normalizeJobtech({ ...base, ...over }, NOW);
    expect(r({ id: '' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ id: '../9' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ headline: '  ' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ employer: { name: '', workplace: '' } })).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(r({ webpage_url: 'https://evil.example/ad/1' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ webpage_url: 'http://arbetsformedlingen.se/platsbanken/annonser/1' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ webpage_url: 'https://arbetsformedlingen.se.evil.io/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ removed: true })).toMatchObject({ ok: false, reason: 'removed' });
    expect(normalizeJobtech(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    expect(normalizeJobtech([], NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
  });
});

describe('Platsbanken connector', () => {
  it('reads priority streams first (physiotherapy by taxonomy group, mobile by query) and the newest ads of every profession last', () => {
    expect(JOBTECH_STREAMS[0]).toMatchObject({ id: 'physio', params: { 'occupation-group': 's7vU_FhY_L5Z' } });
    expect(JOBTECH_STREAMS.at(-1)).toMatchObject({ id: 'new', params: {} });
    expect(JOBTECH_STREAMS.slice(1, -1).every((s) => s.titleMust && s.params.q)).toBe(true);
    expect(SOURCES.jobtech!.maxPages).toBe(JOBTECH_PASS_PAGES);
  });

  it("walks the streams in order with a cursor, never past the API's 2 000 offset and the stream's own page limit", async () => {
    const urls: string[] = [];
    const c = jobtechConnector(async (u) => {
      urls.push(String(u));
      return json({ total: { value: 39000 }, hits: Array.from({ length: 100 }, () => ({})) });
    }, nowFn);
    let cursor: string | null = null;
    let pages = 0;
    do {
      const p = await c.fetchPage(cursor, '');
      cursor = p.nextCursor;
      pages++;
    } while (cursor !== null && pages < 100);
    expect(pages).toBe(JOBTECH_PASS_PAGES);
    expect(urls[0]).toContain('occupation-group=s7vU_FhY_L5Z');
    expect(urls[0]).toContain('limit=100');
    expect(urls[0]).toContain('sort=pubdate-desc');
    expect(urls.at(-1)).toContain('offset=1100');
    expect(Math.max(...urls.map((u) => Number(new URL(u).searchParams.get('offset'))))).toBeLessThanOrEqual(2000);
  });

  it('a stream that ends early (fewer hits than a page) moves straight to the next stream', async () => {
    const c = jobtechConnector(async () => json({ total: { value: 3 }, hits: fixture.hits.slice(0, 3) }), nowFn);
    const p = await c.fetchPage(null, '');
    expect(p.jobs).toHaveLength(3);
    expect(p.nextCursor).toBe('1:0');
    expect(p.isFullSnapshot).toBe(false);
  });

  it('a text-query stream keeps only ads whose TITLE names the technology; a mention in the text is not a job of that kind', async () => {
    const hits = [
      { ...base, id: '1', headline: 'Flutter Developer' },
      { ...base, id: '2', headline: 'Sjuksköterska till vårdavdelning', description: { text: 'Vi har en egen Android-app för personalen.' } },
      { ...base, id: '3', headline: 'Mobilutvecklare till Stockholm' },
      { ...base, id: '4', headline: 'Senior iOS-utvecklare' },
      { ...base, id: '5', headline: 'Kassamedarbetare, mobiltelefoner' }, // "mobiltelefoner" is not a mobile-development word
    ];
    const c = jobtechConnector(async () => json({ total: { value: 5 }, hits }), nowFn);
    const p = await c.fetchPage('1:0', '');
    expect(p.jobs.map((j) => j.externalId)).toEqual(['1', '3', '4']);
  });

  it('refuses a malformed cursor and an unexpected body; a non-JSON answer is a non-retryable 403', async () => {
    const c = jobtechConnector(async () => json({ nothing: true }), nowFn);
    for (const bad of ['abc', '99:0', '0:2100', '0:50', '-1:0']) await expect(c.fetchPage(bad, '')).rejects.toThrow(/invalid cursor/);
    await expect(c.fetchPage(null, '')).rejects.toThrow(/unexpected response/);
    const gate = jobtechConnector(async () => new Response('<html>nope</html>', { status: 200 }), nowFn);
    await expect(gate.fetchPage(null, '')).rejects.toBeInstanceOf(HttpError);
  });
});

class MemoryStore implements JobStore {
  rows = new Map<string, JobRow & { status: string }>();
  stamped: string[][] = [];
  async upsertJobs(): Promise<void> { throw new Error('discover must never upsert'); }
  async listOpenExternalIds() { return []; }
  async markClosed(): Promise<void> { throw new Error('discover must never close'); }
  async recordRun() {}
  async listKnownKeys(): Promise<KnownKey[]> {
    return [...this.rows.values()].map((r) => ({ external_id: r.external_id, fingerprint: r.fingerprint, canonical_url: r.canonical_url, status: r.status as KnownKey['status'] }));
  }
  async countFullJobs() { return this.rows.size; }
  async insertNewJobs(rows: JobRow[]) { let n = 0; for (const r of rows) if (!this.rows.has(r.external_id)) { this.rows.set(r.external_id, { ...r, status: 'open' }); n++; } return n; }
  async confirmOpen(_s: string, ids: string[]) { this.stamped.push(ids); }
}

describe('Platsbanken discover pass', () => {
  const connector = () => jobtechConnector(async () => json({ total: { value: 10 }, hits: fixture.hits }), nowFn);
  const run = (store: MemoryStore, over: Partial<Parameters<typeof runSync>[0]> = {}) =>
    runSync({ connector: connector(), store, mode: 'discover', now: nowFn, sleep: async () => {}, retry: { retries: 0, baseMs: 1, maxMs: 1 }, recordRun: async () => {}, maxPages: JOBTECH_PASS_PAGES, pageWindow: true, ...over });

  it('imports each distinct ad once even though the streams overlap, and a second pass only stamps', async () => {
    const s = new MemoryStore();
    const out = await run(s);
    expect(out.status).toBe('ok');
    expect(out.upserted).toBe(9); // 10 ads come back from every stream; two are the same posting (company, title, city) and are stored once
    expect(s.rows.size).toBe(9);
    expect(await run(s)).toMatchObject({ status: 'ok', upserted: 0 });
    expect(s.stamped.flat().length).toBeGreaterThan(0);
  });

  it('the per-pass cap leaves the priority streams first in line', async () => {
    const s = new MemoryStore();
    const out = await run(s, { maxNewJobs: 3 });
    expect(out.upserted).toBe(3);
    expect([...s.rows.values()].every((r) => /fysioterapeut/i.test(r.title))).toBe(true); // physiotherapy is the first stream
  });
});
