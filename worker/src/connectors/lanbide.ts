import { cleanDescription } from '../description';
import { HttpError, parseRetryAfter } from '../http';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob } from '../types';
import { ownUrl, type Normalized } from './feeds';
import { ES_PHONE } from './feinaactiva';
import { townName } from './sefmurcia';

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

const clean = (html: string): string => cleanDescription(html).replace(ES_PHONE, '[teléfono]');

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
  const feed = opts.origin ? `${opts.origin.replace(/\/+$/, '')}/apps/OF_OFERTAS_ODE_JSON` : LANBIDE_FEED;
  return {
    id: 'lanbide',
    minIntervalMs: 1500,
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      if (cursor) throw new Error('lanbide: invalid cursor');
      const res = await fetchImpl(feed, { headers: { Accept: 'application/json', 'User-Agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)' }, signal: AbortSignal.timeout(90_000) });
      if (!res.ok) throw new HttpError(res.status, parseRetryAfter(res.headers.get('retry-after')));
      let data: unknown;
      try {
        data = JSON.parse(decodeFeed(await res.arrayBuffer()));
      } catch {
        throw new HttpError(403); // not JSON: a challenge or an error page
      }
      if (!Array.isArray(data)) throw new Error('lanbide: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data) {
        const n = normalizeLanbide(raw, nowIso);
        if (n.ok) jobs.push(n.job); else if (n.reason !== 'stale') rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      return { jobs, nextCursor: null, isFullSnapshot: false, rejected };
    },
  };
}
