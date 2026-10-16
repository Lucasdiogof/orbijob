import { describe, expect, it } from 'vitest';
import { decodeFeed, lanbideConnector, normalizeLanbide } from '../src/connectors/lanbide';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/lanbide.sample.json';

// Offers of the Lanbide open-data feed (read 2026-10-16, 7 of them). The capture tool lost the accents of the text, so they were restored by hand, two long texts were
// shortened, and ONE made-up contact sentence (a telephone number, a personal and a role e-mail address) was added to the third offer to exercise the masking.
const NOW = '2026-10-16T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const recs = fixture as Record<string, unknown>[];
const bytes = (s: string, enc: 'utf8' | 'latin1') => new Uint8Array(Buffer.from(s, enc)).buffer as ArrayBuffer;
const ok = (r: ReturnType<typeof normalizeLanbide>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
const rec = (id: string) => recs.find((r) => r.codigo === id)!;
const feed = (body: ArrayBuffer | string, status = 200) => new Response(body, { status });

describe('Lanbide normalizer', () => {
  it('maps an offer without inventing anything: Spain as stated, no employer, the offer\'s page, no salary, its publication date', () => {
    const jobs = recs.map((r) => ok(normalizeLanbide(r, NOW)));
    expect(jobs).toHaveLength(7);
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'lanbide', language: 'es', workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, company: '', country: 'ES', salaryMin: null, salaryCurrency: null, contractType: null, geoRestrictions: [] });
      expect(j.originalUrl).toBe(`https://web.lanbide.eus/apps/OF_DETALLE_OFERTA_TRABAJO?LG=C&ML=OFEMEN1&MS=Eaaa&IDRG=${j.externalId}&CTRG=1`);
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.publishedAt).toMatch(/^2026-10-1[56]T00:00:00\.000Z$/);
      expect(j.description).toMatch(/Provincia: /);
    }
    expect(jobs[0]).toMatchObject({ externalId: '162026011081', title: 'MICROPIGMENTADOR/A-TATUADOR/A', city: 'Bilbao', publishedAt: '2026-10-16T00:00:00.000Z' });
    expect(jobs[0]!.description).toContain('Diseño y aplicación de maquillaje permanente');
    expect(jobs[5]).toMatchObject({ city: 'Vitoria-Gasteiz' });
    expect(jobs[5]!.description).toContain('Provincia: ARABA/ÁLAVA');
  });

  it('the disability flag is shown as a fact only when the offer sets it', () => {
    expect(ok(normalizeLanbide(rec('162026011070'), NOW)).description).toContain('Oferta para personas con discapacidad');
    expect(ok(normalizeLanbide(rec('162026011081'), NOW)).description).not.toContain('discapacidad');
  });

  it('masks telephone numbers and personal e-mail addresses, keeps role addresses', () => {
    const d = ok(normalizeLanbide(rec('162026011070'), NOW)).description;
    expect(d).not.toMatch(/94 412 34 56|maria\.lopez/);
    expect(d).toContain('[teléfono]');
    expect(d).toContain('[e-mail]');
    expect(d).not.toContain('rrhh@empresa.eus'); // not a role address the catalogue recognises: masked too
  });

  it('the country is Spain only when the offer states ESPAÑA', () => {
    const r = (pais: unknown) => ok(normalizeLanbide({ ...recs[0]!, pais }, NOW)).country;
    expect(r('ESPAÑA')).toBe('ES');
    expect(r('España')).toBe('ES');
    expect(r('ESPANA')).toBe('ES');
    for (const none of ['FRANCIA', '', null, undefined, 7]) expect(r(none), String(none)).toBeNull();
  });

  it('refuses an offer that is old in both dates, keeps one modified recently, and what cannot be shown honestly', () => {
    const r = (over: Record<string, unknown>) => normalizeLanbide({ ...recs[0]!, ...over }, NOW);
    expect(r({ fecPub: '01/07/2026', fecMod: '10/07/2026' })).toMatchObject({ ok: false, reason: 'stale' });
    expect(r({ fecPub: '01/07/2026', fecMod: '15/10/2026' }).ok).toBe(true);
    expect(r({ fecPub: 'ayer', fecMod: 'hoy' }).ok).toBe(true);
    expect(r({ codigo: 'abc' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ codigo: undefined })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(ok(r({ codigo: 162026011081 })).externalId).toBe('162026011081');
    expect(r({ desEmpleo: ' ' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ url: 'http://web.lanbide.eus/x?IDRG=162026011081' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'https://evil.example/?IDRG=162026011081&h=lanbide.eus' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'https://web.lanbide.eus/apps/OF_DETALLE_OFERTA_TRABAJO?IDRG=999999999' })).toMatchObject({ ok: false, reason: 'invalid_url' }); // the link names another offer
    for (const bad of [null, 'x', 7, [], undefined]) expect(normalizeLanbide(bad, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
  });
});

describe('Lanbide connector', () => {
  it('decodes ISO-8859-1 bytes that claim to be UTF-8, and plain UTF-8', () => {
    expect(decodeFeed(bytes('Diseño y aplicación', 'latin1'))).toBe('Diseño y aplicación');
    expect(decodeFeed(bytes('Diseño y aplicación', 'utf8'))).toBe('Diseño y aplicación');
    expect(decodeFeed(bytes('ARABA/ÁLAVA', 'latin1'))).toBe('ARABA/ÁLAVA');
  });

  it('reads the whole feed in one request (Latin-1 included), reports refusals by reason, never closes anything', async () => {
    const calls: string[] = [];
    const body = JSON.stringify([...recs, { ...recs[0]!, codigo: 'x' }, { ...recs[1]!, codigo: '162026000001', fecPub: '01/01/2026', fecMod: '01/01/2026', url: 'https://web.lanbide.eus/apps/OF_DETALLE_OFERTA_TRABAJO?IDRG=162026000001' }]);
    const f = (async (u: string) => { calls.push(String(u)); return feed(bytes(body, 'latin1')); }) as unknown as typeof fetch;
    const page = await lanbideConnector(f, nowFn).fetchPage(null, 'discover');
    expect(calls).toEqual(['https://apps.lanbide.euskadi.net/apps/OF_OFERTAS_ODE_JSON']);
    expect(page.jobs).toHaveLength(7);
    expect(page.jobs[0]!.description).toContain('Diseño y aplicación');
    expect(page.nextCursor).toBeNull();
    expect(page.isFullSnapshot).toBe(false);
    expect(page.rejected).toEqual([{ externalId: null, reason: 'invalid_id' }]); // a stale offer is not a refusal
  });

  it('declares itself; a cursor, an error page, a bad payload or an HTTP error surfaces', async () => {
    const c = lanbideConnector((async () => feed('[]')) as unknown as typeof fetch, nowFn);
    expect(c).toMatchObject({ id: 'lanbide', presenceConfirmsOpen: true });
    await expect(c.fetchPage('1', 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(lanbideConnector((async () => feed('<html>challenge</html>')) as unknown as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
    await expect(lanbideConnector((async () => feed('{"a":1}')) as unknown as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/unexpected response/);
    await expect(lanbideConnector((async () => feed('', 503)) as unknown as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
  });

  it('is registered with the licence in its attribution and a ceiling that keeps it in proportion', () => {
    const s = SOURCES['lanbide']!;
    expect(s.host).toBe('lanbide.eus');
    expect(s.attribution).toContain('Creative Commons Attribution 4.0');
    expect(s.attribution).toContain('origin of the data');
    expect(s.catalogue).toBeLessThanOrEqual(1000);
  });
});
