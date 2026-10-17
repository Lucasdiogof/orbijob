import { inlineText } from '../text';
import type { Connector, NormalizedJob } from '../types';
import { ownUrl, type Normalized } from './feeds';
import { jsonRecords, snapshotConnector } from './snapshot';

/**
 * The City of Calgary (Alberta, Canada): the job opportunities of the municipality as open data on its Socrata portal (dataset "City of Calgary Careers", id
 * `5fsi-n9xm`, ≈ 55 current listings, refreshed on the portal's schedule):
 *
 *   https://data.calgary.ca/resource/5fsi-n9xm.json
 *
 * Licence: "Open Government Licence – City of Calgary" v2.1 (https://data.calgary.ca/stories/s/Open-Calgary-Terms-of-Use/u45n-7awa/): worldwide, royalty-free,
 * perpetual, including commercial purposes; copy, modify, publish, translate, adapt and distribute in any medium; the condition is to acknowledge the source with the
 * attribution statement ("Contains information licensed under the Open Government Licence – City of Calgary") and, where possible, a link to the licence. It excludes
 * personal information, the City's names and logos used to suggest endorsement, and third-party rights. The listings carry no personal data (title, area, deadline, link).
 *
 * The dataset holds only the job-opening id, title, area, closing date and the link to the posting on https://recruiting.calgary.ca. There is no description, no
 * publication date and no location per listing: the employer is the City itself (the dataset's own description: "the job opportunities with The City of Calgary"),
 * so the company is "The City of Calgary" and the city Calgary; no salary, date of publication or work mode is invented. The closing date refuses a listing that has
 * closed. The file lists only open listings, so one that leaves it stops being stamped (`presenceConfirmsOpen`).
 */

export const CALGARY_HOST = 'calgary.ca';
export const CALGARY_FEED = 'https://data.calgary.ca/resource/5fsi-n9xm.json?$limit=500';
export const CALGARY_EMPLOYER = 'The City of Calgary';

const str = (v: unknown): string => (typeof v === 'string' ? v : '');

/** The calendar day of an ISO timestamp as the portal writes it ("2026-10-26T00:00:00.000"), or "" for anything else. */
function closingDay(v: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})(?:T|$)/.exec(v.trim());
  if (!m) return '';
  const d = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
  return d.getUTCFullYear() === Number(m[1]) && d.getUTCMonth() === Number(m[2]) - 1 && d.getUTCDate() === Number(m[3]) ? `${m[1]}-${m[2]}-${m[3]}` : '';
}

export function normalizeCalgary(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = str(r.job_opening_id).trim();
  if (!/^[0-9]{4,12}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(r.title));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const url = ownUrl(str(r.job_description).trim(), CALGARY_HOST);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const closes = closingDay(str(r.closing_date));
  // the posting stays open through its closing day (Mountain time is at most 7 h behind UTC)
  if (closes && Date.parse(`${closes}T23:59:59-07:00`) < Date.parse(nowIso)) return { ok: false, reason: 'expired', externalId: id };
  const area = inlineText(str(r.area));
  const description = [area ? `Area: ${area}` : '', closes ? `Closing date: ${closes}` : ''].filter(Boolean).join('\n');
  const job: NormalizedJob = {
    source: 'calgary', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: 'en',
    externalId: id, company: CALGARY_EMPLOYER, title, description,
    country: 'CA', city: 'Calgary', workMode: 'unspecified', contractType: null,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
    publishedAt: null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

export function calgaryConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  return snapshotConnector({
    id: 'calgary', fetchImpl, now, accept: 'application/json', timeoutMs: 60_000,
    url: opts.origin ? `${opts.origin.replace(/\/+$/, '')}/resource/5fsi-n9xm.json?$limit=500` : CALGARY_FEED,
    records: (res) => jsonRecords(res),
    normalize: normalizeCalgary,
    emptyIsError: true,
  });
}
