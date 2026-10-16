import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { csvRecords } from '../src/csv-stream';
import { companyOf, cspConnector, FIELDS, FR_PHONE, isoDay, latestFileUrl, normalizeCsp, offerUrl, statusFromPage, townOf, type CspRow } from '../src/connectors/csp';
import { SOURCES } from '../src/sources';

// Real offers of "Les offres diffusées sur Choisir le Service Public" (data.gouv.fr, Licence Ouverte 2.0; weekly file of 2026-09-20 read 2026-10-14),
// captured by scripts/make-csp-fixture.mjs: a school canteen of a commune, a gardener of Pantin, a nurse, a teacher, prison service posts with
// multi-line employers, a university, a CNC director, a departmental cook, a reference with spaces. E-mails and phones are placeholders.
const NOW = '2026-09-02T06:00:00.000Z';
const CSV = readFileSync(new URL('./fixtures/csp.sample.csv', import.meta.url));
const stream = (b: Uint8Array | string) => new Blob([b]).stream();

async function rows(): Promise<CspRow[]> {
  let head: string[] | null = null;
  const out: CspRow[] = [];
  for await (const r of csvRecords(stream(CSV), ';')) {
    if (!head) { head = r; continue; }
    const row: CspRow = {};
    for (const [k, n] of Object.entries(FIELDS) as [keyof typeof FIELDS, string][]) row[k] = r[head.indexOf(n)] ?? '';
    out.push(row);
  }
  return out;
}
const byRef = async (ref: string) => (await rows()).find((r) => r.ref === ref)!;
const ok = (n: ReturnType<typeof normalizeCsp>) => { if (!n.ok) throw new Error(`expected a valid job, got ${JSON.stringify(n)}`); return n.job; };

describe('streamed CSV records', () => {
  it('reads quoted fields with the delimiter, line breaks and doubled quotes, across chunk boundaries', async () => {
    const text = '﻿a;b;c\r\n1;"x;y";"line1\nline2"\n2;"say ""hi""";\n3;;last';
    const all: string[][] = [];
    for await (const r of csvRecords(stream(text), ';')) all.push(r);
    expect(all).toEqual([['a', 'b', 'c'], ['1', 'x;y', 'line1\nline2'], ['2', 'say "hi"', ''], ['3', '', 'last']]);
    // the same text delivered one byte at a time (a multi-byte letter split between chunks)
    const bytes = new TextEncoder().encode('é;"à\nb"\n');
    const slow = new ReadableStream<Uint8Array>({ start(c) { for (const b of bytes) c.enqueue(new Uint8Array([b])); c.close(); } });
    const got: string[][] = [];
    for await (const r of csvRecords(slow, ';')) got.push(r);
    expect(got).toEqual([['é', 'à\nb']]);
  });

  it('every record of the real sample has the 30 columns of the header', async () => {
    const all: string[][] = [];
    for await (const r of csvRecords(stream(CSV), ';')) all.push(r);
    expect(all.length).toBe(14);
    for (const r of all) expect(r).toHaveLength(30);
  });
});

