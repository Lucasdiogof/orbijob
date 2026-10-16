import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { ads, employerName, feinaActivaConnector, isoDay, looksLikePerson, normalizeFeinaActiva, regionCountry, tag, townName } from '../src/connectors/feinaactiva';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';

// Real offers of the Feina Activa open-data feed (read 2026-10-16): 12 offers (see worker/scripts/make-feinaactiva-fixture.mjs; the two employers that were
// a person's name are replaced by made-up names of the same shape).
const NOW = '2026-10-16T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const xml = readFileSync(new URL('./fixtures/feinaactiva.sample.xml', import.meta.url), 'utf8');
const list = ads(xml);
const ok = (r: ReturnType<typeof normalizeFeinaActiva>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
const byId = (id: string) => ok(normalizeFeinaActiva(list.find((a) => tag(a, 'id') === id)!, NOW));
const text = (body: string, status = 200) => new Response(body, { status, headers: { 'content-type': 'application/xml' } });

describe('Feina Activa normalizer (real offers)', () => {
  it('maps an offer without inventing anything: the offer\'s own page, its date, the stated region, no salary', () => {
    expect(list).toHaveLength(12);
    const jobs = list.map((a) => ok(normalizeFeinaActiva(a, NOW)));
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'feinaactiva', workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null, geoRestrictions: [] });
      expect(j.originalUrl).toBe(`https://feinaactiva.gencat.cat/search/offers/detail/${j.externalId}`);
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.publishedAt).toMatch(/^2026-0[789]-\d\dT00:00:00\.000Z$/);
      expect(j.description.length).toBeGreaterThan(30);
    }
    const waiter = byId('FA92323338');
    expect(waiter).toMatchObject({ title: 'CAMBRER/A MENJADOR', company: 'Empresa de restauració', city: 'Calella', country: 'ES', publishedAt: '2026-08-26T00:00:00.000Z' });
    expect(waiter.contractType).toBe('Contracte laboral temporal (2 mesos), Jornada completa');
    expect(waiter.description).toContain('Retirar platos de las mesas');
    expect(waiter.description).toContain('Contracte: Contracte laboral temporal (2 mesos)');
  });

  it('a salary range without a unit is not turned into a salary', () => {
    expect(tag(list.find((a) => tag(a, 'id') === 'FA92323338')!, 'salaryMin')).toBe('1416'); // the feed has it ...
    expect(byId('FA92323338').salaryMin).toBeNull(); // ... the catalogue does not guess its period
    expect(byId('FA92323338').description).not.toContain('1416');
  });

  it('country: a Spanish province or the Netherlands, nothing else; towns in reading order', () => {
    expect(byId('FA92323468')).toMatchObject({ country: 'NL', city: null });
    expect(byId('09202622835')).toMatchObject({ country: 'ES', city: "L'Hospitalet de Llobregat" });
    expect(regionCountry('BARCELONA')).toBe('ES');
    expect(regionCountry('Castelló de la Plana')).toBe('ES');
    expect(regionCountry('PAÏSOS BAIXOS')).toBe('NL');
    for (const none of ['', 'ATLANTIDA', 'FRANÇA']) expect(regionCountry(none), none).toBeNull();
    expect(townName("HOSPITALET DE LLOBREGAT, L'")).toBe("L'Hospitalet de Llobregat");
    expect(townName('PRAT DE LLOBREGAT, EL')).toBe('El Prat de Llobregat');
    expect(townName('ALCAZARES, LOS')).toBe('Los Alcazares');
    expect(townName('CORNELLÀ DEL TERRI')).toBe('Cornellà del Terri');
    expect(townName('Girona')).toBe('Girona');
    expect(townName('')).toBe('');
  });

  it('never republishes a person\'s name as the employer; a trade name beside it is kept', () => {
    expect(byId('FA92321974').company).toBe(''); // "JOAN GARCIA PUIG"
    expect(byId('FA92323558').company).toBe('Estudi Pons'); // "Josep Pons Mas - Estudi Pons"
    expect(byId('FA92321433').company).toBe('Trans Malavella SL');
    expect(byId('09202622835').company).toBe('Oficina de Treball del SOC');
    expect(employerName('Xavier Estop Torrella (CAHISA)')).toBe('CAHISA');
    expect(employerName('Maria Garcia Lopez')).toBe('');
    expect(employerName('Residència Maria Auxiliadora')).toBe('Residència Maria Auxiliadora');
    expect(employerName('Joan Fuster Escola de Música')).toBe('Joan Fuster Escola de Música');
    expect(employerName('Gestió Josep Mas SL')).toBe('Gestió Josep Mas SL');
    expect(employerName('Aigües d&apos;Esparreguera')).toBe("Aigües d'Esparreguera");
    expect(employerName('  ')).toBe('');
    expect(looksLikePerson('Anna Puig')).toBe(true);
    expect(looksLikePerson('Anna')).toBe(false);
    expect(looksLikePerson('Mitie')).toBe(false);
    expect(looksLikePerson('Joan Garcia 2000')).toBe(false);
    expect(looksLikePerson('Pere Pons Mas Gil Rius')).toBe(false); // five words are not a name
    expect(looksLikePerson('Hotel Maria Pau')).toBe(false);
  });

  it('masks telephone numbers and personal e-mail addresses in the free text', () => {
    const base = list.find((a) => tag(a, 'id') === 'FA92323338')!;
    const withContact = base.replace(/<content>[\s\S]*?<\/content>/, '<content>Truqueu al 93 123 45 67 o al +34 612 345 678; escriviu a maria.puig@gmail.com o a info@empresa.cat</content>');
    const j = ok(normalizeFeinaActiva(withContact, NOW));
    expect(j.description).not.toMatch(/123 45 67|612 345 678|maria\.puig/);
    expect(j.description).toContain('[telèfon]');
    expect(j.description).toContain('info@empresa.cat');
  });

  it('refuses an offer older than 90 days, one that is not PUBLISHED, and what cannot be shown honestly', () => {
    const base = list[0]!;
    const r = (over: Record<string, string>) => {
      let a = base;
      for (const [k, v] of Object.entries(over)) a = a.replace(new RegExp(`<${k}>[\\s\\S]*?</${k}>`), `<${k}>${v}</${k}>`);
      return normalizeFeinaActiva(a, NOW);
    };
    expect(r({ date: '10/07/2026' })).toMatchObject({ ok: false, reason: 'stale' });
    expect(r({ date: '20/07/2026' }).ok).toBe(true);
    expect(r({ date: 'ahir' }).ok).toBe(true); // an unreadable date proves nothing
    expect(r({ status: 'CLOSED' })).toMatchObject({ ok: false, reason: 'not_published' });
    expect(r({ id: '../1' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ title: '  ' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ url: 'http://feinaactiva.gencat.cat/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'https://evil.example/?u=feinaactiva.gencat.cat' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(isoDay('16/10/2026')).toBe('2026-10-16');
    for (const bad of ['', '2026-10-16', '31/02/2026', 'x']) expect(isoDay(bad), bad).toBe('');
  });

  it('flags the offers meant for people with a disability, as the offer states it', () => {
    const j = list.map((a) => ok(normalizeFeinaActiva(a, NOW))).find((x) => x.description.includes('persones amb discapacitat'));
    expect(j).toBeTruthy();
  });
});

describe('Feina Activa connector', () => {
  it('reads the whole feed in one request, reports refusals by reason, never closes anything', async () => {
    const calls: string[] = [];
    const extra = list[0]!.replace(/<id>[^<]*<\/id>/, '<id>FA11</id>').replace(/<status>[^<]*<\/status>/, '<status>CLOSED</status>');
    const old = list[1]!.replace(/<id>[^<]*<\/id>/, '<id>FA2OLD</id>').replace(/<date>[^<]*<\/date>/, '<date>01/01/2026</date>');
    const f = (async (u: string) => { calls.push(String(u)); return text(`<?xml version="1.0"?><ofertes><feinaactiva>${[...list, extra, old].map((a) => `<ad>${a}</ad>`).join('')}</feinaactiva></ofertes>`); }) as unknown as typeof fetch;
    const page = await feinaActivaConnector(f, nowFn).fetchPage(null, 'discover');
    expect(calls).toEqual(['https://feinaactiva.gencat.cat/api/offers/offers-xml']);
    expect(page.jobs).toHaveLength(12);
    expect(page.nextCursor).toBeNull();
    expect(page.isFullSnapshot).toBe(false);
    expect(page.rejected).toEqual([{ externalId: 'FA11', reason: 'not_published' }]); // a stale offer is not a refusal
  });

  it('declares itself; a cursor, an error page, an HTTP error and an empty feed all stop the pass', async () => {
    const good = (async () => text(`<ofertes><feinaactiva>${list.map((a) => `<ad>${a}</ad>`).join('')}</feinaactiva></ofertes>`)) as unknown as typeof fetch;
    const c = feinaActivaConnector(good, nowFn);
    expect(c).toMatchObject({ id: 'feinaactiva', presenceConfirmsOpen: true });
    await expect(c.fetchPage('1', 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(feinaActivaConnector((async () => text('<html>challenge</html>')) as unknown as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
    await expect(feinaActivaConnector((async () => text('', 503)) as unknown as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
    await expect(feinaActivaConnector((async () => text('<ofertes></ofertes>')) as unknown as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/no offers/);
  });

  it('is registered with the licence conditions in its attribution and a ceiling that keeps it in proportion', () => {
    const s = SOURCES['feinaactiva']!;
    expect(s.host).toBe('feinaactiva.gencat.cat');
    expect(s.attribution).toContain('Generalitat de Catalunya');
    expect(s.attribution).toContain('Llicència oberta');
    expect(s.catalogue).toBeLessThanOrEqual(3500);
  });
});
