import { describe, expect, it } from 'vitest';
import { agencyName, normalizeNycJob, nycJobsConnector, postUntil } from '../src/connectors/nycjobs';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/nycjobs.sanitized.json';

// Real postings of the NYC Open Data dataset kpav-sd4t "Jobs NYC Postings" (read 2026-10-13): 8 External of different categories and salary
// frequencies and 1 Internal one; long texts trimmed, contacts scrubbed.
const NOW = '2026-10-13T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const recs = fixture as Record<string, unknown>[];
const external = recs.filter((r) => r.posting_type === 'External');
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (r: ReturnType<typeof normalizeNycJob>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };

describe('NYC Jobs normalizer (real postings)', () => {
  it('maps an External posting without inventing anything', () => {
    const jobs = external.map((r) => ok(normalizeNycJob(r, NOW)));
    expect(jobs).toHaveLength(8);
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'nycjobs', country: 'US', language: null, workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, geoRestrictions: [] });
      expect(j.originalUrl).toBe(`https://cityjobs.nyc.gov/job/${j.externalId}`);
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.company).not.toBe('');
      expect(j.description).not.toMatch(/<[a-z/][^>]*>/i);
      expect(j.description).toContain('Minimum qualifications');
      expect(j.publishedAt).toMatch(/^2026-/);
    }
    expect(jobs[0]).toMatchObject({ title: 'IT Project Manager', company: 'Dept of Health/Mental Hygiene', salaryMin: 75000, salaryMax: 103000, salaryCurrency: 'USD', salaryPeriod: 'year', contractType: 'Full-time' });
    const hourly = jobs.find((j) => j.salaryPeriod === 'hour')!;
    expect(hourly).toMatchObject({ salaryMin: 29.2118, salaryMax: 42.7915 });
  });

  it('never reads an Internal posting (city employees only)', () => {
    const internal = recs.find((r) => r.posting_type === 'Internal')!;
    expect(normalizeNycJob(internal, NOW)).toMatchObject({ ok: false, reason: 'internal_posting' });
    expect(normalizeNycJob({ ...external[0]!, posting_type: undefined }, NOW)).toMatchObject({ ok: false, reason: 'internal_posting' });
  });

  it('uses the closing date of the posting itself: an expired one is refused, an open-ended one is kept', () => {
    expect(postUntil('17-OCT-2026')).toBe(Date.UTC(2026, 9, 17, 23, 59, 59));
    expect(postUntil('1-jan-2027')).toBe(Date.UTC(2027, 0, 1, 23, 59, 59));
    for (const bad of ['', 'soon', '2026-10-17', '32-OCT-2026', '17-XXX-2026', null, undefined, 5]) expect(postUntil(bad), String(bad)).toBeNull();
    const r = (over: Record<string, unknown>) => normalizeNycJob({ ...external[0]!, ...over }, NOW);
    expect(r({ post_until: '12-OCT-2026' })).toMatchObject({ ok: false, reason: 'expired' });
    expect(r({ post_until: '13-OCT-2026' }).ok).toBe(true); // open through the end of that day
    expect(r({ post_until: '' }).ok).toBe(true);
    expect(r({ post_until: undefined }).ok).toBe(true);
  });

  it('a salary only with a known period and a plausible range; a city only when a borough is named', () => {
    const j = (over: Record<string, unknown>) => ok(normalizeNycJob({ ...external[0]!, ...over }, NOW));
    expect(j({ salary_frequency: 'Daily', salary_range_from: '200', salary_range_to: '300' })).toMatchObject({ salaryPeriod: 'day', salaryMin: 200, salaryMax: 300 });
    expect(j({ salary_frequency: 'Weekly' }).salaryMin).toBeNull();
    expect(j({ salary_range_from: '103000', salary_range_to: '75000' }).salaryMin).toBeNull();
    expect(j({ salary_range_from: '5', salary_range_to: '6' }).salaryMin).toBeNull();
    expect(j({ salary_range_from: 'n/a' }).salaryMin).toBeNull();
    expect(j({ salary_range_to: '' })).toMatchObject({ salaryMin: 75000, salaryMax: 75000 });
    expect(j({ work_location_1: '1 Centre St, Manhattan', work_location: '' }).city).toBe('New York City');
    expect(j({ work_location_1: '350 Jay Street, Brooklyn, NY', work_location: '' }).city).toBe('New York City');
    expect(j({ work_location_1: '59 Maiden Lane', work_location: '' }).city).toBeNull(); // an address alone does not state the borough
    expect(j({ work_location_1: 'Valhalla, Westchester', work_location: '' }).city).toBeNull();
    expect(j({ full_time_part_time_indicator: 'P' }).contractType).toBe('Part-time');
    expect(j({ full_time_part_time_indicator: '' }).contractType).toBeNull();
  });

  it('writes capital-letter agency names in title case and keeps real acronyms', () => {
    expect(agencyName('DEPT OF HEALTH/MENTAL HYGIENE')).toBe('Dept of Health/Mental Hygiene');
    expect(agencyName('NYC DEPT OF EDUCATION')).toBe('NYC Dept of Education');
    expect(agencyName('Office of Racial Equity')).toBe('Office of Racial Equity'); // already mixed case: untouched
    expect(agencyName('  ')).toBe('');
  });

  it('rejects what cannot be shown honestly, with a reason and never an exception', () => {
    const r = (over: Record<string, unknown>) => normalizeNycJob({ ...external[0]!, ...over }, NOW);
    expect(r({ job_id: '0' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ job_id: '12/../3' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ job_id: 801875 })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ business_title: ' ', civil_service_title: '' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ agency: '' })).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(normalizeNycJob(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    expect(normalizeNycJob([], NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    // the civil-service title stands in for a missing business title
    expect(ok(r({ business_title: '' })).title).toBe(String(external[0]!.civil_service_title));
  });
});