describe('Choisir le Service Public normalizer (real offers)', () => {
  it('maps an offer: France, French, the offer page by reference, the first publication day, facts as description', async () => {
    const j = ok(normalizeCsp(await byRef('O035260901000846'), NOW));
    expect(j).toMatchObject({
      source: 'csp', externalId: 'O035260901000846', title: 'RESPONSABLE DU RESTAURANT SCOLAIRE - Mairie de Nouvoitou', company: 'Mairie de Nouvoitou',
      country: 'FR', city: 'Nouvoitou', language: 'fr', workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, geoRestrictions: [],
      salaryMin: null, salaryCurrency: null, publishedAt: '2026-09-01T00:00:00.000Z',
    });
    expect(j.originalUrl).toBe('https://choisirleservicepublic.gouv.fr/offre-emploi/responsable-du-restaurant-scolaire-mairie-de-nouvoitou-reference-O035260901000846/');
    expect(j.applyUrl).toBe(j.originalUrl);
    expect(j.description).toContain('Versant : Fonction Publique Territoriale');
    expect(j.description).toContain('Métier : ');
  });

  it('names the employer without guessing: the offer\'s own employer line, the authority its title names, the commune of its town hall', async () => {
    expect(ok(normalizeCsp(await byRef('O093260901001179'), NOW))).toMatchObject({ company: 'Commune de Pantin', city: 'Pantin' });
    expect(ok(normalizeCsp(await byRef('2026-2396372'), NOW)).company).toBe('Ministère de la Justice');
    expect(ok(normalizeCsp(await byRef('O085260901000431'), NOW)).company).toBe('CONSEIL DEPARTEMENTAL DE LA VENDEE');
    // a sentence or an address is not a name; a generic body without an authority in the title stays the body
    expect(companyOf({ employer: 'Le Centre Hospitalier Henri EY recrute un infirmier.', body: 'CH Henri Ey' }, 'Infirmier')).toBe('CH Henri Ey');
    expect(companyOf({ employer: '', body: 'Communes' }, 'Jardinier - Pantin')).toBe('Communes');
    expect(companyOf({ employer: '', body: 'Communes' }, 'Jardinier - Commune de Pantin')).toBe('Commune de Pantin');
  });

  it('a town only from a postal address; CEDEX and capitals tidied, a region is not a town', () => {
    expect(townOf({ place: 'La Valette : 23320 Saint-Vaury' })).toBe('Saint-Vaury');
    expect(townOf({ placePlain: '108 Av du Gl LECLERC – BP 60321  35703  RENNES CEDEX 7' })).toBe('Rennes');
    expect(townOf({ placePlain: '1 bis rue de Lutèce 75195 Paris cedex 04' })).toBe('Paris');
    expect(townOf({ placePlain: 'ILE DE FRANCE' })).toBeNull();
    expect(townOf({})).toBeNull();
  });

  it('refuses what is outside its publication window, a malformed reference, an empty title', async () => {
    const r = await byRef('O093260901001179');
    expect(normalizeCsp(r, '2026-10-02T00:00:00.000Z')).toMatchObject({ ok: false, reason: 'expired' });
    expect(normalizeCsp({ ...r, end: '' }, NOW)).toMatchObject({ ok: false, reason: 'expired' });
    expect(normalizeCsp({ ...r, start: '20/09/2026' }, NOW)).toMatchObject({ ok: false, reason: 'not_yet_published' });
    expect(normalizeCsp({ ...r, ref: 'MINT_BA063PNC -126680' }, NOW)).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(normalizeCsp({ ...r, ref: '../x' }, NOW)).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(normalizeCsp({ ...r, title: '  ' }, NOW)).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(normalizeCsp({ ...r, employer: '', body: '' }, NOW)).toMatchObject({ ok: false, reason: 'missing_company' });
  });

  it('masks telephone numbers and personal e-mail addresses in the free texts', async () => {
    const r = await byRef('O093260901001179');
    const j = ok(normalizeCsp({ ...r, skills: 'Contact : jean.dupont@ville.fr ou 01 23 45 67 89, +33 6 12 34 56 78, jobs@ville.fr' }, NOW));
    expect(j.description).toContain('[téléphone]');
    expect(j.description).not.toMatch(/45 67 89|56 78|jean\.dupont/);
    expect(j.description).toContain('jobs@ville.fr');
    expect('Réf 2026-2396500'.replace(FR_PHONE, 'X')).toBe('Réf 2026-2396500');
  });

  it('dates and links are strict', () => {
    expect(isoDay('01/09/2026')).toBe('2026-09-01');
    expect(isoDay('31/02/2026')).toBe('');
    expect(isoDay('2026-09-01')).toBe('');
    expect(offerUrl('2026-2396430', 'Chef(fe) du bureau')).toBe('https://choisirleservicepublic.gouv.fr/offre-emploi/chef-fe-du-bureau-reference-2026-2396430/');
    expect(offerUrl('a/b', 'x')).toBeNull();
  });
});

