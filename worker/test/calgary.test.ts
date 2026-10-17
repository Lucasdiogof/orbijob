import { describe, expect, it } from 'vitest';
import { calgaryConnector, normalizeCalgary } from '../src/connectors/calgary';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/calgary.sample.json';

// Real listings of the City of Calgary open-data dataset (read 2026-10-16): one per area.
const NOW = '2026-10-16T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const recs = fixture as Record<string, unknown>[];
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (r: ReturnType<typeof normalizeCalgary>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };

describe('City of Calgary normalizer (real listings)', () => {
  it('maps a listing without inventing anything: the City as employer, Calgary, Canada, its own posting page, no salary and no publication date', () => {
    const jobs = recs.map((r) => ok(normalizeCalgary(r, NOW)));
    expect(jobs).toHaveLength(10);
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'calgary', country: 'CA', city: 'Calgary', company: 'The City of Calgary', language: 'en', workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, salaryMin: null, salaryCurrency: null, publishedAt: null, geoRestrictions: [] });
      expect(j.originalUrl).toMatch(/^https:\/\/recruiting\.calgary\.ca\/psc\/hcm\/EMPLOYEE\/HRMS\/c\/HRS_HRAM_FL\.HRS_CG_SEARCH_FL\.GBL\?.*JobOpeningId=\d+/);
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.description).toMatch(/^Area: .+\nClosing date: 20\d\d-\d\d-\d\d$/);
    }
    expect(jobs[0]).toMatchObject({ externalId: '315418', title: 'Capital Grant Consultant' });
    expect(jobs[0]!.description).toBe('Area: Accounting/Finance\nClosing date: 2026-10-26');
  });

  it('a listing is open through its closing day and refused the day after', () => {
    const risk = recs.find((r) => r.job_opening_id === '315372')!; // closes 2026-10-16
    expect(normalizeCalgary(risk, '2026-10-16T23:00:00.000Z').ok).toBe(true);
    expect(normalizeCalgary(risk, '2026-10-17T12:00:00.000Z')).toEqual({ ok: false, reason: 'expired', externalId: '315372' });
  });

  it('refuses what cannot be shown honestly, with the reason', () => {
    const base = recs[0]!;
    expect(normalizeCalgary(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    expect(normalizeCalgary({ ...base, job_opening_id: 'abc' }, NOW)).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(normalizeCalgary({ ...base, title: '  ' }, NOW)).toMatchObject({ ok: false, reason: 'missing_title', externalId: '315418' });
    expect(normalizeCalgary({ ...base, job_description: 'https://evil.example/job' }, NOW)).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(normalizeCalgary({ ...base, job_description: 'http://recruiting.calgary.ca/x' }, NOW)).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(normalizeCalgary({ ...base, job_description: undefined }, NOW)).toMatchObject({ ok: false, reason: 'invalid_url' });
  });

  it('a listing without a usable closing date is kept (nothing proves it closed) and states none', () => {
    const j = ok(normalizeCalgary({ ...recs[0]!, closing_date: 'soon' }, NOW));
    expect(j.description).toBe('Area: Accounting/Finance');
  });
});

describe('City of Calgary connector', () => {
  it('reads the whole dataset in one request, stamps presence and reports refusals by reason only', async () => {
    const calls: string[] = [];
    const f = (async (url: string | URL | Request) => { calls.push(String(url)); return json([...recs, { job_opening_id: 'x', title: 'No link' }]); }) as typeof fetch;
    const c = calgaryConnector(f, nowFn);
    expect(c.presenceConfirmsOpen).toBe(true);
    const page = await c.fetchPage(null, 'discover');
    expect(calls).toEqual(['https://data.calgary.ca/resource/5fsi-n9xm.json?$limit=500']);
    expect(page.jobs).toHaveLength(10);
    expect(page.nextCursor).toBeNull();
    expect(page.rejected).toEqual([{ externalId: null, reason: 'invalid_id' }]);
  });

  it('surfaces an HTTP error, a non-JSON body and an empty answer as failures instead of an empty catalogue', async () => {
    await expect(calgaryConnector((async () => new Response('', { status: 503 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
    await expect(calgaryConnector((async () => new Response('<html>challenge</html>', { status: 200 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toMatchObject({ status: 403 });
    await expect(calgaryConnector((async () => json([])) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/holds no offers/);
    await expect(calgaryConnector((async () => json([])) as typeof fetch, nowFn).fetchPage('x', 'discover')).rejects.toThrow(/invalid cursor/);
  });
});

describe('Calgary source profile', () => {
  it('names the licence and its attribution statement, and links to its own host', () => {
    const s = SOURCES.calgary!;
    expect(s.host).toBe('calgary.ca');
    expect(s.attribution).toContain('Open Government Licence – City of Calgary');
    expect(s.attribution).toContain('https://data.calgary.ca');
    expect(s.maxPages).toBe(1);
  });
});
