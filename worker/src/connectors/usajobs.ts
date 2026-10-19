import { cleanDescription } from '../description';
import { HttpError, parseRetryAfter } from '../http';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob, SalaryPeriod } from '../types';
import { ownUrl, type Normalized } from './feeds';

/**
 * USAJOBS, the job site of the United States federal government (operated by the U.S. Office of Personnel Management), through its Search API:
 *
 *   GET https://data.usajobs.gov/api/search?ResultsPerPage=500&Page=N&SortField=opendate&SortDirection=desc
 *   headers: User-Agent = the e-mail address the key was requested with, Authorization-Key = the key
 *
 * Terms (https://developer.usajobs.gov/guides/terms-of-service, read 2026-10-16): the "Public Data" the API returns "may be copied, stored, reformatted, adapted, analyzed,
 * published, redistributed" for lawful commercial or non-commercial purposes, without advance approval; attribution is encouraged (identify USAJOBS, link to the current official
 * announcement, say that the product is not operated or endorsed by OPM); rate limits apply; presenting modified data as official is forbidden. Registration requires
 * current and accurate contact information: the key and the contact e-mail are the owner's (secrets \`USAJOBS_API_KEY\` and variable \`USAJOBS_CONTACT_EMAIL\`), never part of
 * the code or of any log.
 *
 * What is stored, and only what the API states: the position title, the agency (organization and department), the location(s), the salary range with its rate
 * interval (annual or hourly; any other interval is not mapped), the publication date, the summary, the major duties, the qualifications, who may apply, the schedule and
 * the appointment type. Every listing links to its own page on https://www.usajobs.gov. Nothing is guessed: the country comes from the location's country name, a
 * remote job is marked remote only when the announcement says RemoteIndicator, eligibility (geo restrictions) is left unknown (many announcements are open to U.S.
 * citizens only: that is shown as "Who may apply", never hidden and never read as "anywhere"). The contact data an announcement may carry (agency contact e-mail and
 * phone) is not stored. The newest announcements are read first; the window is the ceiling of the source, a listing that leaves it stops being stamped.
 */

export const USAJOBS_HOST = 'usajobs.gov';
export const USAJOBS_ORIGIN = 'https://data.usajobs.gov';
export const USAJOBS_PAGE = 500;
export const USAJOBS_MAX_PAGES = 4;
const MAX_DESCRIPTION = 9000;

const str = (v: unknown): string => (typeof v === 'string' ? v : typeof v === 'number' ? String(v) : '');
const obj = (v: unknown): Record<string, unknown> => (typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : {});
const arr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);

const PERIOD: Record<string, SalaryPeriod> = { PA: 'year', PH: 'hour' };
const RANGE: Record<SalaryPeriod, [number, number]> = { hour: [5, 500], day: [30, 3000], week: [100, 10_000], month: [400, 40_000], year: [5000, 600_000] };

/**
 * The API writes the closing moment without a time zone ("2026-10-30" or "2026-10-30T23:59:59.9970000"); announcements close at the end of that day in the
 * United States (Eastern time at most five hours behind UTC), so the end of the day is taken at UTC-5: never earlier than the real closing. Null when unreadable.
 */
export function closingTime(v: unknown): number | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})(?:$|T)/.exec(str(v).trim());
  if (!m) return null;
  const t = Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 23, 59, 59);
  return new Date(t).getUTCDate() === Number(m[3]) ? t + 5 * 3_600_000 : null;
}

/** The closing day exactly as the API wrote it (YYYY-MM-DD), or ''. */
const closingDay = (v: unknown): string => /^(\d{4}-\d{2}-\d{2})(?:$|T)/.exec(str(v).trim())?.[1] ?? '';

const names = (v: unknown): string[] => [...new Set(arr(v).map((x) => inlineText(str(obj(x).Name))).filter(Boolean))];

/** The agency: the organization and, when it differs, its department ("Office of the Secretary, Department of Commerce"). */
export function agencyOf(d: Record<string, unknown>): string {
  const org = inlineText(str(d.OrganizationName));
  const dep = inlineText(str(d.DepartmentName));
  if (org && dep && org.toLowerCase() !== dep.toLowerCase() && !org.toLowerCase().includes(dep.toLowerCase())) return `${org}, ${dep}`;
  return org || dep;
}

