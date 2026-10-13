import { cleanDescription } from '../description';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob, SalaryPeriod } from '../types';
import { getFeed, ownUrl, type Normalized } from './feeds';

/**
 * NYC Jobs, the City of New York's job postings, from NYC Open Data (Socrata dataset `kpav-sd4t`, "Jobs NYC Postings", Department of Citywide
 * Administrative Services, refreshed daily):
 *
 *   https://data.cityofnewyork.us/resource/kpav-sd4t.json?$where=posting_type='External'&$order=job_id&$limit=500&$offset=N
 *
 * Licence: NYC Open Data is published under the City's Open Data Law (Local Law 11 of 2012; Administrative Code §23-501 and following), which
 * requires public data sets to be available without registration, licence requirement or restriction on their use. The dataset describes itself as
 * "current job postings available on the City of New York's official jobs site" and distinguishes Internal postings (city employees only), which are
 * NEVER read here, from External ones (open to the public). Each listing links to its own page on https://cityjobs.nyc.gov/job/{job_id}, which
 * the city's site redirects to the posting (an unknown id answers 404). The dataset is the whole current list, read in full each pass, so a posting
 * that disappears simply stops being stamped. Nothing is guessed: the country is the United States because the employer is the City of New York; a city
 * is stored only when the stated work location names a borough; a salary only with its stated period; the work mode is not stated.
 */

export const NYCJOBS_HOST = 'cityjobs.nyc.gov';
export const NYCJOBS_PAGE = 500;
export const NYCJOBS_MAX_PAGES = 8;
const MAX_DESCRIPTION = 6000;

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const SMALL = new Set(['of', 'and', 'the', 'for', 'to', 'in', 'on', 'a', 'at']);

/** "DEPT OF HEALTH/MENTAL HYGIENE" -> "Dept of Health/Mental Hygiene": all-capital agency names are written in title case; short acronyms (NYC, DOE) stay. */
export function agencyName(raw: string): string {
  const s = inlineText(raw);
  if (!s || s !== s.toUpperCase()) return s;
  return s.toLowerCase().replace(/[a-z][a-z'’.]*/g, (w, i: number) => {
    if (i > 0 && SMALL.has(w)) return w;
    return w.charAt(0).toUpperCase() + w.slice(1);
  }).replace(/\b(Nyc|Nypd|Fdny|Doe|Dcas|Hra|Dhs|Doh|Dep|Dot|Dsny|Doitt|Ems|Hpd|Tlc|Mta|Nycha|Cuny|Dycd|Acs)\b/g, (m) => m.toUpperCase());
}

const PERIOD: Record<string, SalaryPeriod> = { annual: 'year', hourly: 'hour', daily: 'day' };
const RANGE: Record<SalaryPeriod, [number, number]> = { hour: [5, 500], day: [30, 3000], week: [100, 10_000], month: [400, 40_000], year: [5000, 600_000] };

const MONTHS: Record<string, number> = { JAN: 0, FEB: 1, MAR: 2, APR: 3, MAY: 4, JUN: 5, JUL: 6, AUG: 7, SEP: 8, OCT: 9, NOV: 10, DEC: 11 };
/** "17-OCT-2026" (the last day the posting is open) -> the end of that day, UTC; null when absent or unreadable. */
export function postUntil(v: unknown): number | null {
  const m = /^(\d{1,2})-([A-Za-z]{3})-(\d{4})$/.exec(str(v).trim());
  if (!m || MONTHS[m[2]!.toUpperCase()] === undefined) return null;
  const day = Number(m[1]);
  const t = Date.UTC(Number(m[3]), MONTHS[m[2]!.toUpperCase()]!, day, 23, 59, 59);
  return Number.isFinite(t) && new Date(t).getUTCDate() === day ? t : null; // 32-OCT or 31-NOV would roll over into another day

}

const BOROUGH = /\b(manhattan|brooklyn|bronx|queens|staten island)\b/i;
/** A city only when the stated work location names a borough: "New York City" is then the place; otherwise it stays empty. */
function cityOf(location: string): string | null {
  return BOROUGH.test(location) ? 'New York City' : null;
}

