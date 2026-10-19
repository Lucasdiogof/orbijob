import { describe, expect, it } from 'vitest';
import { HttpError } from '../src/http';
import { closingTime, normalizeUsaJob, usaJobsConnector } from '../src/connectors/usajobs';
import { protectPersonalData } from '../src/description';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/usajobs.sample.json';

// Announcements written after the public API documentation (see the fixture's note); the real response is checked by the workflow preview with the owner's key.
const NOW = '2026-10-17T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const items = fixture.SearchResult.SearchResultItems as unknown[];
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (r: ReturnType<typeof normalizeUsaJob>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
const KEY = 'test-key-not-a-real-credential';
const EMAIL = 'owner@example.org';

describe('USAJOBS normalizer', () => {
  it('maps an announcement without inventing anything: its own page, the agency, the location, the salary with its interval, who may apply', () => {
    const j = ok(normalizeUsaJob(items[0], NOW));
    expect(j).toMatchObject({
      source: 'usajobs', externalId: '812345600', country: 'US', city: 'Bethesda, Maryland', workMode: 'unspecified', language: 'en', status: 'open', lastCheckedAt: NOW,
      company: 'National Institutes of Health, Department of Health and Human Services', title: 'Information Technology Specialist (Customer Support)',
      contractType: 'Full-time', salaryMin: 86962, salaryMax: 113050, salaryCurrency: 'USD', salaryPeriod: 'year', geoRestrictions: [],
    });
    expect(j.originalUrl).toBe('https://www.usajobs.gov/job/812345600'); // the default port is dropped, the page is USAJOBS' own
    expect(j.applyUrl).toBe(j.originalUrl);
    expect(j.publishedAt).toBe('2026-10-12T00:00:00.000Z');
    expect(j.description).toContain('Provide technical support to staff.');
    expect(j.description).toContain('Major duties\n- Resolves hardware and software problems\n- Installs and configures workstations');
    expect(j.description).toContain('Qualifications\nYou must have one year of specialized experience');
    expect(j.description).toContain('Who may apply: United States Citizens');
    expect(j.description).toContain('Series: Information Technology Management');
    expect(j.description).toContain('Appointment: Permanent');
    expect(j.description).toContain('Closing date: 2026-11-30');
  });

  it('never stores the contact data an announcement carries: the agency contact field is not read, personal phones in the text pass the storage guard', () => {
    const j = ok(normalizeUsaJob(items[0], NOW));
    expect(j.description).not.toContain('private.person');
    const guarded = protectPersonalData(j.description, 'US');
    expect(guarded).not.toContain('301-555-0100');
    expect(guarded).not.toContain('jane.doe@');
  });

  it('remote only when the announcement says so; an hourly salary keeps its interval; eligibility stays unknown, never "anywhere"', () => {
    const j = ok(normalizeUsaJob(items[1], NOW));
    expect(j).toMatchObject({ workMode: 'remote', salaryMin: 38.5, salaryMax: 49.1, salaryPeriod: 'hour', contractType: 'Part-time', geoRestrictions: [] });
    expect(j.description).toContain('Who may apply: Open to the public');
  });

  it('several locations are said as they are; an interval that is not annual or hourly (or no pay) maps no salary', () => {
    const j = ok(normalizeUsaJob(items[2], NOW));
    expect(j.city).toBe('Multiple Locations');
    expect(j).toMatchObject({ salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null, workMode: 'unspecified' });
  });

  it('refuses what cannot be shown honestly, with the reason', () => {
    expect(normalizeUsaJob(items[3], NOW)).toEqual({ ok: false, reason: 'expired', externalId: '812345603' });
    expect(normalizeUsaJob(items[4], NOW)).toMatchObject({ ok: false, reason: 'invalid_url', externalId: '812345604' });
    expect(normalizeUsaJob(null, NOW)).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(normalizeUsaJob({ MatchedObjectId: 'abc', MatchedObjectDescriptor: {} }, NOW)).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(normalizeUsaJob({ MatchedObjectId: '812345999', MatchedObjectDescriptor: { PositionURI: 'https://www.usajobs.gov/job/1' } }, NOW)).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(normalizeUsaJob({ MatchedObjectId: '812345999', MatchedObjectDescriptor: { PositionTitle: 'X', PositionURI: 'https://www.usajobs.gov/job/1' } }, NOW)).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(normalizeUsaJob({ MatchedObjectId: '812345999', MatchedObjectDescriptor: { PositionTitle: 'X', OrganizationName: 'A', PositionURI: 'https://evil.example/job/1' } }, NOW)).toMatchObject({ ok: false, reason: 'invalid_url' });
  });

  it('closing dates: a day closes at its end, a time is the time, garbage is unknown (and the announcement is kept)', () => {
    const eod = Date.UTC(2026, 9, 17, 23, 59, 59) + 5 * 3_600_000; // end of the day in the US (UTC-5), never earlier than the real closing
    expect(closingTime('2026-10-17')).toBe(eod);
    expect(closingTime('2026-10-17T23:59:59.9970000')).toBe(eod);
    expect(closingTime('')).toBeNull();
    expect(closingTime('2026-02-30')).toBeNull();
    expect(closingTime('soon')).toBeNull();
    const base = items[0] as { MatchedObjectDescriptor: object };
    const kept = ok(normalizeUsaJob({ ...base, MatchedObjectDescriptor: { ...base.MatchedObjectDescriptor, ApplicationCloseDate: 'soon' } }, NOW));
    expect(kept.description).not.toContain('Closing date');
  });
});

describe('USAJOBS connector', () => {
  it('sends the key and the contact e-mail as the API asks, reads a page, drops the closed one quietly and reports the rest by reason only', async () => {
    const seen: { url: string; headers: Record<string, string> }[] = [];
    const f = (async (url: string | URL | Request, init?: RequestInit) => { seen.push({ url: String(url), headers: init?.headers as Record<string, string> }); return json(fixture); }) as typeof fetch;
    const c = usaJobsConnector(f, nowFn, { apiKey: KEY, email: EMAIL });
    expect(c.presenceConfirmsOpen).toBe(true);
    const page = await c.fetchPage(null, 'discover');
    expect(seen).toHaveLength(1);
    expect(seen[0]!.url).toBe('https://data.usajobs.gov/api/search?ResultsPerPage=500&Page=1&SortField=opendate&SortDirection=desc');
    expect(seen[0]!.headers).toMatchObject({ 'Authorization-Key': KEY, 'User-Agent': EMAIL });
    expect(page.jobs.map((j) => j.externalId)).toEqual(['812345600', '812345601', '812345602']);
    expect(page.rejected).toEqual([{ externalId: '812345604', reason: 'invalid_url' }]);
    expect(page.nextCursor).toBeNull();
  });

  it('pages: a full page and more announcements behind it ask for the next page, up to the window', async () => {
    const full = { SearchResult: { SearchResultCountAll: 1200, SearchResultItems: Array.from({ length: 500 }, (_, i) => ({ MatchedObjectId: String(900000 + i), MatchedObjectDescriptor: { PositionTitle: 'T', OrganizationName: 'A', PositionURI: `https://www.usajobs.gov/job/${900000 + i}` } })) } };
    const f = (async () => json(full)) as typeof fetch;
    const c = usaJobsConnector(f, nowFn, { apiKey: KEY, email: EMAIL });
    expect((await c.fetchPage(null, 'discover')).nextCursor).toBe('2');
    expect((await c.fetchPage('2', 'discover')).nextCursor).toBe('3');
    expect((await c.fetchPage('3', 'discover')).nextCursor).toBeNull(); // 1500 >= 1200: nothing behind it
    await expect(c.fetchPage('5', 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(c.fetchPage('x', 'discover')).rejects.toThrow(/invalid cursor/);
  });

  it('without the key or the e-mail nothing is requested, and the message never carries a value', async () => {
    let calls = 0;
    const f = (async () => { calls++; return json(fixture); }) as typeof fetch;
    await expect(usaJobsConnector(f, nowFn, { email: EMAIL }).fetchPage(null, 'discover')).rejects.toThrow('USAJOBS_API_KEY is not set');
    await expect(usaJobsConnector(f, nowFn, { apiKey: KEY }).fetchPage(null, 'discover')).rejects.toThrow('USAJOBS_CONTACT_EMAIL is not set');
    await expect(usaJobsConnector(f, nowFn, { apiKey: KEY, email: 'not an email' }).fetchPage(null, 'discover')).rejects.toThrow('USAJOBS_CONTACT_EMAIL');
    expect(calls).toBe(0);
    let message = '';
    try {
      await usaJobsConnector(f, nowFn, { apiKey: KEY }).fetchPage(null, 'discover');
    } catch (e) {
      message = String(e);
    }
    expect(message).not.toContain(KEY);
  });

  it('an HTTP error (rate limit, bad key), a body that is not JSON and an unexpected shape are failures, never an empty list', async () => {
    const mk = (b: string, status = 200) => usaJobsConnector((async () => new Response(b, { status, headers: { 'retry-after': '30' } })) as typeof fetch, nowFn, { apiKey: KEY, email: EMAIL });
    await expect(mk('', 429).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
    await expect(mk('', 401).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
    await expect(mk('<html>challenge</html>').fetchPage(null, 'discover')).rejects.toMatchObject({ status: 403 });
    await expect(mk('{"SearchResult":{}}').fetchPage(null, 'discover')).rejects.toThrow(/unexpected response/);
  });
});

describe('USAJOBS source profile', () => {
  it('identifies USAJOBS and OPM, links to the terms, says the product is not endorsed, and has a small ceiling', () => {
    const s = SOURCES.usajobs!;
    expect(s.host).toBe('usajobs.gov');
    expect(s.attribution).toContain('USAJOBS');
    expect(s.attribution).toContain('https://www.usajobs.gov');
    expect(s.attribution).toContain('https://developer.usajobs.gov/guides/terms-of-service');
    expect(s.attribution).toMatch(/not operated or endorsed by the U\.S\. Office of Personnel Management/);
    expect(s.maxPages).toBe(4);
    expect(s.catalogue).toBeLessThanOrEqual(2000);
  });
});
