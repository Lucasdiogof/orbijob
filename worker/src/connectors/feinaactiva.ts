import { cleanDescription } from '../description';
import { HttpError } from '../http';
import { inlineText } from '../text';
import type { Connector, NormalizedJob } from '../types';
import { ownUrl, type Normalized } from './feeds';
import { snapshotConnector } from './snapshot';
import { ES_PHONE, isoDay, maskPhones, townName } from './spain';

export { ES_PHONE, isoDay, townName };

/**
 * Feina Activa (Catalonia, Spain): the job offers published on the portal of the Servei Públic d'Ocupació de Catalunya (SOC), as open data of the Generalitat
 * de Catalunya (dataset "Portal Feina Activa. Ofertes de feina", refreshed daily, ≈ 4,600 offers):
 *
 *   https://feinaactiva.gencat.cat/api/offers/offers-xml
 *
 * Licence: the Generalitat's general terms, "Llicència oberta d'ús d'informació - Catalunya" (https://web.gencat.cat/ca/generalitat/dades-indicadors/dades-obertes/llicencies):
 * reuse, distribution, public communication and adaptation worldwide without time limit; the source is cited ("Generalitat de Catalunya. Departament d'Empresa i
 * Treball. Servei Públic d'Ocupació de Catalunya"), the date of the data is stated (each offer shows its own date), the content is not altered or distorted, and no
 * Generalitat logos or marks are used. Every offer links to its own page on https://feinaactiva.gencat.cat.
 *
 * Personal data: the employer field of the feed holds the name of the employer as the offer's author typed it, and for sole traders that is their own name. Such a
 * name is not republished: a company that reads as a person (a known given name followed by surnames) is left empty, and when it carries a trade name after a dash or in
 * brackets ("Pedro Piera López - Alpha Disseny") only the trade name is kept. Telephone numbers in the free text are masked and e-mail addresses are masked unless they
 * are role addresses.
 *
 * The feed has no end date and no salary period: the offer's date is its publication date, an offer older than 90 days is refused (the portal keeps offers for a few
 * months and nothing in the feed proves a very old one is still open), and the salary range is NOT mapped (its unit is not stated, part-time amounts are not comparable).
 * The feed lists only PUBLISHED offers; a listing that leaves it stops being stamped (`presenceConfirmsOpen`).
 */

export const FEINAACTIVA_HOST = 'feinaactiva.gencat.cat';
export const FEINAACTIVA_FEED = `https://${FEINAACTIVA_HOST}/api/offers/offers-xml`;
export const FEINAACTIVA_MAX_AGE_DAYS = 90;

