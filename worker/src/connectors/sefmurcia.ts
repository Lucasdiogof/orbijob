import { cleanDescription } from '../description';
import { inlineText } from '../text';
import type { Connector, NormalizedJob } from '../types';
import { ownUrl, type Normalized } from './feeds';
import { jsonRecords, snapshotConnector } from './snapshot';
import { isoDay, townName } from './spain';

export { isoDay, townName };

/**
 * SEF, the Servicio de Empleo y Formación de la Región de Murcia (Spain): the job offers its offices publish for employers of the region, as open data of the
 * Región de Murcia (dataset "Ofertas de empleo activas en la Región de Murcia" on https://datosabiertos.regiondemurcia.es):
 *
 *   https://sefapps.carm.es/sefApps/rest/ofertas/ofertas   (one JSON array with every active offer, ≈ 250, refreshed on the site's own schedule)
 *
 * Licence: the data portal's legal notice (https://datosabiertos.regiondemurcia.es/avisolegal, Ley 37/2007 on the reuse of public-sector information) authorises
 * reuse, commercial or not, including copying, distribution and adaptation, on four conditions that are kept here: the source is cited ("Origen de los datos": the
 * owner of the data, stored in the source's attribution), the date of the data is mentioned (the offer's own start date is shown as its publication date), the sense of
 * the information is not distorted (title and text are kept as written; only the registration instructions are left out, see below), and nothing suggests that
 * the Region sponsors OrbiJob.
 *
 * The SEF publishes offers on behalf of employers and does NOT name them: the company stays empty (the app shows no company line) instead of inventing one; the
 * fingerprint then identifies the offer by its own id. Every offer links to its own page on https://sefoficinavirtual.carm.es (`urlDetalles`).
 *
 * The free text (`adicionales`) is HTML with the sections FUNCIONES, REQUISITOS, CONDICIONES and a final INSCRIPCION. The last one only tells the person how to
 * register at the SEF (an office's e-mail address, an ID-number instruction, the deadline); it is left out because the offer's page is where that happens, and
 * because the description must not carry contact details. Any e-mail address that remains is masked unless it is a role address. The offer's end date
 * (`fechaDeFin`) refuses an expired offer; the feed lists only active offers, so a listing that leaves it stops being stamped (`presenceConfirmsOpen`).
 */

export const SEFMURCIA_HOST = 'carm.es';
export const SEFMURCIA_FEED = 'https://sefapps.carm.es/sefApps/rest/ofertas/ofertas';

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const obj = (v: unknown): Record<string, unknown> => (typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : {});

/**
 * The free text up to (not including) its final registration section. The heading comes in many spellings in the real feed (`<b>INSCRIPCION:</b>`,
 * `<B>INSCRIPCIÓN</B>`, `<b>INSCRIPCION EN LA OFERTA:</b>`, `<u>INSCRIPCION</u>`); the few offers without a heading start the section with the sentence
 * "Si está inscrito/a en una oficina …".
 */
export function withoutRegistration(html: string): string {
  const heading = html.search(/<[a-z]+[^>]*>\s*(?:<[a-z]+[^>]*>\s*)*INSCRIPCI[OÓ]N\b/i);
  if (heading >= 0) return html.slice(0, heading);
  const sentence = html.search(/Si est[aá] inscrit[oa]\/?a?\s+en una oficina/i);
  return sentence >= 0 ? html.slice(0, sentence) : html;
}

const SECTOR_LABEL = 'Sector profesional';

export function normalizeSefMurcia(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = (typeof r.numeroOferta === 'number' ? String(r.numeroOferta) : str(r.numeroOferta)).trim();
  if (!/^[0-9]{6,20}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(r.descripcion));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const url = ownUrl(r.urlDetalles, SEFMURCIA_HOST);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const end = isoDay(str(r.fechaDeFin));
  if (end && Date.parse(`${end}T21:59:59Z`) < Date.parse(nowIso)) return { ok: false, reason: 'expired', externalId: id };
  const start = isoDay(str(r.fechaDeInicio));
  const body = cleanDescription(withoutRegistration(str(r.adicionales)));
  const facts: string[] = [];
  const fact = (label: string, v: string) => { if (v) facts.push(`${label}: ${v}`); };
  fact(SECTOR_LABEL, inlineText(str(obj(r.sectorProfesional).denominacion)));
  fact('Nivel profesional', inlineText(str(r.descNivelProfesional)));
  if (typeof r.mesesExperiencia === 'number' && r.mesesExperiencia > 0) fact('Experiencia (meses)', String(r.mesesExperiencia));
  fact('Permisos de conducir', inlineText(str(r.permisosConducir)));
  const description = [body, facts.join('\n')].filter(Boolean).join('\n\n');
  const contract = [/Contrato\s*:?\s+([^\n.]+)/i.exec(body)?.[1], /Jornada\s*:\s*([^\n.]+)/i.exec(body)?.[1]].map((s) => inlineText(s ?? '')).filter(Boolean).join(', ');
  const town = townName(str(obj(r.municipio).municipio));
  const job: NormalizedJob = {
    source: 'sefmurcia', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: 'es',
    externalId: id, company: '', title, description,
    country: 'ES', city: town || null, workMode: 'unspecified', contractType: contract || null,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
    publishedAt: start ? `${start}T00:00:00.000Z` : null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

export function sefMurciaConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  return snapshotConnector({
    id: 'sefmurcia', fetchImpl, now, accept: 'application/json', timeoutMs: 60_000,
    url: opts.origin ? `${opts.origin.replace(/\/+$/, '')}/sefApps/rest/ofertas/ofertas` : SEFMURCIA_FEED,
    records: (res) => jsonRecords(res),
    normalize: normalizeSefMurcia,
  });
}
