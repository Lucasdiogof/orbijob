import { describe, expect, it } from 'vitest';
import { isoDay, normalizeSefMurcia, sefMurciaConnector, townName, withoutRegistration } from '../src/connectors/sefmurcia';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/sefmurcia.sample.json';

// Real offers of the SEF Murcia open-data feed (read 2026-10-16): 10 offers of different sectors.
const NOW = '2026-10-16T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const recs = fixture as Record<string, unknown>[];
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (r: ReturnType<typeof normalizeSefMurcia>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };

describe('SEF Murcia normalizer (real offers)', () => {
  it('maps an offer without inventing anything: Spain, no employer, the offer\'s own page, no salary, its start date', () => {
    const jobs = recs.filter((r) => r.urlDetalles).map((r) => ok(normalizeSefMurcia(r, NOW)));
    expect(jobs).toHaveLength(9);
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'sefmurcia', country: 'ES', language: 'es', workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, company: '', salaryMin: null, salaryCurrency: null, geoRestrictions: [] });
      expect(j.originalUrl).toMatch(/^https:\/\/sefoficinavirtual\.carm\.es\/sefoficinavirtual\/public\/oferta\/detalle-oferta\.xhtml\?id=\d+$/);
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.publishedAt).toMatch(/^2026-10-1[2-6]T00:00:00\.000Z$/);
      expect(j.description.length).toBeGreaterThan(200);
      expect(j.description).toMatch(/Sector profesional: /);
    }
    expect(jobs[0]).toMatchObject({ externalId: '142026005385', title: 'CHÓFER DE TRÁILER PARA CERCANÍAS', city: 'Aguilas' });
  });

  it('leaves out the registration section (office e-mail, ID number, deadline) and never carries a personal address or a phone', () => {
    for (const r of recs.filter((x) => x.urlDetalles)) {
      const j = ok(normalizeSefMurcia(r, NOW));
      expect(j.description).not.toMatch(/INSCRIPCI[OÓ]N/i);
      expect(j.description).not.toMatch(/@carm\.es/);
      expect(j.description).not.toMatch(/\bDNI\b/);
      expect(j.description).not.toMatch(/<[a-z/][^>]*>/i);
    }
    expect(withoutRegistration('a<BR/><b>INSCRIPCION:</b> mail me@x.es')).toBe('a');
    expect(withoutRegistration('a<BR/><b>INSCRIPCIÓN</b>b')).toBe('a');
    for (const h of ['<b>INSCRIPCION:</b>', '<B>INSCRIPCIÓN</B>', '<b>INSCRIPCION EN LA OFERTA:</b>', '<u>INSCRIPCION</u>', '<b>INSCRIPCIÓN: </b>']) expect(withoutRegistration(`a<BR/>${h} mail me@x.es`), h).toBe('a');
    expect(withoutRegistration('a. Si está inscrito/a en una oficina de empleo, escriba.')).toBe('a. ');
    expect(withoutRegistration('no section')).toBe('no section');
    expect(withoutRegistration('Se pide inscripción en el registro mercantil')).toBe('Se pide inscripción en el registro mercantil'); // the word inside a sentence is not a heading
  });

  it('reads the contract and the working time from the conditions the offer states, only when it states them', () => {
    const j = ok(normalizeSefMurcia(recs[0]!, NOW));
    expect(j.contractType).toBe('Indefinido y jornada completa');
    const bare = ok(normalizeSefMurcia({ ...recs[0]!, adicionales: 'Se necesita personal.' }, NOW));
    expect(bare.contractType).toBeNull();
  });

  it('town names: the INE inversion and the upper-case form', () => {
    expect(townName('ALCAZARES, LOS')).toBe('Los Alcazares');
    expect(townName('FUENTE ALAMO DE MURCIA')).toBe('Fuente Alamo de Murcia');
    expect(townName('CARAVACA DE LA CRUZ')).toBe('Caravaca de la Cruz');
    expect(townName('Murcia')).toBe('Murcia');
    expect(townName('')).toBe('');
  });

  it('dates: dd/mm/yyyy only, real days only', () => {
    expect(isoDay('16/10/2026')).toBe('2026-10-16');
    for (const bad of ['', '2026-10-16', '31/02/2026', '1/1/2026', 'hoy']) expect(isoDay(bad), bad).toBe('');
  });

  it('refuses an expired offer, keeps one that ends today or has no readable end', () => {
    const r = (over: Record<string, unknown>) => normalizeSefMurcia({ ...recs[0]!, ...over }, NOW);
    expect(r({ fechaDeFin: '15/10/2026' })).toMatchObject({ ok: false, reason: 'expired' });
    expect(r({ fechaDeFin: '16/10/2026' }).ok).toBe(true);
    expect(r({ fechaDeFin: null }).ok).toBe(true);
    expect(r({ fechaDeFin: 'pronto' }).ok).toBe(true);
  });

  it('rejects what cannot be shown honestly, with a reason and never an exception', () => {
    const r = (over: Record<string, unknown>) => normalizeSefMurcia({ ...recs[0]!, ...over }, NOW);
    expect(r({ numeroOferta: 'abc' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ numeroOferta: '../1' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ numeroOferta: undefined })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(ok(r({ numeroOferta: 142026005385 })).externalId).toBe('142026005385');
    expect(r({ descripcion: '   ' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ urlDetalles: 'http://sefoficinavirtual.carm.es/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ urlDetalles: 'https://evil.example/x?host=carm.es' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ urlDetalles: 'https://user:pw@sefoficinavirtual.carm.es/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    for (const bad of [null, 'x', 7, [], undefined]) expect(normalizeSefMurcia(bad, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
  });
});

describe('SEF Murcia connector', () => {
  it('reads the whole feed in one request, reports refusals by reason, never closes anything', async () => {
    const calls: string[] = [];
    const f = (async (u: string) => { calls.push(String(u)); return json([...recs, { ...recs[0]!, numeroOferta: 'x' }, { ...recs[1]!, fechaDeFin: '01/01/2026', numeroOferta: '142026000001' }]); }) as unknown as typeof fetch;
    const page = await sefMurciaConnector(f, nowFn).fetchPage(null, 'discover');
    expect(calls).toEqual(['https://sefapps.carm.es/sefApps/rest/ofertas/ofertas']);
    expect(page.jobs).toHaveLength(9);
    expect(page.nextCursor).toBeNull();
    expect(page.isFullSnapshot).toBe(false);
    // the real feed has offers without a page (`urlDetalles: null`): refused, never given an invented link; an expired offer is not a refusal
    expect(page.rejected).toEqual([{ externalId: '142026005925', reason: 'invalid_url' }, { externalId: null, reason: 'invalid_id' }]);
  });

  it('declares itself: presence confirms open, a cursor is never valid, a bad payload or HTTP error surfaces', async () => {
    const c = sefMurciaConnector((async () => json([])) as unknown as typeof fetch, nowFn);
    expect(c).toMatchObject({ id: 'sefmurcia', presenceConfirmsOpen: true });
    await expect(c.fetchPage('1', 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(sefMurciaConnector((async () => json({ ofertas: [] })) as unknown as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/unexpected response/);
    await expect(sefMurciaConnector((async () => json({}, 503)) as unknown as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
  });

  it('is registered with the licence conditions in its attribution and a proportionate ceiling', () => {
    const s = SOURCES['sefmurcia']!;
    expect(s.host).toBe('carm.es');
    expect(s.attribution).toContain('avisolegal');
    expect(s.attribution).toContain('origin of the data');
    expect(s.catalogue).toBeLessThanOrEqual(1000);
  });
});