describe('Choisir le Service Public pages and connector', () => {
  const page = (title: string) => `<html><head><title>${title}</title></head><body></body></html>`;

  it('reads an offer page: its own title is open, "Offre dépubliée" is closed, anything else no answer', () => {
    expect(statusFromPage(page("Agent d'entretien des écoles  (h/f) - commune de nice Nice | Choisir le service public"))).toBe('open');
    expect(statusFromPage(page('Offre dépubliée | Choisir le service public'))).toBe('closed');
    expect(statusFromPage(page('Just a moment...'))).toBeNull();
    expect(statusFromPage('')).toBeNull();
  });

  it('picks the newest full weekly file of the dataset, never a partial one or another host', async () => {
    const f = (async () => new Response(JSON.stringify({ resources: [
      { title: 'offres-datagouv-20260920.csv', url: 'https://static.data.gouv.fr/resources/x/offres-datagouv-20260920.csv', filesize: 123_000_000 },
      { title: 'offres-datagouv-20261228.csv', url: 'https://static.data.gouv.fr/resources/x/offres-datagouv-20261228.csv', filesize: 1_600_000 },
      { title: 'offres-datagouv-20261231.csv', url: 'https://evil.example/offres-datagouv-20261231.csv', filesize: 200_000_000 },
      { title: 'documentation.pdf', url: 'https://static.data.gouv.fr/d.pdf', filesize: 200_000 },
    ] }))) as typeof fetch;
    expect(await latestFileUrl(f)).toBe('https://static.data.gouv.fr/resources/x/offres-datagouv-20260920.csv');
    await expect(latestFileUrl((async () => new Response(JSON.stringify({ resources: [] }))) as typeof fetch)).rejects.toThrow(/no weekly file/);
  });

  function fakeSite(pages: Record<string, number | string>) {
    const asked: string[] = [];
    const f = (async (u: string | URL | Request) => {
      const url = String(u);
      if (url.includes('/api/1/datasets/')) return new Response(JSON.stringify({ resources: [{ title: 'offres-datagouv-20260830.csv', url: 'https://static.data.gouv.fr/r/offres-datagouv-20260830.csv', filesize: 120_000_000 }] }));
      if (url.startsWith('https://static.data.gouv.fr/')) return new Response(CSV);
      asked.push(url);
      const ref = /reference-([^/]+)\/$/.exec(url)?.[1] ?? '';
      const p = pages[ref];
      if (typeof p === 'number') return new Response('', { status: p });
      return new Response(page(p ?? 'Offre dépubliée | Choisir le service public'));
    }) as typeof fetch;
    return { f, asked };
  }

  it('one pass reads the file, keeps the offers inside their window, newest first; nothing is proven open by the file', async () => {
    const { f } = fakeSite({});
    const c = cspConnector(f, () => new Date(NOW), { minRows: 5 });
    expect(c.presenceConfirmsOpen).toBeFalsy();
    const p = await c.fetchPage(null, 'discover');
    expect(p.nextCursor).toBeNull();
    expect(p.isFullSnapshot).toBe(false);
    expect(p.jobs.map((j) => j.externalId)).toEqual(expect.arrayContaining(['O035260901000846', 'O093260901001179', '2026-2396430']));
    expect(p.jobs.every((j) => j.source === 'csp')).toBe(true);
    expect(p.rejected).toEqual([{ externalId: null, reason: 'invalid_id' }]);
    await expect(c.fetchPage('1', 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(cspConnector(f, () => new Date(NOW)).fetchPage(null, 'discover')).rejects.toThrow(/implausible/);
  });

  it('asks each offer\'s page politely and stops at the first sign of overload', async () => {
    const { f, asked } = fakeSite({ AA1: 'Jardinier | Choisir le service public', BB2: 'Offre dépubliée | Choisir le service public', CC3: 404, DD4: 429, EE5: 'x | Choisir le service public' });
    const waits: number[] = [];
    const c = cspConnector(f, () => new Date(NOW), { sleep: async (ms) => { waits.push(ms); } });
    expect(await c.checkStatuses!(['AA1', 'BB2', 'CC3', 'bad/ref', 'DD4', 'EE5'])).toEqual({ AA1: 'open', BB2: 'closed' });
    expect(asked).toHaveLength(4); // EE5 is never asked after the 429
    expect(waits.every((w) => w >= 1000)).toBe(true);
  });

  it('is registered with the Licence Ouverte attribution and a bounded catalogue', () => {
    const s = SOURCES.csp!;
    expect(s).toMatchObject({ id: 'csp', host: 'choisirleservicepublic.gouv.fr' });
    expect(s.attribution).toMatch(/Licence Ouverte/);
    expect(s.attribution).toMatch(/data\.gouv\.fr/);
    expect(s.catalogue).toBeLessThanOrEqual(2000);
    expect(s.newCap).toBeLessThanOrEqual(80);
    expect(s.make(fetch, () => new Date(NOW)).statusBatch).toBeLessThanOrEqual(25);
    expect(s.make(fetch, () => new Date(NOW)).id).toBe('csp');
  });
});
