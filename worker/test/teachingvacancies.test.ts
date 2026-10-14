import { describe, expect, it } from 'vitest';
import { normalizeTeachingVacancies, parseSalary, teachingVacanciesConnector } from '../src/connectors/teachingvacancies';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/teachingvacancies.sanitized.json';

// Real listings of the Teaching Vacancies open API (read 2026-10-13): 14 listings of 14 categories; texts trimmed, contacts scrubbed.
const NOW = '2026-10-13T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const recs = fixture.data as Record<string, unknown>[];
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (r: ReturnType<typeof normalizeTeachingVacancies>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
const money = (value: string, unitText = 'YEAR', currency = 'GBP') => ({ '@type': 'MonetaryAmount', currency, value: { '@type': 'QuantitativeValue', value, unitText } });

describe('Teaching Vacancies normalizer (real listings)', () => {
  it('maps a listing without inventing anything: the stated country, no language, no work mode, the listing\'s own page as the link', () => {
    const jobs = recs.map((r) => ok(normalizeTeachingVacancies(r, NOW)));
    expect(jobs).toHaveLength(14);
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'teachingvacancies', country: 'GB', language: null, workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, geoRestrictions: [] });
      expect(new URL(j.originalUrl).hostname).toBe('teaching-vacancies.service.gov.uk');
      expect(j.originalUrl).toContain(`/jobs/${j.externalId}`);
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.company).not.toBe('');
      expect(j.description).not.toMatch(/<[a-z/][^>]*>/i);
      expect(j.publishedAt).toMatch(/^202[4-6]-/);
    }
    expect(jobs[0]).toMatchObject({ title: 'Exam Invigilator', city: 'Birmingham', contractType: 'Part-time', salaryMin: 13.45, salaryMax: 13.45, salaryCurrency: 'GBP', salaryPeriod: 'hour' });
    expect(new Set(jobs.map((j) => j.externalId)).size).toBe(14);
  });

  it('a salary is stored only when the text states one or two plain amounts and the listing gives the period', () => {
    const s = (v: string, unit = 'YEAR', cur = 'GBP') => parseSalary(money(v, unit, cur));
    expect(s('£31,015 to £33,673')).toEqual({ min: 31015, max: 33673, currency: 'GBP', period: 'year' });
    expect(s('£37,597.00 - £39,598.00 Annually (FTE)')).toMatchObject({ min: 37597, max: 39598 });
    expect(s('£25,989.00 - £25,989.00 Annually (FTE)')).toMatchObject({ min: 25989, max: 25989 });
    expect(s('£13.45 per hour', 'HOUR')).toMatchObject({ min: 13.45, max: 13.45, period: 'hour' });
    expect(s('£24,884.87 - £26,531')).toMatchObject({ min: 24884.87, max: 26531 });
    expect(s('£26,847 per annum pro rata')).toMatchObject({ min: 26847, period: 'year' });
    // ambiguous or not an amount: nothing is shown
    expect(s('Grade 3 Point 5 - 6')).toBeNull();
    expect(s('ECT/MPS')).toBeNull();
    expect(s('L9 -11 (£65,277 to £68,691)')).toBeNull();
    expect(s('£41,817 - £63,996 + TLR 2c')).toBeNull();
    expect(s('£26,847 - £27,709 per annum pro rata | £18,723 - £19,763 per annum')).toBeNull();
    expect(s('From £30,000')).toBeNull();
    expect(s('Up to £30,000')).toBeNull();
    expect(s('£31,015 to £33,673', 'YEAR', 'EUR')).toBeNull();
    expect(s('£31,015 to £33,673', 'FORTNIGHT')).toBeNull();
    expect(s('£33,673 to £31,015')).toBeNull(); // upside down
    expect(s('£3,000,000')).toBeNull(); // implausible for a year
    expect(s('£1.50', 'HOUR')).toBeNull(); // implausible for an hour
    expect(parseSalary(null)).toBeNull();
    expect(parseSalary({ currency: 'GBP' })).toBeNull();
  });

  it('refuses an expired listing and what cannot be shown honestly, with a reason and never an exception', () => {
    const base = recs[1]!;
    const r = (over: Record<string, unknown>) => normalizeTeachingVacancies({ ...base, ...over }, NOW);
    expect(r({ validThrough: '2026-10-12T23:59:00+00:00' })).toMatchObject({ ok: false, reason: 'expired' });
    expect(r({ validThrough: '2026-10-13T15:00:00+01:00' }).ok).toBe(true);
    expect(r({ validThrough: null }).ok).toBe(true);
    expect(r({ url: 'https://evil.example/jobs/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'http://teaching-vacancies.service.gov.uk/jobs/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'https://teaching-vacancies.service.gov.uk/pages/terms' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'https://teaching-vacancies.service.gov.uk/jobs/../../x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ title: '  ' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ hiringOrganization: { name: '' } })).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(normalizeTeachingVacancies(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    expect(normalizeTeachingVacancies([], NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    // a missing country or place stays empty
    const j = ok(r({ jobLocation: { address: { addressLocality: null, addressRegion: 'South East' } } }));
    expect(j).toMatchObject({ country: null, city: 'South East' });
  });

  it('joins the benefits to the description and caps the text', () => {
    const j = ok(normalizeTeachingVacancies({ ...recs[3]!, description: '<p>' + 'word '.repeat(3000) + '</p>', jobBenefits: '<p>Free parking</p>' }, NOW));
    expect(j.description.length).toBeLessThanOrEqual(6001);
    const k = ok(normalizeTeachingVacancies({ ...recs[3]!, description: '<p>Teach maths.</p>', jobBenefits: '<p>Free parking</p>' }, NOW));
    expect(k.description).toBe('Teach maths.\n\nFree parking');
  });
});

describe('Teaching Vacancies connector', () => {
  const page = (data: unknown[], totalPages: number) => json({ data, meta: { totalPages, count: totalPages * 100 } });

  it('reads every page in order and stops at the last one', async () => {
    const urls: string[] = [];
    const f = (async (u: string | URL | Request) => { urls.push(String(u)); return page(recs, 3); }) as typeof fetch;
    const c = teachingVacanciesConnector(f, nowFn);
    expect(c).toMatchObject({ id: 'teachingvacancies', presenceConfirmsOpen: true });
    expect(c.minIntervalMs).toBeGreaterThanOrEqual(1500);
    let cursor: string | null = null;
    let jobs = 0;
    do {
      const p = await c.fetchPage(cursor, 'discover');
      jobs += p.jobs.length;
      expect(p.isFullSnapshot).toBe(false);
      cursor = p.nextCursor;
    } while (cursor !== null);
    expect(urls).toEqual([1, 2, 3].map((n) => `https://teaching-vacancies.service.gov.uk/api/v1/jobs.json?page=${n}`));
    expect(jobs).toBe(42);
  });

  it('refuses a forged cursor, an unexpected body and an HTML gate; limits surface as HttpError', async () => {
    const c = teachingVacanciesConnector((async () => page(recs, 1)) as typeof fetch, nowFn);
    for (const bad of ['0', '-1', 'x', '91', '1.5', '1/../']) await expect(c.fetchPage(bad, 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(teachingVacanciesConnector((async () => json({ nope: 1 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/unexpected response/);
    await expect(teachingVacanciesConnector((async () => new Response('<html>blocked</html>', { status: 200 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toMatchObject({ status: 403 });
    await expect(teachingVacanciesConnector((async () => new Response('', { status: 429 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
  });

  it('expired listings are dropped silently, other refusals are recorded', async () => {
    const f = (async () => page([recs[0], { ...recs[1], validThrough: '2020-01-01T00:00:00+00:00' }, { ...recs[2], url: 'https://x.example/jobs/y' }, 7], 1)) as typeof fetch;
    const p = await teachingVacanciesConnector(f, nowFn).fetchPage(null, 'discover');
    expect(p.jobs).toHaveLength(1);
    expect(p.rejected).toEqual([{ externalId: null, reason: 'invalid_url' }, { externalId: null, reason: 'not_an_object' }]);
  });

  it('is registered as a source with the OGL attribution and a ceiling that keeps one source from dominating', () => {
    const s = SOURCES.teachingvacancies!;
    expect(s).toMatchObject({ id: 'teachingvacancies', host: 'teaching-vacancies.service.gov.uk' });
    expect(s.attribution).toMatch(/Open Government Licence/);
    expect(s.attribution).toMatch(/https:\/\/teaching-vacancies\.service\.gov\.uk/);
    // never the biggest source of the catalogue: its ceiling stays below the largest ceiling of the other sources
    const others = Object.values(SOURCES).filter((o) => o.id !== 'teachingvacancies').map((o) => o.catalogue);
    expect(s.catalogue).toBeLessThan(Math.max(...others));
    expect(s.make(fetch, nowFn).id).toBe('teachingvacancies');
  });
});