const ENTITIES: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };
const decode = (s: string): string =>
  s
    .replace(/&#x([0-9a-f]+);/gi, (_m, h: string) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_m, d: string) => String.fromCodePoint(Number(d)))
    .replace(/&([a-z]+);/gi, (m, n: string) => ENTITIES[n.toLowerCase()] ?? m);

/** The text of one child element of an `<ad>` ("" when absent or empty). The feed is flat and regular, so no XML library is needed. */
export function tag(ad: string, name: string): string {
  const m = new RegExp(`<${name}>([\\s\\S]*?)</${name}>`).exec(ad);
  return m ? decode(m[1]!) : '';
}

/** Splits the feed into its `<ad>…</ad>` blocks. */
export function ads(xml: string): string[] {
  const out: string[] = [];
  for (const m of xml.matchAll(/<ad>([\s\S]*?)<\/ad>/g)) out.push(m[1]!);
  return out;
}

const PROVINCE_ES = new Set(['BARCELONA', 'GIRONA', 'LLEIDA', 'TARRAGONA', 'MADRID', 'CASTELLÓ DE LA PLANA', 'VALÈNCIA', 'ALACANT', 'BIZKAIA', 'GIPUZKOA', 'ARABA', 'NAVARRA', 'ZARAGOZA', 'HUESCA', 'OSCA', 'TERUEL', 'VALLADOLID', 'BURGOS', 'LEÓN', 'SALAMANCA', 'BADAJOZ', 'CÁCERES', 'SEVILLA', 'MÁLAGA', 'CÁDIZ', 'GRANADA', 'ALMERÍA', 'JAÉN', 'CÓRDOBA', 'HUELVA', 'MURCIA', 'ALBACETE', 'TOLEDO', 'CIUDAD REAL', 'CUENCA', 'GUADALAJARA', 'LUGO', 'OURENSE', 'PONTEVEDRA', 'A CORUÑA', 'ASTURIAS', 'CANTABRIA', 'LA RIOJA', 'ILLES BALEARS', 'LAS PALMAS', 'SANTA CRUZ DE TENERIFE', 'ÁVILA', 'SEGOVIA', 'SORIA', 'ZAMORA', 'PALENCIA']);

/** The country a region name states: a Spanish province, or "PAÏSOS BAIXOS" (the Netherlands); anything else states none. */
export function regionCountry(region: string): string | null {
  const r = region.trim().toUpperCase();
  if (PROVINCE_ES.has(r)) return 'ES';
  if (r === 'PAÏSOS BAIXOS' || r === 'PAISES BAJOS') return 'NL';
  return null;
}

// --- personal names of sole traders --------------------------------------------------------------------------------------------------

const GIVEN = new Set(
  ('albert alberto alejandro alex alexandre alfons alfonso alfred alfredo alvaro álvaro ana andrea andreu andres andrés angel ángel angels ángeles anna antoni antonio arnau ariadna beatriz berta blanca bruno carla carles carlos carme carmen carolina cesar césar clara claudia concepcio concepció cristian cristina daniel david diego dolors dolores edgar eduard eduardo elena elisabet eloi emilio enric enrique ernest esther eva eugenia fernando ferran francesc francisco gabriel gemma gerard gerardo gerard ignasi ignacio imma immaculada irene isabel isidre ivan iván jaime jaume javier jesus jesús joan joaquim joaquin joel jordi jorge josep jose josé josefa judith juan julia júlia julian laia laura leonor lidia lídia lluis lluís lola lorena lucia lucía luis luisa manel manuel marc marcos margarida maria maría mariela marina mario marta martí marti mercè merce miquel mireia monica mónica montserrat narcis natalia nuria núria olga oriol pablo pau paula pedro pere pilar quim rafael ramon ramón raul raúl rebeca ricard ricardo roger rosa rosario rubén ruben sandra santiago sara sergi sergio silvia sílvia sonia sònia tomas tomás toni vanessa vicenc vicente victor víctor xavier yolanda')
    .split(/\s+/),
);
/** Words that make a name an organisation ("Maria Auxiliadora Residència", "Gestió Josep Mas SL"). */
const ORG_WORD = new Set(
  ('sl slu sa slp scp sccl cb coop cooperativa grup grupo group fundacio fundació fundacion associacio associació asociacion asociación ajuntament ayuntamiento consorci consorcio residencia residència centre centro hotel restaurant restaurante clinica clínica escola escuela institut instituto empresa serveis servicios services construccions construcciones transports transportes assessors asesores gestio gestió gestion gestión taller tallers farmacia farmàcia ceip ies cap hospital universitat universidad club associació mutua mútua despatx despacho advocats abogados estudi estudio llar casa mercat supermercat bar cafeteria pizzeria panaderia fleca forn carniceria peixateria perruqueria barberia')
    .split(/\s+/),
);

const lettersOnly = (t: string): boolean => /^[\p{L}'’.-]+$/u.test(t);

/** True when a name is a person's: 2 to 4 words, all letters, none an organisation word, the first a common given name. */
export function looksLikePerson(name: string): boolean {
  const tokens = name.trim().split(/\s+/).filter(Boolean);
  if (tokens.length < 2 || tokens.length > 4) return false;
  if (!tokens.every(lettersOnly)) return false;
  const low = tokens.map((t) => t.toLowerCase().replace(/[.'’-]/g, ''));
  if (low.some((t) => ORG_WORD.has(t))) return false;
  return GIVEN.has(low[0]!);
}

/**
 * The employer to show: the name as written unless it is a person's. "Person - Trade name" and "Person (Trade name)" keep the trade name when that is not a person
 * either; a bare person name is left empty.
 */
export function employerName(raw: string): string {
  const name = inlineText(raw);
  if (!name) return '';
  const dash = /^(.+?)\s+-\s+(.+)$/.exec(name);
  const paren = /^(.+?)\s*\(([^()]+)\)\s*$/.exec(name);
  const split = dash ?? paren;
  if (split && looksLikePerson(split[1]!)) {
    const trade = split[2]!.trim();
    return trade && !looksLikePerson(trade) ? trade : '';
  }
  return looksLikePerson(name) ? '' : name;
}

// --- one offer -------------------------------------------------------------------------------------------------------------------------

const clean = (html: string): string => maskPhones(cleanDescription(html), '[telèfon]');

export function normalizeFeinaActiva(ad: string, nowIso: string): Normalized {
  const id = tag(ad, 'id').trim();
  if (!/^[A-Za-z0-9]{4,30}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  if (tag(ad, 'status').trim().toUpperCase() !== 'PUBLISHED') return { ok: false, reason: 'not_published', externalId: id };
  const title = inlineText(tag(ad, 'title'));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const url = ownUrl(tag(ad, 'url').trim(), FEINAACTIVA_HOST);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const day = isoDay(tag(ad, 'date'));
  if (day && Date.parse(`${day}T00:00:00Z`) < Date.parse(nowIso) - FEINAACTIVA_MAX_AGE_DAYS * 86_400_000) return { ok: false, reason: 'stale', externalId: id };
  const content = clean(tag(ad, 'content'));
  const facts: string[] = [];
  const fact = (label: string, v: string) => { if (v) facts.push(`${label}: ${v}`); };
  fact('Experiència', clean(tag(ad, 'experience')));
  fact('Requisits', clean(tag(ad, 'requirements')));
  fact('Estudis', inlineText(tag(ad, 'studies')));
  fact('Contracte', inlineText(tag(ad, 'contract')));
  fact('Jornada', inlineText(tag(ad, 'workingHours')));
  if (/^s[ií]$/i.test(tag(ad, 'disability').trim())) facts.push('Oferta per a persones amb discapacitat');
  const description = [content, facts.join('\n')].filter(Boolean).join('\n\n');
  const city = townName(tag(ad, 'city'));
  const region = tag(ad, 'region');
  const contract = [inlineText(tag(ad, 'contract')), inlineText(tag(ad, 'workingHours'))].filter(Boolean).join(', ');
  const job: NormalizedJob = {
    source: 'feinaactiva', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: null,
    externalId: id, company: employerName(tag(ad, 'company')), title, description,
    country: regionCountry(region), city: city || null, workMode: 'unspecified', contractType: contract || null,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
    publishedAt: day ? `${day}T00:00:00.000Z` : null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

export function feinaActivaConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  return snapshotConnector({
    id: 'feinaactiva', fetchImpl, now, accept: 'application/xml', timeoutMs: 120_000, emptyIsError: true,
    url: opts.origin ? `${opts.origin.replace(/\/+$/, '')}/api/offers/offers-xml` : FEINAACTIVA_FEED,
    records: async (res) => {
      const xml = await res.text();
      if (!/^\s*(<\?xml[^>]*>\s*)?<ofertes>/.test(xml)) throw new HttpError(403); // not the feed: a challenge or an error page
      return ads(xml);
    },
    normalize: (raw, nowIso) => normalizeFeinaActiva(String(raw), nowIso),
  });
}