export function normalizeNycJob(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = str(r.job_id).trim();
  if (!/^[1-9][0-9]{0,11}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  if (str(r.posting_type) !== 'External') return { ok: false, reason: 'internal_posting', externalId: id }; // city employees only: never shown
  const title = inlineText(str(r.business_title)) || inlineText(str(r.civil_service_title));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const agency = agencyName(str(r.agency));
  if (!agency) return { ok: false, reason: 'missing_company', externalId: id };
  const url = ownUrl(`https://${NYCJOBS_HOST}/job/${id}`, NYCJOBS_HOST);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const until = postUntil(r.post_until);
  if (until !== null && until < Date.parse(nowIso)) return { ok: false, reason: 'expired', externalId: id };

  const sections: string[] = [];
  const add = (label: string, body: unknown) => {
    const text = cleanDescription(str(body));
    if (text) sections.push(label ? `${label}\n${text}` : text);
  };
  add('', r.job_description);
  add('Minimum qualifications', r.minimum_qual_requirements);
  add('Preferred skills', r.preferred_skills);
  add('Additional information', r.additional_information);
  const loc = inlineText(str(r.work_location_1)) || inlineText(str(r.work_location));
  if (loc) sections.push(`Work location\n${loc}`);
  let description = sections.join('\n\n');
  if (description.length > MAX_DESCRIPTION) description = `${description.slice(0, MAX_DESCRIPTION).trimEnd()}…`;

  const period = PERIOD[str(r.salary_frequency).trim().toLowerCase()];
  const lo = Number(str(r.salary_range_from));
  const hi = Number(str(r.salary_range_to) || str(r.salary_range_from));
  const salaryOk = period !== undefined && Number.isFinite(lo) && Number.isFinite(hi) && lo >= RANGE[period][0] && hi <= RANGE[period][1] && hi >= lo;
  const posted = Date.parse(str(r.posting_date));
  const ft = str(r.full_time_part_time_indicator).toUpperCase();
  const job: NormalizedJob = {
    source: 'nycjobs', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: null,
    externalId: id, company: agency, title, description,
    country: 'US', city: cityOf(loc), workMode: 'unspecified', contractType: ft === 'F' ? 'Full-time' : ft === 'P' ? 'Part-time' : null,
    salaryMin: salaryOk ? lo : null, salaryMax: salaryOk ? hi : null, salaryCurrency: salaryOk ? 'USD' : null, salaryPeriod: salaryOk ? period! : null,
    publishedAt: Number.isFinite(posted) ? new Date(posted).toISOString() : null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

export function nycJobsConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const ORIGIN = (opts.origin ?? 'https://data.cityofnewyork.us').replace(/\/+$/, '');
  return {
    id: 'nycjobs',
    minIntervalMs: 2000, // the portal's robots.txt asks for a crawl delay of one second
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      const offset = cursor ? Number(cursor) : 0;
      if (!Number.isInteger(offset) || offset < 0 || offset % NYCJOBS_PAGE !== 0 || offset >= NYCJOBS_PAGE * NYCJOBS_MAX_PAGES) throw new Error('nycjobs: invalid cursor');
      const where = encodeURIComponent("posting_type='External'");
      const data = await getFeed<unknown>(fetchImpl, `${ORIGIN}/resource/kpav-sd4t.json?$where=${where}&$order=job_id&$limit=${NYCJOBS_PAGE}&$offset=${offset}`);
      if (!Array.isArray(data)) throw new Error('nycjobs: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data) {
        const n = normalizeNycJob(raw, nowIso);
        if (n.ok) jobs.push(n.job); else if (n.reason !== 'expired') rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      const more = data.length === NYCJOBS_PAGE && offset + NYCJOBS_PAGE < NYCJOBS_PAGE * NYCJOBS_MAX_PAGES;
      return { jobs, nextCursor: more ? String(offset + NYCJOBS_PAGE) : null, isFullSnapshot: false, rejected };
    },
  };
}
