import { cleanDescription } from '../description';
import { inlineText } from '../text';
import type { Connector, NormalizedJob } from '../types';
import { ownUrl, type Normalized } from './feeds';
import { jsonRecords, snapshotConnector } from './snapshot';
import { maskPhones } from './spain';

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
 * province of Castilla y León; for the EURES offers ("Otra") it is the one country the title states ("en Dinamarca"), else none. The offer's publication date is its start date; an offer older than 90 days is
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

/** Country names (Spanish) the EURES offers abroad write in their title ("Embryologist en Dinamarca"). */
const ABROAD: Record<string, string> = {
  españa: 'ES', alemania: 'DE', austria: 'AT', 'bélgica': 'BE', belgica: 'BE', dinamarca: 'DK', finlandia: 'FI', francia: 'FR', irlanda: 'IE', islandia: 'IS',
  italia: 'IT', luxemburgo: 'LU', malta: 'MT', noruega: 'NO', 'países bajos': 'NL', 'paises bajos': 'NL', holanda: 'NL', polonia: 'PL', portugal: 'PT',
  suecia: 'SE', suiza: 'CH', chequia: 'CZ', grecia: 'GR', croacia: 'HR', eslovenia: 'SI', estonia: 'EE', letonia: 'LV', lituania: 'LT', 'reino unido': 'GB',
};
const ABROAD_RE = new RegExp(`(?<!\\p{L})en (${Object.keys(ABROAD).join('|')})(?!\\p{L})`, 'giu');

/**
 * Spain when the offer's province is one of Castilla y León; otherwise (the EURES offers, province "Otra") the country the title itself states with "en <país>",
 * only when it names exactly one ("15 electricistas en España con desplazamientos a Alemania y Austria" is in Spain); nothing is guessed from anything else.
 */
export function ecylCountry(province: string, title = ''): string | null {
  if (PROVINCES.has(province.trim().toLowerCase())) return 'ES';
  const named = new Set([...title.matchAll(ABROAD_RE)].map((m) => ABROAD[m[1]!.toLowerCase()]!));
  return named.size === 1 ? [...named][0]! : null;
}

const clean = (html: string): string => maskPhones(cleanDescription(html), '[teléfono]');

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
    country: ecylCountry(province, title), city: town || null, workMode: 'unspecified', contractType: null,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
    publishedAt: Number.isFinite(posted) ? new Date(posted).toISOString() : null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

export function ecylConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  return snapshotConnector({
    id: 'ecyl', fetchImpl, now, accept: 'application/json', timeoutMs: 90_000,
    url: opts.origin ? `${opts.origin.replace(/\/+$/, '')}/web/jcyl/risp/es/empleo/ofertas-empleo/1284354353012.json` : ECYL_FEED,
    records: (res) => jsonRecords(res),
    normalize: normalizeEcyl,
  });
}
