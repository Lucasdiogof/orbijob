import { describe, expect, it } from 'vitest';
import { bpceConnector, bpceCountry, normalizeBpce, placeName } from '../src/connectors/bpce';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/bpce.sanitized.json';

// Real offers of the Groupe BPCE open-data portal (read 2026-10-13): 13 offers (France, International, no country), long texts trimmed, recruiter
// name and e-mail removed, contacts scrubbed.
const NOW = '2026-10-13T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const recs = fixture as Record<string, unknown>[];
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (r: ReturnType<typeof normalizeBpce>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
const slug = (r: Record<string, unknown>) => String(r.url).split('/').pop();

describe('Groupe BPCE normalizer (real offers)', () => {
  it('maps an offer without inventing anything: the stated country, no salary, no publication date, the offer\'s own page as the link', () => {
    const jobs = recs.map((r) => ok(normalizeBpce(r, NOW)));
    expect(jobs).toHaveLength(13);
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'bpce', language: null, workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, geoRestrictions: [], salaryMin: null, salaryCurrency: null, publishedAt: null });
      expect(j.originalUrl).toMatch(/^https:\/\/recrutement\.bpce\.fr\/job\//);
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.company).not.toBe('');
      expect(j.contractType).toBeTruthy();
      expect(j.description).not.toMatch(/<[a-z/][^>]*>/i);
    }
    expect(jobs[0]).toMatchObject({ externalId: slug(recs[0]!), company: 'Natixis CIB France', country: 'FR', city: 'Paris', contractType: 'CDI' });
    expect(jobs[0]!.description).toMatch(/Domaine : Informatique/);
    expect(jobs.filter((j) => j.country === 'FR')).toHaveLength(8);
    expect(jobs.filter((j) => j.country === 'US')).toHaveLength(2);
    expect(jobs.find((j) => j.country === 'GB')).toMatchObject({ city: 'Londres', contractType: 'VIE' });
    // an offer that states no country has none: a French bank branch in Metz is not guessed to be in France
    const none = jobs.filter((j) => j.country === null);
    expect(none).toHaveLength(2);
    expect(none.map((j) => j.city)).toContain('Metz');
  });

  it('never reads the recruiter\'s name or e-mail', () => {
    const j = ok(normalizeBpce({ ...recs[0]!, nom_recruteur_principal: 'Elizabeth Pereira', email_recruteur_principal: 'elizabeth.pereira@natixis.com' }, NOW));
    expect(JSON.stringify(j)).not.toMatch(/Pereira|elizabeth/i);
  });

  it('the country: France, or the French name in `state` of an International offer; unknown names stay empty', () => {
    expect(bpceCountry('France', 'Ile de France')).toBe('FR');
    expect(bpceCountry('France', null)).toBe('FR');
    expect(bpceCountry('International', 'États-Unis')).toBe('US');
    expect(bpceCountry('International', 'Royaume-Uni')).toBe('GB');
    expect(bpceCountry('International', 'Émirats Arabes Unis')).toBe('AE');
    expect(bpceCountry('International', 'Hong Kong')).toBe('HK');
    expect(bpceCountry('International', 'Suède')).toBe('SE');
    expect(bpceCountry('Germany', null)).toBe('DE'); // an English name is read too
    for (const [c, s] of [['International', null], ['International', 'Narnia'], ['International', ''], [null, 'France'], ['', ''], ['Atlantis', null], [5, 5]] as const) expect(bpceCountry(c, s), `${c}/${s}`).toBeNull();
  });

  it('writes upper-case cities in normal case and leaves the others alone', () => {
    expect(placeName('BELFORT')).toBe('Belfort');
    expect(placeName('SAINT-GRÉGOIRE')).toBe('Saint-Grégoire');
    expect(placeName("L'ISLE-ADAM")).toBe("L'Isle-Adam");
    expect(placeName('Paris')).toBe('Paris');
    expect(placeName('Aix-en-Provence')).toBe('Aix-en-Provence');
    expect(placeName('  ')).toBe('');
    expect(placeName('75')).toBe('75');
  });

  it('rejects what cannot be shown honestly, with a reason and never an exception', () => {
    const r = (over: Record<string, unknown>) => normalizeBpce({ ...recs[0]!, ...over }, NOW);
    expect(r({ url: 'https://evil.example/job/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'http://recrutement.bpce.fr/job/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'https://recrutement.bpce.fr/pages/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'https://recrutement.bpce.fr/job/../x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: null })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ title: ' ' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ organization: '', company: '' })).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(normalizeBpce(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    expect(normalizeBpce([], NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    expect(ok(r({ organization: '' })).company).toBe('Groupe BPCE'); // the group name stands in for a missing entity
  });

  it('caps the text and decodes the entities of titles', () => {
    const j = ok(normalizeBpce({ ...recs[0]!, description: '<p>' + 'mot '.repeat(4000) + '</p>' }, NOW));
    expect(j.description.length).toBeLessThanOrEqual(6001);
    expect(ok(normalizeBpce({ ...recs[0]!, title: 'V.I.E. - Financial Planning &amp; Analysis F/M - London' }, NOW)).title).toBe('V.I.E. - Financial Planning & Analysis F/M - London');
  });
});

describe('Groupe BPCE connector', () => {
  const page = (rows: unknown[], total: number) => json({ total_count: total, results: rows });

  it('reads the list 100 at a time in a stable order and stops at the end', async () => {
    const urls: string[] = [];
    const full = Array.from({ length: 100 }, (_, i) => ({ ...recs[0]!, url: `https://recrutement.bpce.fr/job/offer-${i}` }));
    const f = (async (u: string | URL | Request) => { urls.push(String(u)); return urls.length < 3 ? page(full, 250) : page(full.slice(0, 50), 250); }) as typeof fetch;
    const c = bpceConnector(f, nowFn);
    expect(c).toMatchObject({ id: 'bpce', presenceConfirmsOpen: true });
    expect(c.minIntervalMs).toBeGreaterThanOrEqual(1000);
    let cursor: string | null = null;
    let jobs = 0;
    do {
      const p = await c.fetchPage(cursor, 'discover');
      jobs += p.jobs.length;
      expect(p.isFullSnapshot).toBe(false);
      cursor = p.nextCursor;
    } while (cursor !== null);
    expect(jobs).toBe(250);
    expect(urls).toHaveLength(3);
    expect(urls[0]).toContain('/groupe-bpce-offres-emploi/records?limit=100&offset=0&order_by=referencenumber%2Curl%2Ccity');
    expect(urls[2]).toContain('offset=200');
    expect(new URL(urls[0]!).hostname).toBe('bpce.opendatasoft.com');
  });

  it('refuses a forged cursor, an unexpected body and an HTML gate; limits surface as HttpError', async () => {
    const c = bpceConnector((async () => page(recs, 13)) as typeof fetch, nowFn);
    for (const bad of ['-100', '50', 'x', '3000', '99999', '100/../']) await expect(c.fetchPage(bad, 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(bpceConnector((async () => json({ error: 'x' })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/unexpected response/);
    await expect(bpceConnector((async () => new Response('<html>quota</html>', { status: 200 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toMatchObject({ status: 403 });
    await expect(bpceConnector((async () => new Response('', { status: 429, headers: { 'retry-after': '20' } })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
  });

  it('records the refused rows and keeps the rest', async () => {
    const f = (async () => page([recs[0], { ...recs[1], url: 'https://x.example/job/y' }, 5], 3)) as typeof fetch;
    const p = await bpceConnector(f, nowFn).fetchPage(null, 'discover');
    expect(p.jobs).toHaveLength(1);
    expect(p.rejected).toEqual([{ externalId: null, reason: 'invalid_url' }, { externalId: null, reason: 'not_an_object' }]);
    expect(p.nextCursor).toBeNull();
  });

  it('is registered as a source with the Licence Ouverte attribution', () => {
    const s = SOURCES.bpce!;
    expect(s).toMatchObject({ id: 'bpce', host: 'bpce.fr' });
    expect(s.attribution).toMatch(/Groupe BPCE/);
    expect(s.attribution).toMatch(/Licence Ouverte/);
    expect(s.make(fetch, nowFn).id).toBe('bpce');
  });
});
