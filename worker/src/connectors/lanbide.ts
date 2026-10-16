import { cleanDescription } from '../description';
import { inlineText } from '../text';
import type { Connector, NormalizedJob } from '../types';
import { ownUrl, type Normalized } from './feeds';
import { jsonRecords, snapshotConnector } from './snapshot';
import { maskPhones, townName } from './spain';

/**
 * Lanbide, the Basque employment service (Spain): the job offers it manages, as open data of Open Data Euskadi (dataset "Ofertas de empleo de Lanbide", ≈ 500 offers,
 * refreshed through the day, only offers Lanbide manages, not the ones it merely lists from the press):
 *
 *   https://apps.lanbide.euskadi.net/apps/OF_OFERTAS_ODE_JSON
 *
 * Licence: Creative Commons Attribution 4.0 (stated on the dataset's distributions, https://creativecommons.org/licenses/by/4.0/). The attribution is stored with the source.
 * Every offer links to its own page on https://web.lanbide.eus.
 *
 * Encoding: the response says UTF-8 but its bytes are ISO-8859-1 ("Dise\xf1o"); it is read as UTF-8 when that is valid and as ISO-8859-1 otherwise, so accents survive.
 * The offer does not name the employer: the company stays empty. The offer's date is `fecPub`; an offer whose publication AND last modification are over 90 days old is
 * refused (the feed has no end date). The text may end with how to apply: telephone numbers are masked and e-mail addresses masked unless they are role addresses. The
 * country is Spain when the offer states "ESPAÑA" (it also lists the neighbouring provinces of Navarra, Asturias, …); any other country name states none.
 * A listing that leaves the feed stops being stamped (`presenceConfirmsOpen`).
 */

export const LANBIDE_HOST = 'lanbide.eus';
export const LANBIDE_FEED = 'https://apps.lanbide.euskadi.net/apps/OF_OFERTAS_ODE_JSON';
export const LANBIDE_MAX_AGE_DAYS = 90;

const str = (v: unknown): string => (typeof v === 'string' ? v : '');

/** Bytes of the feed as text: UTF-8 when valid, else ISO-8859-1. */
export function decodeFeed(bytes: ArrayBuffer): string {
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch {
    return new TextDecoder('iso-8859-1').decode(bytes);
  }
}

/** dd/mm/yyyy -> epoch ms (UTC midnight), or NaN. */
function day(s: string): number {
  const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(s.trim());
  if (!m) return NaN;
  const t = Date.UTC(Number(m[3]), Number(m[2]) - 1, Number(m[1]));
  return new Date(t).getUTCDate() === Number(m[1]) ? t : NaN;
}

const fold = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase().trim();

const clean = (html: string): string => maskPhones(cleanDescription(html), '[teléfono]');

export function normalizeLanbide(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = (typeof r.codigo === 'number' ? String(r.codigo) : str(r.codigo)).trim();
  if (!/^[0-9]{6,20}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(r.desEmpleo));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const url = ownUrl(str(r.url).trim(), LANBIDE_HOST);
  if (!url || !new URL(url).search.includes(`IDRG=${id}`)) return { ok: false, reason: 'invalid_url', externalId: id };
  const pub = day(str(r.fecPub));
  const mod = day(str(r.fecMod));
  const cutoff = Date.parse(nowIso) - LANBIDE_MAX_AGE_DAYS * 86_400_000;
  const newest = Math.max(Number.isFinite(pub) ? pub : -Infinity, Number.isFinite(mod) ? mod : -Infinity);
  if (Number.isFinite(newest) && newest < cutoff) return { ok: false, reason: 'stale', externalId: id };
  const body = clean(str(r.desPuesto));
  const province = inlineText(str(r.provincia));
  const facts: string[] = [];
  if (province) facts.push(`Provincia: ${province}`);
  if (str(r.disc).trim().toUpperCase() === 'S') facts.push('Oferta para personas con discapacidad');
  const description = [body, facts.join('\n')].filter(Boolean).join('\n\n');
  const job: NormalizedJob = {
    source: 'lanbide', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: 'es',
    externalId: id, company: '', title, description,
    country: fold(str(r.pais)) === 'ESPANA' ? 'ES' : null, city: townName(str(r.municipio)) || null, workMode: 'unspecified', contractType: null,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
    publishedAt: Number.isFinite(pub) ? new Date(pub).toISOString() : null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

export function lanbideConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  return snapshotConnector({
    id: 'lanbide', fetchImpl, now, accept: 'application/json', timeoutMs: 90_000,
    url: opts.origin ? `${opts.origin.replace(/\/+$/, '')}/apps/OF_OFERTAS_ODE_JSON` : LANBIDE_FEED,
    records: (res) => jsonRecords(res, decodeFeed),
    normalize: normalizeLanbide,
  });
}