export function normalizeUsaJob(raw: unknown, nowIso: string): Normalized {
  const item = obj(raw);
  const d = obj(item.MatchedObjectDescriptor);
  const id = str(item.MatchedObjectId).trim();
  if (!/^[1-9][0-9]{4,12}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(d.PositionTitle));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const company = agencyOf(d);
  if (!company) return { ok: false, reason: 'missing_company', externalId: id };
  const url = ownUrl(str(d.PositionURI), USAJOBS_HOST);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const apply = ownUrl(str(arr(d.ApplyURI)[0]), USAJOBS_HOST) ?? url;
  const closes = closingTime(d.ApplicationCloseDate);
  if (closes !== null && closes < Date.parse(nowIso)) return { ok: false, reason: 'expired', externalId: id };

  const details = obj(obj(d.UserArea).Details);
  const locations = arr(d.PositionLocation).map(obj);
  const first = locations[0] ?? {};
  const countryName = inlineText(str(first.CountryCode)).toLowerCase();
  const country = countryName === 'united states' || countryName === 'us' || countryName === 'usa' ? 'US' : null;
  const display = inlineText(str(d.PositionLocationDisplay));
  const city = locations.length > 1 ? display || 'Multiple locations' : inlineText(str(first.CityName)) || display || null;

  const pay = obj(arr(d.PositionRemuneration)[0]);
  const period = PERIOD[str(pay.RateIntervalCode).trim().toUpperCase()];
  const lo = Number(str(pay.MinimumRange).replace(/[$,]/g, ''));
  const hi = Number(str(pay.MaximumRange).replace(/[$,]/g, '') || str(pay.MinimumRange).replace(/[$,]/g, ''));
  const salaryOk = period !== undefined && Number.isFinite(lo) && Number.isFinite(hi) && lo > 0 && lo >= RANGE[period][0] && hi <= RANGE[period][1] && hi >= lo;

  const sections: string[] = [];
  const add = (label: string, body: unknown) => {
    const text = cleanDescription(Array.isArray(body) ? body.map((x) => `- ${str(x)}`).join('\n') : str(body));
    if (text) sections.push(label ? `${label}\n${text}` : text);
  };
  add('', details.JobSummary);
  add('Major duties', details.MajorDuties);
  add('Qualifications', d.QualificationSummary);
  add('Requirements', details.Requirements);
  const facts: string[] = [];
  const fact = (label: string, v: string) => { if (v) facts.push(`${label}: ${v}`); };
  fact('Who may apply', inlineText(str(obj(details.WhoMayApply).Name)));
  fact('Agency', company);
  fact('Series', names(d.JobCategory).join(', '));
  fact('Grade', arr(d.JobGrade).map((g) => inlineText(str(obj(g).Code))).filter(Boolean).join(', '));
  fact('Schedule', names(d.PositionSchedule).join(', '));
  fact('Appointment', names(d.PositionOfferingType).join(', '));
  if (closes !== null) fact('Closing date', closingDay(d.ApplicationCloseDate));
  if (facts.length) sections.push(facts.join('\n'));
  let description = sections.join('\n\n');
  if (description.length > MAX_DESCRIPTION) description = `${description.slice(0, MAX_DESCRIPTION).trimEnd()}…`;

  const schedule = names(d.PositionSchedule).join(', ');
  const posted = Date.parse(str(d.PublicationStartDate));
  const remote = str(details.RemoteIndicator).trim().toLowerCase() === 'true';
  const job: NormalizedJob = {
    source: 'usajobs', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: 'en',
    externalId: id, company, title, description,
    country, city: city || null, workMode: remote ? 'remote' : 'unspecified', contractType: schedule || null,
    salaryMin: salaryOk ? lo : null, salaryMax: salaryOk ? hi : null, salaryCurrency: salaryOk ? 'USD' : null, salaryPeriod: salaryOk ? period! : null,
    publishedAt: Number.isFinite(posted) ? new Date(posted).toISOString() : null,
    originalUrl: url, applyUrl: apply, geoRestrictions: [],
  };
  return { ok: true, job };
}

export function usaJobsConnector(
  fetchImpl: typeof fetch,
  now: () => Date = () => new Date(),
  opts: { origin?: string; apiKey?: string; email?: string } = {},
): Connector {
  const ORIGIN = (opts.origin ?? USAJOBS_ORIGIN).replace(/\/+$/, '');
  return {
    id: 'usajobs',
    minIntervalMs: 2000,
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      const key = (opts.apiKey ?? '').trim();
      const email = (opts.email ?? '').trim();
      // the credentials belong to the owner (secret and variable): without them nothing is requested, and the message never carries a value
      if (!key) throw new Error('usajobs: USAJOBS_API_KEY is not set');
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('usajobs: USAJOBS_CONTACT_EMAIL is not set (the e-mail address the key was requested with)');
      const page = cursor ? Number(cursor) : 1;
      if (!Number.isInteger(page) || page < 1 || page > USAJOBS_MAX_PAGES) throw new Error('usajobs: invalid cursor');
      const url = `${ORIGIN}/api/search?ResultsPerPage=${USAJOBS_PAGE}&Page=${page}&SortField=opendate&SortDirection=desc`;
      const res = await fetchImpl(url, { headers: { Accept: 'application/json', 'User-Agent': email, 'Authorization-Key': key }, signal: AbortSignal.timeout(60_000) });
      if (!res.ok) throw new HttpError(res.status, parseRetryAfter(res.headers.get('retry-after')));
      let data: unknown;
      try {
        data = JSON.parse(await res.text());
      } catch {
        throw new HttpError(403); // not JSON: a challenge or an error page
      }
      const result = obj(obj(data).SearchResult);
      const items = result.SearchResultItems;
      if (!Array.isArray(items)) throw new Error('usajobs: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of items) {
        const n = normalizeUsaJob(raw, nowIso);
        if (n.ok) jobs.push(n.job); else if (n.reason !== 'expired') rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      const total = Number(str(result.SearchResultCountAll));
      const more = items.length === USAJOBS_PAGE && page < USAJOBS_MAX_PAGES && (!Number.isFinite(total) || page * USAJOBS_PAGE < total);
      return { jobs, nextCursor: more ? String(page + 1) : null, isFullSnapshot: false, rejected };
    },
  };
}
