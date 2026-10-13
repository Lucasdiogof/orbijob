import { describe, expect, it } from 'vitest';
import { foremConnector, foremPlaces, normalizeForem } from '../src/connectors/forem';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/forem.sanitized.json';

// Real offers of Le Forem from Open Data Wallonie-Bruxelles (read 2026-10-13): 11 offers (different contracts, boards, provinces).
const NOW = '2026-10-13T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const recs = fixture as Record<string, unknown>[];
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (r: ReturnType<typeof normalizeForem>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };

describe('Le Forem normalizer (real offers)', () => {
  it('maps an offer without inventing anything: the stated country, only stated facts in the description, the offer\'s own page, no salary', () => {
    const jobs = recs.map((r) => ok(normalizeForem(r, NOW)));
    expect(jobs).toHaveLength(11);
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'forem', country: 'BE', language: null, workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, salaryMin: null, salaryCurrency: null });
      expect(j.originalUrl).toBe(`https://www.leforem.be/recherche-offres/offre-detail/${j.externalId}`);
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.company).not.toBe('');
      expect(j.contractType).toBeTruthy();
      expect(j.description).toMatch(/Type de contrat : /);
      expect(j.publishedAt).toMatch(/^2026-/);
    }
    expect(jobs[0]).toMatchObject({ externalId: '2110283', company: "LET'S WORK", city: 'Staden', contractType: 'Intérimaire avec option sur durée indéterminée, Temps plein' });
    expect(jobs[0]!.description).toContain('Offre diffusée via : Let\'s Work');
    // an offer published by the Forem itself does not repeat "via the Forem"; an offer with no locality has no city
    const own = jobs.find((j) => j.externalId === '2079926')!;
    expect(own.description).not.toMatch(/Offre diffusée via/);
    expect(own.city).toBeNull();
  });

  it('the country comes from the regions the offer lists, in any order; several countries are eligibility, never one country', () => {
    expect(foremPlaces(['Belgique', 'Province de Namur', 'RÉGION WALLONNE'])).toEqual({ country: 'BE', restrictions: [] });
    expect(foremPlaces(['Province de Liège', 'Belgique', 'RÉGION WALLONNE'])).toEqual({ country: 'BE', restrictions: [] });
    expect(foremPlaces(['Espagne'])).toEqual({ country: 'ES', restrictions: [] });
    expect(foremPlaces(['Nord-Pas de Calais', 'France', 'Hauts-de-France'])).toEqual({ country: 'FR', restrictions: [] });
    expect(foremPlaces(['Malte', 'Pays-Bas'])).toEqual({ country: null, restrictions: ['MT', 'NL'] });
    expect(foremPlaces(['Belgique', 'Belgique'])).toEqual({ country: 'BE', restrictions: [] });
    for (const none of [[], null, undefined, 'Belgique', ['Province de Liège'], ['Atlantide']]) expect(foremPlaces(none), JSON.stringify(none)).toEqual({ country: null, restrictions: [] });
    const abroad = ok(normalizeForem({ ...recs[0]!, lieuxtravailregion: ['Malte', 'Pays-Bas'] }, NOW));
    expect(abroad).toMatchObject({ country: null, geoRestrictions: ['MT', 'NL'] });
  });

  it('refuses an offer whose diffusion has ended; keeps one with no end date', () => {
    const r = (over: Record<string, unknown>) => normalizeForem({ ...recs[0]!, ...over }, NOW);
    expect(r({ datefindiffusion: '2026-10-12' })).toMatchObject({ ok: false, reason: 'expired' });
    expect(r({ datefindiffusion: '2026-10-13' }).ok).toBe(true);
    expect(r({ datefindiffusion: null }).ok).toBe(true);
    expect(r({ datefindiffusion: 'bientôt' }).ok).toBe(true); // an unreadable date proves nothing
  });

  it('rejects what cannot be shown honestly, with a reason and never an exception', () => {
    const r = (over: Record<string, unknown>) => normalizeForem({ ...recs[0]!, ...over }, NOW);
    expect(r({ numerooffreforem: '0' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ numerooffreforem: '../1' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ numerooffreforem: undefined })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(ok(r({ numerooffreforem: 2110283 })).externalId).toBe('2110283'); // a number is read too
    expect(r({ titreoffre: ' ' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ nomemployeur: '' })).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(r({ url: 'https://evil.example/offre/1' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'http://www.leforem.be/offre/1' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: null })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(normalizeForem(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    expect(normalizeForem([], NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
  });

  it('writes upper-case localities in normal case and joins up to three', () => {
    expect(ok(normalizeForem({ ...recs[0]!, lieuxtravaillocalite: ['NEUFCHÂTEAU', 'LIÈGE', 'SAINT-GHISLAIN', 'MONS'] }, NOW)).city).toBe('Neufchâteau, Liège, Saint-Ghislain');
    expect(ok(normalizeForem({ ...recs[0]!, lieuxtravaillocalite: [] }, NOW)).city).toBeNull();
  });
});

describe('Le Forem connector', () => {
  const page = (rows: unknown[], total: number) => json({ total_count: total, results: rows });

  it('asks for the offers still being diffused, newest first, 100 at a time, and stops at the window or the end', async () => {
    const urls: string[] = [];
    const full = Array.from({ length: 100 }, (_, i) => ({ ...recs[0]!, numerooffreforem: String(3000000 + i), url: `https://www.leforem.be/recherche-offres/offre-detail/${3000000 + i}` }));
    const f = (async (u: string | URL | Request) => { urls.push(String(u)); return urls.length < 3 ? page(full, 25000) : page(full.slice(0, 10), 210); }) as typeof fetch;
    const c = foremConnector(f, nowFn);
    expect(c).toMatchObject({ id: 'forem', presenceConfirmsOpen: true });
    let cursor: string | null = null;
    let jobs = 0;
    do {
      const p = await c.fetchPage(cursor, 'discover');
      jobs += p.jobs.length;
      cursor = p.nextCursor;
    } while (cursor !== null);
    expect(jobs).toBe(210);
    expect(urls).toHaveLength(3);
    expect(urls[0]).toContain('/offres-d-emploi-forem/records?where=datefindiffusion%20%3E%3D%20now()');
    expect(urls[0]).toContain('order_by=datedebutdiffusion%20desc%2C%20numerooffreforem%20desc&limit=100&offset=0');
    expect(urls[2]).toContain('offset=200');
    expect(new URL(urls[0]!).hostname).toBe('www.odwb.be');
    // the window ends at 25 pages even if the dataset has more
    const long = foremConnector((async () => page(full, 25000)) as typeof fetch, nowFn);
    expect((await long.fetchPage('2400', 'discover')).nextCursor).toBeNull();
    expect((await long.fetchPage('2300', 'discover')).nextCursor).toBe('2400');
  });

  it('refuses a forged cursor, an unexpected body and an HTML gate; limits surface as HttpError', async () => {
    const c = foremConnector((async () => page(recs, 11)) as typeof fetch, nowFn);
    for (const bad of ['-100', '50', 'x', '2500', '99999', '100/../']) await expect(c.fetchPage(bad, 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(foremConnector((async () => json({ error: 'x' })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/unexpected response/);
    await expect(foremConnector((async () => new Response('<html>quota</html>', { status: 200 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toMatchObject({ status: 403 });
    await expect(foremConnector((async () => new Response('', { status: 429 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
  });

  it('drops expired offers silently and records other refusals', async () => {
    const f = (async () => page([recs[0], { ...recs[1], datefindiffusion: '2020-01-01' }, { ...recs[2], url: 'https://x.example/o/1' }, 5], 4)) as typeof fetch;
    const p = await foremConnector(f, nowFn).fetchPage(null, 'discover');
    expect(p.jobs).toHaveLength(1);
    expect(p.rejected).toEqual([{ externalId: '2110302', reason: 'invalid_url' }, { externalId: null, reason: 'not_an_object' }]);
  });

  it('is registered with the CC BY-SA attribution, a ceiling and a read window', () => {
    const s = SOURCES.forem!;
    expect(s).toMatchObject({ id: 'forem', host: 'leforem.be', pageWindow: true });
    expect(s.attribution).toMatch(/Le Forem/);
    expect(s.attribution).toMatch(/CC BY-SA 4\.0/);
    expect(s.catalogue).toBeLessThanOrEqual(2000);
    expect(s.make(fetch, nowFn).id).toBe('forem');
  });
});
