import { describe, expect, it } from 'vitest';
import { GETONBOARD_CATEGORIES, getOnBoardConnector, normalizeGetOnBoard } from '../src/connectors/getonboard';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/getonboard.sanitized.json';

// Real listings of the Get on Board public API (read 2026-10-13): 10 listings of 5 categories; long texts trimmed and e-mails scrubbed.
const NOW = '2026-10-13T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const recs = fixture.data as Record<string, unknown>[];
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (r: ReturnType<typeof normalizeGetOnBoard>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
const withAttrs = (over: Record<string, unknown>) => ({ ...recs[0]!, attributes: { ...(recs[0] as { attributes: object }).attributes, ...over } });

describe('Get on Board normalizer (real listings)', () => {
  it('maps a listing without inventing anything: stated place, no salary, language only when stated', () => {
    const jobs = recs.map((r) => ok(normalizeGetOnBoard(r, NOW)));
    expect(jobs).toHaveLength(10);
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'getonboard', status: 'open', lastCheckedAt: NOW, salaryMin: null, salaryCurrency: null, salaryPeriod: null, contractType: null });
      expect(new URL(j.originalUrl).hostname).toBe('www.getonbrd.com');
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.company).not.toBe('');
      expect(j.publishedAt).toMatch(/^2026-/);
      expect(j.description).not.toMatch(/<[a-z/][^>]*>/i);
      expect(j.description.length).toBeGreaterThan(50);
      expect([null, 'es', 'en', 'pt']).toContain(j.language);
    }
    const hybridChile = jobs.find((j) => j.country === 'CL')!;
    expect(hybridChile).toMatchObject({ workMode: 'hybrid', city: 'Santiago', geoRestrictions: [] });
    expect(jobs.find((j) => j.country === 'MX')).toMatchObject({ workMode: 'hybrid' });
    expect(jobs.find((j) => j.country === 'PE')).toBeTruthy();
    // "Remote" is a mode, not a country, and says nothing about eligibility
    const remote = jobs.filter((j) => j.workMode === 'remote');
    expect(remote.length).toBeGreaterThan(0);
    for (const j of remote) expect(j).toMatchObject({ country: null, city: null, geoRestrictions: [] });
    expect(jobs.some((j) => j.language === 'es')).toBe(true);
    expect(jobs.some((j) => j.language === null)).toBe(true); // lang_not_specified stays empty
  });

  it('remote work: eligibility only from countries the listing names, a single one becomes the country', () => {
    const j = (over: Record<string, unknown>) => ok(normalizeGetOnBoard(withAttrs(over), NOW));
    expect(j({ remote_modality: 'remote_local', countries: ['Colombia'], location_cities: { data: [] } })).toMatchObject({ workMode: 'remote', country: 'CO', geoRestrictions: [] });
    expect(j({ remote_modality: 'remote_local', countries: ['Chile', 'Perú', 'Brasil'], location_cities: { data: [] } })).toMatchObject({ workMode: 'remote', country: null, geoRestrictions: ['CL', 'PE', 'BR'] });
    expect(j({ remote_modality: 'fully_remote', countries: ['Remote'], location_cities: { data: [] } })).toMatchObject({ workMode: 'remote', country: null, geoRestrictions: [] });
    expect(j({ remote_modality: 'fully_remote', countries: ['Remote', 'Atlantis'], location_cities: { data: [] } })).toMatchObject({ geoRestrictions: ['Atlantis'] });
    expect(j({ remote_modality: 'temporarily_remote' }).workMode).toBe('unspecified');
    expect(j({ remote_modality: 'no_remote' }).workMode).toBe('onsite');
    expect(j({ remote_modality: 'something_new' }).workMode).toBe('unspecified');
  });

  it('on-site work takes the country from the city record, never from the language', () => {
    const city = (name: string, country: string) => ({ type: 'tenant_city', id: '1', attributes: { name, country } });
    const j = (cities: unknown[], over: Record<string, unknown> = {}) => ok(normalizeGetOnBoard(withAttrs({ remote_modality: 'hybrid', location_cities: { data: cities }, ...over }), NOW));
    expect(j([city('Bogotá', 'Colombia')])).toMatchObject({ country: 'CO', city: 'Bogotá' });
    expect(j([city('São Paulo', 'Brasil')])).toMatchObject({ country: 'BR' });
    expect(j([city('Santiago', 'Chile'), city('Concepción', 'Chile')])).toMatchObject({ country: 'CL', city: 'Santiago, Concepción' });
    expect(j([city('Lima', 'Peru'), city('Quito', 'Ecuador')])).toMatchObject({ country: null }); // two countries: none is stated alone
    expect(j([city('Nowhere', 'Zzzland')])).toMatchObject({ country: null, city: 'Nowhere' });
    expect(j([], { countries: ['Mexico'] })).toMatchObject({ country: 'MX', city: null });
    expect(j([], { countries: ['Mexico'], lang: 'es' }).language).toBe('es');
    expect(j([], { lang: 'de' }).language).toBeNull();
  });

  it('rejects what cannot be shown honestly, with a reason and never an exception', () => {
    const r = (over: Record<string, unknown>) => normalizeGetOnBoard({ ...recs[0]!, ...over }, NOW);
    expect(r({ id: '../x' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ id: '' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(normalizeGetOnBoard(withAttrs({ title: '  ' }), NOW)).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(normalizeGetOnBoard(withAttrs({ company: { data: { id: 'x', type: 'company' } } }), NOW)).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(r({ links: { public_url: 'https://evil.example/jobs/x' } })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ links: { public_url: 'http://www.getonbrd.com/jobs/x' } })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ links: {} })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(normalizeGetOnBoard(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    expect(normalizeGetOnBoard([], NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
  });

  it('keeps the description to plain text with the platform\'s own section headlines, capped', () => {
    const long = '<p>' + 'palabra '.repeat(2000) + '</p>';
    const j = ok(normalizeGetOnBoard(withAttrs({ description: long, functions: '<ul><li>Uno</li><li>Dos</li></ul>', functions_headline: '¿Qué harás?' }), NOW));
    expect(j.description.length).toBeLessThanOrEqual(6001);
    expect(j.description.endsWith('…')).toBe(true);
    const short = ok(normalizeGetOnBoard(withAttrs({ description: '<p>Hola</p>', description_headline: 'Requisitos', projects: '', benefits: '', desirable: '', functions: '<ul><li>Uno</li><li>Dos</li></ul>', functions_headline: '¿Qué harás?' }), NOW));
    expect(short.description).toContain('Requisitos\nHola');
    expect(short.description).toContain('¿Qué harás?');
    expect(short.description).toMatch(/Uno/);
  });
});

describe('Get on Board connector', () => {
  const page = (data: unknown[], total = 1) => json({ data, meta: { page: 1, per_page: 100, total_pages: total } });

  it('walks every category in order, then every page of a category, and stops at the end', async () => {
    const urls: string[] = [];
    const f = (async (u: string | URL | Request) => {
      urls.push(String(u));
      return page(recs, urls.length === 1 ? 2 : 1);
    }) as typeof fetch;
    const c = getOnBoardConnector(f, nowFn);
    expect(c).toMatchObject({ id: 'getonboard', presenceConfirmsOpen: true });
    expect(c.minIntervalMs).toBeGreaterThanOrEqual(2000);
    let cursor: string | null = null;
    let jobs = 0;
    let pages = 0;
    do {
      const p = await c.fetchPage(cursor, 'discover');
      jobs += p.jobs.length;
      pages++;
      expect(p.isFullSnapshot).toBe(false);
      cursor = p.nextCursor;
    } while (cursor !== null);
    expect(pages).toBe(GETONBOARD_CATEGORIES.length + 1); // first category has 2 pages
    expect(jobs).toBe(pages * 10);
    expect(urls[0]).toContain('/api/v0/categories/programming/jobs?per_page=100&page=1&expand=');
    expect(urls[1]).toContain('/categories/programming/jobs?per_page=100&page=2');
    expect(urls[2]).toContain('/categories/mobile-developer/jobs?per_page=100&page=1');
    expect(new Set(urls.map((u) => new URL(u).hostname))).toEqual(new Set(['www.getonbrd.com']));
  });

  it('refuses a forged cursor, an unexpected body and an HTML gate; rate limits surface as HttpError', async () => {
    const f = (async () => page(recs)) as typeof fetch;
    const c = getOnBoardConnector(f, nowFn);
    for (const bad of ['x', '99:1', '0:0', '0:999', '1', '-1:1', '0:1/../']) await expect(c.fetchPage(bad, 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(getOnBoardConnector((async () => json({ nope: 1 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/unexpected response/);
    await expect(getOnBoardConnector((async () => new Response('<html>Just a moment</html>', { status: 200 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toMatchObject({ status: 403 });
    await expect(getOnBoardConnector((async () => new Response('', { status: 429, headers: { 'retry-after': '30' } })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
  });

  it('records rejected listings and keeps the rest', async () => {
    const f = (async () => page([recs[0], { ...recs[1], id: '../bad' }, 'junk'])) as typeof fetch;
    const p = await getOnBoardConnector(f, nowFn).fetchPage(null, 'discover');
    expect(p.jobs).toHaveLength(1);
    expect(p.rejected).toEqual([{ externalId: null, reason: 'invalid_id' }, { externalId: null, reason: 'not_an_object' }]);
  });

  it('is registered as a source with attribution and a catalogue ceiling', () => {
    expect(SOURCES.getonboard).toMatchObject({ id: 'getonboard', host: 'getonbrd.com' });
    expect(SOURCES.getonboard!.attribution).toMatch(/Get on Board \(https:\/\/www\.getonbrd\.com\)/);
    expect(SOURCES.getonboard!.make(fetch, nowFn).id).toBe('getonboard');
  });
});
