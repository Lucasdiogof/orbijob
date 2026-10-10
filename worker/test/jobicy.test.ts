import { describe, expect, it } from 'vitest';
import { JOBICY_SOURCE, jobicyConnector, normalizeJobicy } from '../src/connectors/jobicy';
import { parseGeo } from '../src/geo';
import { decodeEntities, htmlToText } from '../src/text';
import feed from './fixtures/jobicy-feed.sanitized.json';
import statusFixture from './fixtures/jobicy-status.json';

// Fixtures are REAL Jobicy API v2 payloads captured 2026-10-09 with the descriptions truncated and logos replaced.
const NOW = '2026-10-09T23:30:00.000Z';
const jobs = feed.jobs as Record<string, unknown>[];
const byId = (id: number) => jobs.find((j) => j.id === id)!;
const ok = (raw: unknown) => {
  const r = normalizeJobicy(raw, NOW);
  if (!r.ok) throw new Error(`expected a valid job, got ${r.reason}`);
  return r.job;
};
const res = (status: number, body: unknown = {}, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers });

describe('normalizeJobicy (real payloads)', () => {
  it('maps a complete listing without inventing anything', () => {
    expect(ok(byId(154956))).toMatchObject({
      source: 'jobicy', externalId: '154956', company: 'Juniper Square', title: 'Account Executive, Private Equity',
      workMode: 'remote', country: 'US', city: null, language: null, contractType: 'Full-Time',
      salaryMin: 120000, salaryMax: 145000, salaryCurrency: 'USD', salaryPeriod: 'year',
      geoRestrictions: ['US'], status: 'open', lastCheckedAt: NOW,
      originalUrl: 'https://jobicy.com/jobs/154956-account-executive-private-equity',
    });
  });

  it('keeps the Jobicy URL as both the original and the apply link (attribution is never dropped)', () => {
    for (const raw of jobs) {
      const j = ok(raw);
      expect(new URL(j.originalUrl).hostname).toBe('jobicy.com');
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.source).toBe(JOBICY_SOURCE.id);
    }
    expect(JOBICY_SOURCE.attribution).toContain('Jobicy');
  });

  it('maps an hourly contract salary', () => {
    expect(ok(byId(154950))).toMatchObject({ contractType: 'Contract', salaryMin: 60, salaryMax: 70, salaryCurrency: 'USD', salaryPeriod: 'hour' });
  });

  it('leaves salary null when the source sent none', () => {
    const j = ok(byId(154943));
    expect([j.salaryMin, j.salaryMax, j.salaryCurrency, j.salaryPeriod]).toEqual([null, null, null, null]);
    expect(j.country).toBe('AU');
  });

  it('drops a salary range that has no currency instead of guessing one', () => {
    const raw = byId(154930);
    expect(raw.salaryMin).toBe(121000); // the real payload does carry amounts...
    const j = ok(raw);
    expect([j.salaryMin, j.salaryMax, j.salaryCurrency, j.salaryPeriod]).toEqual([null, null, null, null]); // ...but no currency
  });

  it('rejects inconsistent salary data (min > max, unknown period, bad currency)', () => {
    const base = { ...byId(154956) };
    for (const bad of [{ salaryMin: 9, salaryMax: 3 }, { salaryPeriod: 'fortnightly' }, { salaryCurrency: 'dollars' }, { salaryMin: -5, salaryMax: null }]) {
      const j = ok({ ...base, ...bad });
      expect(j.salaryMin === null && j.salaryCurrency === null && j.salaryPeriod === null).toBe(true);
    }
  });

  it('decodes HTML entities in names (real case: "hims &#038; hers")', () => {
    expect(byId(154909).companyName).toBe('hims &#038; hers');
    expect(ok(byId(154909)).company).toBe('hims & hers');
  });

  describe('location', () => {
    it('several countries: country stays null, every eligible country is kept as ISO code', () => {
      const j = ok(byId(154925));
      expect(j.country).toBeNull();
      expect(j.geoRestrictions).toEqual(['CA', 'IE', 'NL', 'PT', 'GB', 'US']);
    });
    it('a region is kept as a region, not expanded to countries', () => {
      expect(ok(byId(154905))).toMatchObject({ country: null, geoRestrictions: ['Europe'] });
      expect(ok(byId(154903))).toMatchObject({ country: null, geoRestrictions: ['EMEA'] });
    });
    it('two countries (UK, Sweden): ambiguous, so no single country', () => {
      expect(ok(byId(154910))).toMatchObject({ country: null, geoRestrictions: ['SE', 'GB'] });
    });
    it('"Anywhere" is kept as an explicit marker; unknown names are preserved as written; a missing location stays EMPTY (unknown, not global)', () => {
      expect(ok({ ...byId(154956), jobGeo: 'Anywhere' })).toMatchObject({ country: null, geoRestrictions: ['Anywhere'] });
      expect(ok({ ...byId(154956), jobGeo: 'Atlantis, USA' })).toMatchObject({ country: null, geoRestrictions: ['US', 'Atlantis'] });
      expect(ok({ ...byId(154956), jobGeo: undefined })).toMatchObject({ country: null, geoRestrictions: [] });
    });
    it('parseGeo handles the real separator (comma + two spaces), accents and repeats', () => {
      expect(parseGeo('Canada,  USA,  USA')).toMatchObject({ countries: ['CA', 'US'] });
      expect(parseGeo('Türkiye')).toMatchObject({ countries: ['TR'] });
      expect(parseGeo('UAE').countries).toEqual(['AE']);
    });
  });

  describe('invalid or incomplete records', () => {
    const cases: [string, Record<string, unknown>, string][] = [
      ['missing id', { id: undefined }, 'invalid_id'],
      ['zero id', { id: 0 }, 'invalid_id'],
      ['text id', { id: 'abc' }, 'invalid_id'],
      ['blank title', { jobTitle: '   ' }, 'missing_title'],
      ['markup-only title', { jobTitle: '<b></b>' }, 'missing_title'],
      ['garbage url', { url: 'not a url' }, 'invalid_url'],
      ['http url', { url: 'http://jobicy.com/jobs/1' }, 'invalid_url'],
      ['foreign host', { url: 'https://evil.example/jobs/1' }, 'invalid_url'],
      ['look-alike host', { url: 'https://jobicy.com.evil.example/jobs/1' }, 'invalid_url'],
      ['credentials in url', { url: 'https://user:pw@jobicy.com/jobs/1' }, 'invalid_url'],
      ['javascript url', { url: 'javascript:alert(1)' }, 'invalid_url'],
    ];
    it.each(cases)('rejects %s', (_n, patch, reason) => {
      const r = normalizeJobicy({ ...byId(154956), ...patch }, NOW);
      expect(r).toMatchObject({ ok: false, reason });
    });
    it('rejects non-objects', () => {
      for (const v of [null, undefined, 'x', 7, [], true]) expect(normalizeJobicy(v, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    });
    it('accepts a sparse record: only id, title and url are required; company may be empty', () => {
      const j = ok({ id: 5, jobTitle: 'Barista', url: 'https://jobicy.com/jobs/5-barista' });
      expect(j).toMatchObject({ company: '', description: '', publishedAt: null, contractType: null, geoRestrictions: [], country: null });
    });
    it('a bad date becomes null, not "Invalid Date"', () => {
      expect(ok({ ...byId(154956), pubDate: 'yesterday-ish' }).publishedAt).toBeNull();
      expect(ok(byId(154956)).publishedAt).toBe('2026-10-09T18:42:49.000Z');
    });
  });
});

describe('plain-text reduction (job HTML is never stored as HTML)', () => {
  it('removes scripts, handlers, iframes and markup but keeps the readable text', () => {
    const dirty = '<p>Hello <b>team</b></p><script>alert(1)</script><img src=x onerror=alert(2)><iframe src="//e.x"></iframe><ul><li>One</li><li>Two</li></ul><!-- c -->';
    const t = htmlToText(dirty);
    expect(t).not.toMatch(/<|alert|onerror|iframe|script/);
    expect(t).toBe('Hello team\n\n- One\n- Two'.replace('\n\n-', '\n\n-'));
  });
  it('escaped markup stays visible as text and is not turned into tags', () => {
    expect(htmlToText('&lt;script&gt;x&lt;/script&gt; and &amp;lt;b&amp;gt;')).toBe('<script>x</script> and &lt;b&gt;');
  });
  it('decodes numeric, hex and named entities once; leaves unknown ones alone', () => {
    expect(decodeEntities('a &#038; b &#x26; c &amp; d &nbsp;e &bogus; &#0; &#xD800;')).toBe('a & b & c & d  e &bogus; &#0; &#xD800;');
  });
  it('normalizes the description of a real listing', () => {
    const d = ok(byId(154956)).description;
    expect(d.length).toBeGreaterThan(20);
    expect(d).not.toMatch(/<[a-z]/i);
  });
  it('a hostile description cannot leak markup through normalization', () => {
    const j = ok({ ...byId(154956), jobDescription: '<img src=x onerror="steal()"><a href="javascript:x()">hi</a>' });
    expect(j.description).toBe('hi');
  });
});

describe('jobicyConnector.fetchPage', () => {
  const page = (js: unknown[], next: string | null) => ({ success: true, statusCode: 200, jobs: js, nextCursor: next, hasMore: !!next });

  it('requests 100 per page, forwards the scope filters and the opaque cursor unchanged, URL-encoded', async () => {
    const urls: string[] = [];
    const f = (async (u: string) => (urls.push(u), res(200, page([], null)))) as unknown as typeof fetch;
    const c = jobicyConnector(f, () => new Date(NOW));
    await c.fetchPage(null, 'geo=usa&industry=engineering');
    await c.fetchPage('Ag AA+/=', 'geo=usa&industry=engineering');
    const first = new URL(urls[0]!);
    expect(first.origin + first.pathname).toBe('https://jobicy.com/api/v2/remote-jobs');
    expect(Object.fromEntries(first.searchParams)).toEqual({ geo: 'usa', industry: 'engineering', count: '100' });
    expect(new URL(urls[1]!).searchParams.get('cursor')).toBe('Ag AA+/=');
    expect(urls[1]).toContain('cursor=Ag+AA%2B%2F%3D');
  });

  it('never claims a full snapshot (the feed is a 7-day window) and ends when nextCursor is null', async () => {
    const f = (async () => res(200, page(jobs.slice(0, 3), null))) as unknown as typeof fetch;
    const p = await jobicyConnector(f, () => new Date(NOW)).fetchPage(null, '');
    expect(p).toMatchObject({ nextCursor: null, isFullSnapshot: false });
    expect(p.jobs).toHaveLength(3);
  });

  it('continues while a cursor is present', async () => {
    const f = (async () => res(200, page(jobs.slice(0, 2), 'NEXT'))) as unknown as typeof fetch;
    expect((await jobicyConnector(f, () => new Date(NOW)).fetchPage(null, '')).nextCursor).toBe('NEXT');
  });

  it('reports rejected records by reason and keeps the valid ones', async () => {
    const bad = [{ id: 1, jobTitle: 'x', url: 'https://evil.example/1' }, { id: 'zz' }, jobs[0]];
    const f = (async () => res(200, page(bad, null))) as unknown as typeof fetch;
    const p = await jobicyConnector(f, () => new Date(NOW)).fetchPage(null, '');
    expect(p.jobs).toHaveLength(1);
    expect(p.rejected).toEqual([{ externalId: '1', reason: 'invalid_url' }, { externalId: null, reason: 'invalid_id' }]);
  });

  it('treats an empty list as a valid empty page', async () => {
    const f = (async () => res(200, page([], null))) as unknown as typeof fetch;
    expect((await jobicyConnector(f).fetchPage(null, '')).jobs).toEqual([]);
  });

  it.each([429, 500, 503, 400])('surfaces HTTP %i as HttpError with the status', async (status) => {
    const f = (async () => res(status, {}, { 'retry-after': '3' })) as unknown as typeof fetch;
    await expect(jobicyConnector(f).fetchPage(null, '')).rejects.toMatchObject({ status });
  });

  it('rejects a 200 whose body is not the documented shape (success:false, no jobs array, null)', async () => {
    for (const body of [{ success: false, error: 'bad' }, { success: true }, null]) {
      const f = (async () => res(200, body)) as unknown as typeof fetch;
      await expect(jobicyConnector(f).fetchPage(null, '')).rejects.toThrow(/unexpected response/);
    }
  });
});

describe('jobicyConnector.checkStatuses', () => {
  it('maps active/closed/unknown and answers only for the ids asked (real response shape)', async () => {
    const urls: string[] = [];
    const f = (async (u: string) => (urls.push(u), res(200, statusFixture))) as unknown as typeof fetch;
    const ids = (statusFixture.jobs as { id: number }[]).map((j) => String(j.id));
    const out = await jobicyConnector(f).checkStatuses!(ids);
    expect(urls[0]).toBe(`https://jobicy.com/api/v2/remote-jobs/status?ids=${ids.join(',')}`);
    expect(out['154956']).toBe('open');
    expect(out['1']).toBe('unknown');
    expect(Object.keys(out)).toHaveLength(11);
  });

  it('splits into batches of at most 100 ids and ignores invalid ids', async () => {
    const sizes: number[] = [];
    const f = (async (u: string) => {
      const ids = new URL(u).searchParams.get('ids')!.split(',');
      sizes.push(ids.length);
      return res(200, { success: true, jobs: ids.map((id) => ({ id: Number(id), status: 'closed' })) });
    }) as unknown as typeof fetch;
    const ids = Array.from({ length: 250 }, (_, i) => String(i + 1));
    const out = await jobicyConnector(f).checkStatuses!([...ids, 'abc', '0', '-3']);
    expect(sizes).toEqual([100, 100, 50]);
    expect(Object.keys(out)).toHaveLength(250);
  });

  it('an unrecognised status is "unknown", never "closed"; unsolicited ids are ignored', async () => {
    const f = (async () => res(200, { success: true, jobs: [{ id: 7, status: 'weird' }, { id: 8, status: 'closed' }, { id: 99, status: 'closed' }] })) as unknown as typeof fetch;
    expect(await jobicyConnector(f).checkStatuses!(['7', '8'])).toEqual({ '7': 'unknown', '8': 'closed' });
  });

  it('a failing status request throws instead of pretending the jobs are closed', async () => {
    const f = (async () => res(500)) as unknown as typeof fetch;
    await expect(jobicyConnector(f).checkStatuses!(['1'])).rejects.toMatchObject({ status: 500 });
  });
});
