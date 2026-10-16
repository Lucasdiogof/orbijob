import { describe, expect, it } from 'vitest';
import { ecylConnector, ecylCountry, ecylUrl, normalizeEcyl } from '../src/connectors/ecyl';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/ecyl.sample.json';

// Real offers of the ECYL open-data feed (read 2026-10-16): 10 offers (see worker/scripts/make-ecyl-fixture.mjs).
const NOW = '2026-10-16T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const recs = fixture as Record<string, unknown>[];
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (r: ReturnType<typeof normalizeEcyl>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
const rec = (id: string) => recs.find((r) => r.identificador === id)!;

describe('ECYL normalizer (real offers)', () => {
  it('maps an offer without inventing anything: no employer, the stated province, the offer\'s public page, no salary, its date', () => {
    const jobs = recs.map((r) => ok(normalizeEcyl(r, NOW)));
    expect(jobs).toHaveLength(10);
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'ecyl', language: 'es', workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, company: '', salaryMin: null, salaryCurrency: null, contractType: null, geoRestrictions: [] });
      expect(j.originalUrl).toBe(`https://empleo.jcyl.es/web/jcyl/Empleo/es/Plantilla100Detalle/1284216458054/OfertasEmpleo/${j.externalId}/Empleo`);
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.publishedAt).toMatch(/^2026-10-(08|1[0-5])T00:00:00\.000Z$/);
      expect(j.description).toMatch(/Fuente de la oferta: /);
    }
    expect(jobs[0]).toMatchObject({ externalId: '1285690244084', title: 'VIGILANTES, EN GENERAL', city: 'Miranda de Ebro', country: 'ES' });
    expect(jobs[0]!.description).toContain('Provincia: Burgos');
  });

  it('an offer given on the content manager host gets the public address with the same path; any other shape is refused', () => {
    const manager = ok(normalizeEcyl(rec('1285688092022'), NOW));
    expect(manager.originalUrl).toBe('https://empleo.jcyl.es/web/jcyl/Empleo/es/Plantilla100Detalle/1284216458054/OfertasEmpleo/1285688092022/Empleo');
    const base = 'https://gestorcontenidos.jcyl.es/web/jcyl/Empleo/es/Plantilla100Detalle/1284216458054/OfertasEmpleo/1285688092022/Empleo';
    expect(ecylUrl(base, '1285688092022')).toBe(manager.originalUrl);
    expect(ecylUrl(base, '999999999')).toBeNull(); // the link names another offer
    for (const bad of [null, '', 'http://empleo.jcyl.es/web/jcyl/Empleo/es/Plantilla100Detalle/1284216458054/OfertasEmpleo/1285688092022/Empleo',
      'https://evil.example/web/jcyl/Empleo/es/Plantilla100Detalle/1284216458054/OfertasEmpleo/1285688092022/Empleo',
      'https://empleo.jcyl.es/web/jcyl/Empleo/es/Plantilla100Detalle/1284216458054/OfertasEmpleo/1285688092022/Empleo/../x',
      'https://user:pw@empleo.jcyl.es/web/jcyl/Empleo/es/Plantilla100Detalle/1284216458054/OfertasEmpleo/1285688092022/Empleo',
      'https://empleo.jcyl.es/otra/ruta']) expect(ecylUrl(bad, '1285688092022'), String(bad)).toBeNull();
  });

  it('masks telephone numbers and personal e-mail addresses, keeps role addresses', () => {
    for (const r of recs) {
      const j = ok(normalizeEcyl(r, NOW));
      expect(j.description).not.toMatch(/(?<![0-9])[6-9][0-9](?:[\s.-]?[0-9]){7}(?![0-9])/);
      expect(j.description).not.toMatch(/@jcyl\.es|@alzheimer|@gmail/);
    }
    const j = ok(normalizeEcyl({ ...recs[0]!, descripcion: '<p>Llamar al 947 32 04 08 ext. 821928 o escribir a ana.ruiz@gmail.com o a info@empresa.es</p>' }, NOW));
    expect(j.description).toContain('[teléfono]');
    expect(j.description).toContain('[e-mail]');
    expect(j.description).toContain('info@empresa.es');
    expect(j.description).not.toMatch(/ana\.ruiz|947/);
  });

  it('the country is Spain only for a province of Castilla y León; EURES offers abroad state none', () => {
    const abroad = ok(normalizeEcyl(rec('1285689967800'), NOW));
    expect(abroad).toMatchObject({ country: null, city: null });
    expect(abroad.description).not.toMatch(/Provincia:/);
    expect(abroad.description).toContain('Fuente de la oferta: Red EURES');
    for (const p of ['Burgos', 'León', 'Leon', 'Ávila', 'Avila', 'Zamora', 'Soria', 'Segovia', 'Palencia', 'Salamanca', 'Valladolid']) expect(ecylCountry(p), p).toBe('ES');
    for (const p of ['Otra', '', 'Madrid', 'Europa']) expect(ecylCountry(p), p).toBeNull();
  });

  it('refuses an offer older than 90 days and what cannot be shown honestly, with a reason and never an exception', () => {
    const r = (over: Record<string, unknown>) => normalizeEcyl({ ...recs[0]!, ...over }, NOW);
    expect(r({ fecha_publicacion: '2026-07-10' })).toMatchObject({ ok: false, reason: 'stale' });
    expect(r({ fecha_publicacion: '2026-07-20' }).ok).toBe(true);
    expect(r({ fecha_publicacion: 'ayer' }).ok).toBe(true);
    expect(r({ identificador: 'abc' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ identificador: undefined })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(ok(r({ identificador: 1285690244084 })).externalId).toBe('1285690244084');
    expect(r({ titulo: '  ' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ enlace_al_contenido: null })).toMatchObject({ ok: false, reason: 'invalid_url' });
    for (const bad of [null, 'x', 7, [], undefined]) expect(normalizeEcyl(bad, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
  });
});

describe('ECYL connector', () => {
  it('reads the whole feed in one request, reports refusals by reason, never closes anything', async () => {
    const calls: string[] = [];
    const f = (async (u: string) => { calls.push(String(u)); return json([...recs, { ...recs[0]!, identificador: 'x' }, { ...recs[1]!, fecha_publicacion: '2026-01-01' }]); }) as unknown as typeof fetch;
    const page = await ecylConnector(f, nowFn).fetchPage(null, 'discover');
    expect(calls).toEqual(['https://datosabiertos.jcyl.es/web/jcyl/risp/es/empleo/ofertas-empleo/1284354353012.json']);
    expect(page.jobs).toHaveLength(10);
    expect(page.nextCursor).toBeNull();
    expect(page.isFullSnapshot).toBe(false);
    expect(page.rejected).toEqual([{ externalId: null, reason: 'invalid_id' }]);
  });

  it('declares itself; a cursor, a bad payload or an HTTP error surfaces', async () => {
    const c = ecylConnector((async () => json([])) as unknown as typeof fetch, nowFn);
    expect(c).toMatchObject({ id: 'ecyl', presenceConfirmsOpen: true });
    await expect(c.fetchPage('1', 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(ecylConnector((async () => json({ results: [] })) as unknown as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/unexpected response/);
    await expect(ecylConnector((async () => json({}, 503)) as unknown as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
  });

  it('is registered with the licence in its attribution and a ceiling that keeps it in proportion', () => {
    const s = SOURCES['ecyl']!;
    expect(s.host).toBe('jcyl.es');
    expect(s.attribution).toContain('Creative Commons Attribution 4.0');
    expect(s.attribution).toContain('origin of the data');
    expect(s.catalogue).toBeLessThanOrEqual(1500);
  });
});
