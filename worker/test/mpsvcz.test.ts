import { describe, expect, it } from 'vitest';
import { inWindow, listingUrl, mpsvCzConnector, MPSVCZ_CHANGED_DAYS, normalizeMpsvJob, type MpsvCodes } from '../src/connectors/mpsvcz';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/mpsvcz.sanitized.json';
import codesFixture from './fixtures/mpsvcz.codes.json';

// Real vacancies of the Czech open data "Volná pracovní místa" (data.mpsv.cz, read 2026-10-14): welder, cook, waiter, lorry driver, warehouse, building
// maintenance, farm helper, labourers, a logistics dispatcher whose HOURLY wage is a monthly figure, a vacancy published for the EU portal, one marked
// `anosp`, one with an expiry date, a cleaner without text. Contact people, e-mails and phones are placeholders: the connector never reads them.
const NOW = '2026-10-14T06:00:00.000Z';
const nowFn = () => new Date(NOW);
const recs = (fixture as { polozky: Record<string, unknown>[] }).polozky;
const byId = (id: number) => recs.find((r) => r.portalId === id)!;
const names = (l: { polozky: Record<string, unknown>[] }) => new Map(l.polozky.map((i) => [String(i.id), String((i.nazev as { cs: string }).cs)] as [string, string]));
const codes: MpsvCodes = { towns: names(codesFixture.obce), shifts: names(codesFixture.smennosti), contracts: names(codesFixture['pracovnepravni-vztahy']) };
const ok = (r: ReturnType<typeof normalizeMpsvJob>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
/** Marks a fixture record as changed one day ago so it falls inside the 14-day window. */
const fresh = (r: Record<string, unknown>) => ({ ...r, datumZmeny: '2026-10-13T04:00:00.000Z' });

describe('MPSV Czech vacancies normalizer (real vacancies)', () => {
  it('maps a welder: Czech country, the vacancy\'s own link, monthly salary in CZK, the town from the workplace address', () => {
    const j = ok(normalizeMpsvJob(byId(67287507), NOW, codes));
    expect(j).toMatchObject({
      source: 'mpsvcz', externalId: '67287507', title: 'Svářeč', company: 'METAL HOUSING s.r.o.', country: 'CZ', language: 'cs', workMode: 'unspecified',
      salaryMin: 35000, salaryMax: 35000, salaryCurrency: 'CZK', salaryPeriod: 'month', status: 'open', lastCheckedAt: NOW, geoRestrictions: [],
    });
    expect(j.originalUrl).toBe('https://up.gov.cz/volna-mista-v-cr#/volna-mista-detail/67287507');
    expect(j.applyUrl).toBe(j.originalUrl);
    expect(j.city).toBeTruthy();
    expect(j.publishedAt).toBe('2026-08-24T00:00:00.000Z');
    expect(j.contractType).toBe('Pracovní poměr - plný úvazek');
    expect(j.description).toContain('Směnnost: Dvousměnný provoz');
    expect(j.description).toContain('Hodin týdně: 38.75');
    expect(j.description).toContain('Počet volných míst: 2');
  });

  it('keeps the salary range, an hourly wage, and drops a "hourly" amount that is really a month', () => {
    expect(ok(normalizeMpsvJob(byId(67246351), NOW, codes))).toMatchObject({ salaryMin: 25000, salaryMax: 50000, salaryPeriod: 'month' });
    expect(ok(normalizeMpsvJob(byId(67301327), NOW, codes))).toMatchObject({ salaryMin: 180, salaryMax: 180, salaryPeriod: 'hour', salaryCurrency: 'CZK' });
    const mixed = ok(normalizeMpsvJob(byId(67301512), NOW, codes));
    expect(mixed).toMatchObject({ salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null });
  });

  it('names a town only when the vacancy names exactly one; a list of districts, an undetermined place or several sites give none', () => {
    expect(ok(normalizeMpsvJob(byId(67247686), NOW, codes)).city).toBeNull(); // districts
    expect(ok(normalizeMpsvJob(byId(67247666), NOW, codes)).city).toBeNull(); // not determined
    expect(ok(normalizeMpsvJob(byId(67249347), NOW, codes)).city).toBeTruthy(); // one town
    for (const r of recs.filter((x) => x.portalId !== 67301123)) expect(ok(normalizeMpsvJob(r, NOW, codes)).country).toBe('CZ');
  });

  it('refuses what the office does not publish, an expired vacancy, and a record without id, title, employer', () => {
    expect(normalizeMpsvJob(byId(67301123), NOW, codes)).toMatchObject({ ok: false, reason: 'not_published' });
    expect(normalizeMpsvJob(byId(67301560), NOW, codes).ok).toBe(true);
    expect(normalizeMpsvJob(byId(67301560), '2026-11-10T00:00:00.000Z', codes)).toMatchObject({ ok: false, reason: 'expired' });
    expect(normalizeMpsvJob({ ...byId(67287507), portalId: 'x' }, NOW, codes)).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(normalizeMpsvJob({ ...byId(67287507), pozadovanaProfese: { cs: ' ' } }, NOW, codes)).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(normalizeMpsvJob({ ...byId(67287507), zamestnavatel: { ico: '1', nazev: '' } }, NOW, codes)).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(normalizeMpsvJob(null, NOW, codes)).toMatchObject({ ok: false });
  });

  it('never keeps a contact person, e-mail address or phone number of the employer in what it stores', () => {
    const raw = { ...byId(67287507), prvniKontaktSeZamestnavatelem: { komuSeHlasit: { email: 'karel.novak@firma.cz', telefon: '777123456', jmeno: 'Karel', prijmeni: 'Novák' } },
      mistoVykonuPrace: { ...(byId(67287507).mistoVykonuPrace as object), pracoviste: [{ email: 'jana.svobodova@firma.cz', nazev: 'Provozovna', telefon: '602 111 222', adresa: null }] },
      upresnujiciInformace: { cs: 'Volejte na 777 123 456 nebo +420 602-111-222, pište na karel.novak@firma.cz. Nástup ihned, mzda 35 000 Kč.' } };
    const j = ok(normalizeMpsvJob(raw, NOW, codes));
    const all = JSON.stringify(j);
    expect(all).not.toMatch(/Novák|Svobodová|777|602|karel\.novak@firma\.cz|jana\.svobodova/);
    expect(j.description).toContain('[telefon]');
    expect(j.description).toContain('Nástup ihned, mzda 35 000 Kč.'); // ordinary numbers stay
    for (const r of recs.filter((x) => x.portalId !== 67301123)) expect(JSON.stringify(ok(normalizeMpsvJob(r, NOW, codes)))).not.toContain('kontakt@example.cz');
  });

  it('a phone glued to the country code is masked too; a vacancy number is not a phone (found in production 2026-10-14)', () => {
    const raw = { ...byId(67287507), upresnujiciInformace: { cs: 'Kontakt: email info@firma.cz, telefon +420721983270 nebo 00420602111222. Číslo volného místa 33171700713.' } };
    const d = ok(normalizeMpsvJob(raw, NOW, codes)).description ?? '';
    expect(d).not.toMatch(/721983270|602111222/);
    expect(d.match(/\[telefon\]/g)).toHaveLength(2);
    expect(d).toContain('33171700713');
  });

  it('the window: published, changed in the last 14 days, not in the future', () => {
    const now = Date.parse(NOW);
    expect(inWindow(fresh(byId(67287507)), now)).toBe(true);
    expect(inWindow({ ...byId(67287507), datumZmeny: new Date(now - (MPSVCZ_CHANGED_DAYS + 1) * 86400e3).toISOString() }, now)).toBe(false);
    expect(inWindow({ ...byId(67287507), datumZmeny: '2027-01-01T00:00:00.000Z' }, now)).toBe(false);
    expect(inWindow(fresh(byId(67301123)), now)).toBe(false); // anosp
    expect(inWindow({ ...byId(67287507), datumZmeny: null }, now)).toBe(false);
  });

  it('listing URLs are https on the service\'s own host', () => {
    expect(listingUrl(1)).toBe('https://up.gov.cz/volna-mista-v-cr#/volna-mista-detail/1');
  });
});

describe('MPSV connector (streams one big JSON document)', () => {
  const bigDoc = (items: Record<string, unknown>[]) => JSON.stringify({ polozky: items });
  const fetcher = (items: Record<string, unknown>[], urls: string[] = []) => (async (u: string | URL | Request) => {
    const url = String(u);
    urls.push(url);
    if (url.endsWith('/ciselniky/obce.json')) return new Response(JSON.stringify(codesFixture.obce));
    if (url.endsWith('/ciselniky/smennosti.json')) return new Response(JSON.stringify(codesFixture.smennosti));
    if (url.endsWith('/ciselniky/pracovnepravni-vztahy.json')) return new Response(JSON.stringify(codesFixture['pracovnepravni-vztahy']));
    if (url.endsWith('/volna-mista/volna-mista.json')) return new Response(bigDoc(items));
    return new Response('no', { status: 404 });
  }) as typeof fetch;
  const small = { minTowns: 1, minVacancies: 1 };

  it('keeps only the vacancies in the window and returns them newest-inserted first', async () => {
    const items = [...recs.map(fresh), { ...byId(67287507), portalId: 5, datumZmeny: '2025-01-01T00:00:00.000Z' }];
    const out = await mpsvCzConnector(fetcher(items), nowFn, small).fetchPage(null, 'default');
    expect(out.nextCursor).toBeNull();
    expect(out.isFullSnapshot).toBe(false);
    expect(out.jobs.length).toBeGreaterThan(8);
    expect(out.jobs.map((j) => j.externalId)).not.toContain('5'); // changed long ago
    expect(out.jobs.map((j) => j.externalId)).not.toContain('67301123'); // anosp
    const pub = out.jobs.map((j) => Date.parse(j.publishedAt ?? ''));
    expect([...pub].sort((a, b) => b - a)).toEqual(pub);
  });

  it('caps the window at the most recently inserted vacancies', async () => {
    const many = Array.from({ length: 50 }, (_, i) => ({ ...fresh(byId(67287507)), portalId: 1000 + i, datumVlozeni: new Date(Date.UTC(2026, 9, 1, 0, i)).toISOString() }));
    const out = await mpsvCzConnector(fetcher(many), nowFn, { ...small, max: 10 }).fetchPage(null, 'default');
    expect(out.jobs).toHaveLength(10);
    expect(out.jobs.map((j) => j.externalId)).toEqual(Array.from({ length: 10 }, (_, i) => String(1049 - i)));
  });

  it('reads the three code lists and the big file from the publisher\'s open-data folder only', async () => {
    const urls: string[] = [];
    await mpsvCzConnector(fetcher(recs.map(fresh), urls), nowFn, small).fetchPage(null, 'default');
    expect(urls.every((u) => u.startsWith('https://data.mpsv.cz/od/soubory/'))).toBe(true);
    expect(urls.some((u) => u.endsWith('/volna-mista/volna-mista.json'))).toBe(true);
  });

  it('fails loudly on an implausibly small file or town list, and on an unexpected cursor', async () => {
    await expect(mpsvCzConnector(fetcher(recs.map(fresh)), nowFn, { minTowns: 1 }).fetchPage(null, 'default')).rejects.toThrow(/implausible/);
    await expect(mpsvCzConnector(fetcher(recs.map(fresh)), nowFn, { minVacancies: 1 }).fetchPage(null, 'default')).rejects.toThrow(/town list/);
    await expect(mpsvCzConnector(fetcher(recs), nowFn, small).fetchPage('1', 'default')).rejects.toThrow(/cursor/);
    const down = (async () => new Response('x', { status: 503 })) as typeof fetch;
    await expect(mpsvCzConnector(down, nowFn, small).fetchPage(null, 'default')).rejects.toBeTruthy();
  });

  it('is registered with an attribution that names the publisher, its licence statement and its own host', () => {
    const s = SOURCES.mpsvcz!;
    expect(s.host).toBe('up.gov.cz');
    expect(s.attribution).toContain('https://');
    expect(s.attribution).toMatch(/Úřad práce|Labour Office/);
    expect(s.newCap).toBeLessThanOrEqual(s.catalogue);
  });
});
