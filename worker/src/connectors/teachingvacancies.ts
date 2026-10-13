import { cleanDescription } from '../description';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob, SalaryPeriod } from '../types';
import { getFeed, ownUrl, type Normalized } from './feeds';

/**
 * Teaching Vacancies, the Department for Education's (England) free job service for schools, through its open API:
 *
 *   https://teaching-vacancies.service.gov.uk/api/v1/jobs.json?page=N      schema.org JobPosting, 100 per page, newest first
 *
 * Terms for API users (https://teaching-vacancies.service.gov.uk/pages/terms-and-conditions#terms-and-conditions-for-api-users, read 2026-10-13):
 * "You are free to reuse job listing data under the terms of the Open Government Licence for public sector information with the following
 * exception: you must not charge any fee or commission for contacting, interviewing or hiring a respondent to your listing". OGL v3.0 asks for
 * attribution, which the catalogue shows with every listing together with a link to the listing's own page; OrbiJob charges nobody anything.
 * The listing is not just teachers: head teachers, teaching assistants, administrators, finance, IT support, catering, cleaning and site staff.
 *
 * The feed lists only open vacancies and every one carries `validThrough`, so an expired one is refused. A listing in the feed IS the proof that
 * it is open (`presenceConfirmsOpen`); the whole feed (about 70 pages) is read each pass, so a listing that disappears simply stops being
 * stamped. Nothing is guessed: the country is the one the listing states (`addressCountry`), and a salary is stored only when the text states
 * one or two amounts and the listing gives the period.
 */

export const TEACHINGVACANCIES_HOST = 'teaching-vacancies.service.gov.uk';
export const TEACHINGVACANCIES_MAX_PAGES = 90;
const MAX_DESCRIPTION = 6000;

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const obj = (v: unknown): Record<string, unknown> => (typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : {});
const arr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);

const TYPE: Record<string, string> = { FULL_TIME: 'Full-time', PART_TIME: 'Part-time', TEMPORARY: 'Temporary', CONTRACTOR: 'Contract', INTERN: 'Internship', CASUAL: 'Casual' };
const PERIOD: Record<string, SalaryPeriod> = { HOUR: 'hour', DAY: 'day', WEEK: 'week', MONTH: 'month', YEAR: 'year' };
const PLAIN = new Set(['to', 'per', 'annum', 'annually', 'annual', 'a', 'year', 'yearly', 'hour', 'hourly', 'day', 'daily', 'week', 'weekly', 'month', 'monthly', 'fte', 'pro', 'rata', 'pa', 'p', 'full', 'time', 'equivalent']);
const RANGE: Record<SalaryPeriod, [number, number]> = { hour: [5, 500], day: [30, 2000], week: [100, 10_000], month: [400, 40_000], year: [5000, 500_000] };

/** "£31,015 to £33,673", "£13.45 per hour", "£37,597.00 - £39,598.00 Annually (FTE)": one or two £ amounts. A grade or a point scale ("Grade 3 Point 5 - 6") states none. */
export function parseSalary(base: unknown): { min: number; max: number; currency: string; period: SalaryPeriod } | null {
  const b = obj(base);
  const value = obj(b.value);
  const period = PERIOD[str(value.unitText).toUpperCase()];
  if (!period || str(b.currency) !== 'GBP') return null;
  const text = str(value.value);
  const amounts = [...text.matchAll(/£\s*(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?/g)].map((m) => Number(`${m[1]!.replace(/,/g, '')}${m[2] ? `.${m[2]}` : ''}`));
  if (amounts.length < 1 || amounts.length > 2) return null;
  // only plain wording around the amounts: anything else ("+ TLR 2c", "L9 -11", "Grade 3 Point 5", a second scale) makes the figure ambiguous
  const rest = text.replace(/£\s*(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?/g, ' ').toLowerCase().match(/[a-z]+|\d+/g) ?? [];
  if (!rest.every((w) => PLAIN.has(w))) return null;
  const [lo, hi] = [amounts[0]!, amounts[1] ?? amounts[0]!];
  const [min, max] = RANGE[period];
  if (!(lo >= min && hi <= max && hi >= lo)) return null;
  return { min: lo, max: hi, currency: 'GBP', period };
}

/** The slug in the listing's own address (`/jobs/{slug}`) is the stable id. */
function slugOf(url: string): string | null {
  const m = /^\/jobs\/([A-Za-z0-9][A-Za-z0-9._~-]{0,198})$/.exec(new URL(url).pathname);
  return m ? m[1]! : null;
}

export function normalizeTeachingVacancies(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const url = ownUrl(r.url, TEACHINGVACANCIES_HOST);
  const id = url ? slugOf(url) : null;
  if (!url || !id) return { ok: false, reason: 'invalid_url', externalId: null };
  const title = inlineText(str(r.title));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const company = inlineText(str(obj(r.hiringOrganization).name));
  if (!company) return { ok: false, reason: 'missing_company', externalId: id };
  const through = Date.parse(str(r.validThrough));
  if (Number.isFinite(through) && through < Date.parse(nowIso)) return { ok: false, reason: 'expired', externalId: id };

  const addr = obj(obj(r.jobLocation).address);
  const countryCode = str(addr.addressCountry).trim().toUpperCase();
  const city = inlineText(str(addr.addressLocality)) || inlineText(str(addr.addressRegion)) || null;
  const benefits = cleanDescription(str(r.jobBenefits));
  let description = cleanDescription(str(r.description));
  if (benefits) description = `${description}${description ? '\n\n' : ''}${benefits}`;
  if (description.length > MAX_DESCRIPTION) description = `${description.slice(0, MAX_DESCRIPTION).trimEnd()}…`;
  const types = arr(r.employmentType).map((t) => TYPE[str(t)]).filter((t): t is string => Boolean(t));
  const posted = Date.parse(str(r.datePosted));
  const sal = parseSalary(r.baseSalary);
  const job: NormalizedJob = {
    source: 'teachingvacancies', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: null,
    externalId: id, company, title, description,
    country: /^[A-Z]{2}$/.test(countryCode) ? countryCode : null, city,
    workMode: 'unspecified', contractType: types.length ? types.join(', ') : null,
    salaryMin: sal?.min ?? null, salaryMax: sal?.max ?? null, salaryCurrency: sal?.currency ?? null, salaryPeriod: sal?.period ?? null,
    publishedAt: Number.isFinite(posted) ? new Date(posted).toISOString() : null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

export function teachingVacanciesConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const ORIGIN = (opts.origin ?? 'https://teaching-vacancies.service.gov.uk').replace(/\/+$/, '');
  return {
    id: 'teachingvacancies',
    minIntervalMs: 1500,
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      const page = cursor ? Number(cursor) : 1;
      if (!Number.isInteger(page) || page < 1 || page > TEACHINGVACANCIES_MAX_PAGES) throw new Error('teachingvacancies: invalid cursor');
      const data = await getFeed<{ data?: unknown; meta?: { totalPages?: unknown } }>(fetchImpl, `${ORIGIN}/api/v1/jobs.json?page=${page}`);
      if (!Array.isArray(data.data)) throw new Error('teachingvacancies: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data.data) {
        const n = normalizeTeachingVacancies(raw, nowIso);
        if (n.ok) jobs.push(n.job); else if (n.reason !== 'expired') rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      const totalPages = typeof data.meta?.totalPages === 'number' ? data.meta.totalPages : page;
      const more = page < totalPages && page < TEACHINGVACANCIES_MAX_PAGES && data.data.length > 0;
      return { jobs, nextCursor: more ? String(page + 1) : null, isFullSnapshot: false, rejected };
    },
  };
}