describe('NYC Jobs connector', () => {
  it('asks only for External postings, pages by 500 and stops on a short page', async () => {
    const urls: string[] = [];
    const full = Array.from({ length: 500 }, (_, i) => ({ ...external[0]!, job_id: String(1000 + i) }));
    const f = (async (u: string | URL | Request) => { urls.push(String(u)); return json(urls.length === 1 ? full : external); }) as typeof fetch;
    const c = nycJobsConnector(f, nowFn);
    expect(c).toMatchObject({ id: 'nycjobs', presenceConfirmsOpen: true });
    expect(c.minIntervalMs).toBeGreaterThanOrEqual(1000);
    const p1 = await c.fetchPage(null, 'discover');
    expect(p1.jobs).toHaveLength(500);
    expect(p1.nextCursor).toBe('500');
    const p2 = await c.fetchPage('500', 'discover');
    expect(p2.jobs).toHaveLength(8);
    expect(p2.nextCursor).toBeNull();
    expect(urls[0]).toContain("posting_type%3D'External'");
    expect(urls[0]).toContain('$order=job_id&$limit=500&$offset=0');
    expect(urls[1]).toContain('$offset=500');
    expect(new URL(urls[0]!).hostname).toBe('data.cityofnewyork.us');
  });

  it('refuses a forged cursor, an unexpected body and an HTML gate; limits surface as HttpError', async () => {
    const c = nycJobsConnector((async () => json(external)) as typeof fetch, nowFn);
    for (const bad of ['-500', '250', 'x', '4000', '9999', '500/../']) await expect(c.fetchPage(bad, 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(nycJobsConnector((async () => json({ error: true })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/unexpected response/);
    await expect(nycJobsConnector((async () => new Response('<HTML>Access Denied</HTML>', { status: 200 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toMatchObject({ status: 403 });
    await expect(nycJobsConnector((async () => new Response('', { status: 429 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
  });

  it('drops expired postings silently and records other refusals', async () => {
    const f = (async () => json([external[0], { ...external[1], post_until: '01-JAN-2020' }, { ...external[2], job_id: 'x' }, recs[8], 5])) as typeof fetch;
    const p = await nycJobsConnector(f, nowFn).fetchPage(null, 'discover');
    expect(p.jobs).toHaveLength(1);
    expect(p.rejected).toEqual([{ externalId: null, reason: 'invalid_id' }, { externalId: '801875', reason: 'internal_posting' }, { externalId: null, reason: 'not_an_object' }]);
  });

  it('is registered as a source with its attribution', () => {
    const s = SOURCES.nycjobs!;
    expect(s).toMatchObject({ id: 'nycjobs', host: 'cityjobs.nyc.gov' });
    expect(s.attribution).toMatch(/NYC Open Data/);
    expect(s.attribution).toMatch(/https:\/\/cityjobs\.nyc\.gov/);
    expect(s.make(fetch, nowFn).id).toBe('nycjobs');
  });
});
