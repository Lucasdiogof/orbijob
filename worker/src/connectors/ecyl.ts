import { cleanDescription } from '../description';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob } from '../types';
import { getFeed, ownUrl, type Normalized } from './feeds';
import { ES_PHONE } from './feinaactiva';

/**
 * ECYL, the Servicio Público de Empleo de Castilla y León (Spain): the job offers its offices publish, as open data of the Junta de Castilla y León (dataset "Ofertas de
 * Empleo" of https://datosabiertos.jcyl.es, ≈ 950 offers, refreshed daily):
 *
 *   https://datosabiertos.jcyl.es/web/jcyl/risp/es/empleo/ofertas-empleo/1284354353012.json   (redirects to the portal's JSON export)
 *
 * Licence: Creative Commons Attribution 4.0 (stated on the dataset's distributions, https://creativecommons.org/licenses/by/4.0/deed.es_ES). The attribution is stored with the
 * source. Offers come from the ECYL's own offices (≈ 85 %), official bodies, the press and the EURES network (offers abroad).
 *
 * Links: the dataset's `enlace_al_contenido` points to the Junta's content manager (`gestorcontenidos.jcyl.es`, not reachable by the public) for most offers and to the public
 * site (`empleo.jcyl.es`) for the others, always with the same path `/web/jcyl/Empleo/es/Plantilla100Detalle/1284216458054/OfertasEmpleo/{id}/Empleo`. The public address is
 * the same path on `empleo.jcyl.es` (checked on the live site: the page of an offer given on the manager host opens there with the offer's title). Only a link of that exact
 * shape is accepted.
 *
 * The ECYL does not name the employer: the company stays empty. The text is written by the office and often ends with how to apply, with an office or employer e-mail address
 * and a telephone number: telephone numbers are masked and e-mail addresses masked unless they are role addresses. The country is Spain when the offer's province is a
 * province of Castilla y León; the EURES offers abroad ("Otra") state no single country. The offer's publication date is its start date; an offer older than 90 days is
 * refused, since the feed has no end date. A listing that leaves the feed stops being stamped (`presenceConfirmsOpen`).
 */

export const ECYL_HOST = 'empleo.jcyl.es';
export const ECYL_FEED = 'https://datosabiertos.jcyl.es/web/jcyl/risp/es/empleo/ofertas-empleo/1284354353012.json';
export const ECYL_MAX_AGE_DAYS = 90;
const PATH = /^\/web\/jcyl\/Empleo\/es\/Plantilla100Detalle\/\d{6,16}\/OfertasEmpleo\/(\d{6,16})\/Empleo$/;
const PROVINCES = new Set(['ávila', 'avila', 'burgos', 'león', 'leon', 'palencia', 'salamanca', 'segovia', 'soria', 'valladolid', 'zamora']);

const str = (v: unknown): string => (typeof v === 'string' ? v : '');

/** The public address of an offer from the dataset's link: same path, on the public host; null for any other shape. */
export function ecylUrl(link: unknown, id: string): string | null {
  let u: URL;
  try { u = new URL(str(link).trim()); } catch { return null; }
  if (u.protocol !== 'https:' || u.username || u.password) return null;
  if (u.hostname !== 'gestorcontenidos.jcyl.es' && u.hostname !== ECYL_HOST) return null;
  const m = PATH.exec(u.pathname);
  if (!m || m[1] !== id) return null;
  return ownUrl(`https://${ECYL_HOST}${u.pathname}`, ECYL_HOST);
}

export function ecylCountry(province: string): string | null {
  return PROVINCES.has(province.trim().toLowerCase()) ? 'ES' : null;
}

const clean = (html: string): string => cleanDescription(html).replace(ES_PHONE, '[teléfono]');

export function normalizeEcyl(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = (typeof r.identificador === 'number' ? String(r.identificador) : str(r.identificador)).trim();
  if (!/^[0-9]{6,16}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(r.titulo));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const url = ecylUrl(r.enlace_al_contenido, id);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const day = /^(\d{4})-(\d{2})-(\d{2})$/.exec(str(r.fecha_publicacion));
  const posted = day ? Date.UTC(Number(day[1]), Number(day[2]) - 1, Number(day[3])) : NaN;
  if (Number.isFinite(posted) && posted < Date.parse(nowIso) - ECYL_MAX_AGE_DAYS * 86_400_000) return { ok: false, reason: 'stale', externalId: id };
  const body = clean(str(r.descripcion));
  const province = inlineText(str(r.provincia));
  const source = inlineText(str(r.fuente_contenido));
  const facts: string[] = [];
  if (province && province !== 'Otra') facts.push(`Provincia: ${province}`);
  if (source) facts.push(`Fuente de la oferta: ${source}`);
  const description = [body, facts.join('\n')].filter(Boolean).join('\n\n');
  const town = inlineText(str(r.localidad_asset0));
  const job: NormalizedJob = {
    source: 'ecyl', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: 'es',
    externalId: id, company: '', title, description,
    country: ecylCountry(province), city: town || null, workMode: 'unspecified', contractType: null,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
    publishedAt: Number.isFinite(posted) ? new Date(posted).toISOString() : null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

export function ecylConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const feed = opts.origin ? `${opts.origin.replace(/\/+$/, '')}/web/jcyl/risp/es/empleo/ofertas-empleo/1284354353012.json` : ECYL_FEED;
  return {
    id: 'ecyl',
    minIntervalMs: 1500,
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      if (cursor) throw new Error('ecyl: invalid cursor');
      const data = await getFeed<unknown>(fetchImpl, feed, 90_000);
      if (!Array.isArray(data)) throw new Error('ecyl: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data) {
        const n = normalizeEcyl(raw, nowIso);
        if (n.ok) jobs.push(n.job); else if (n.reason !== 'stale') rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      return { jobs, nextCursor: null, isFullSnapshot: false, rejected };
    },
  };
}
