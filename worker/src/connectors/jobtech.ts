import { cleanDescription } from '../description';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob, WorkMode } from '../types';
import { HttpError, parseRetryAfter } from '../http';
import type { JobStatus } from '../types';
import { getFeed, ownUrl, type Normalized } from './feeds';

/**
 * Arbetsförmedlingen (the Swedish Public Employment Service) through JobTech Dev's open JobSearch API:
 *
 *   https://jobsearch.api.jobtechdev.se/search    no key, no account; the API description states "Ads are licensed under CC0"
 *                                                (public-domain dedication), so the ads may be stored and shown. We still credit and link the
 *                                                Platsbanken page of every ad. All professions, all of Sweden.
 *
 * The search is capped at 2 100 hits (offset <= 2 000, 100 per page) and sorts by publication date, so one pass reads:
 *   1. PRIORITY streams first, each a small, exact slice the owner cares about: physiotherapists (the taxonomy's occupation group, not a
 *      text match), and mobile-development ads (text query, kept only when the TITLE itself names the technology);
 *   2. then the newest ads of every profession.
 * An ad that is listed is open (`presenceConfirmsOpen`). The search only reaches the newest ads, so STORED ads are re-verified one by one
 * through `/ad/{id}` (`checkStatuses`, revalidate mode): 200 = still published, 404 = gone. `ops.expire_unseen_jobs` stays as the backstop. Nothing is translated, guessed or filled in: language, salary and eligibility stay empty when the ad does not state them.
 */

export const JOBTECH_HOST = 'arbetsformedlingen.se';
const PAGE = 100;
const MAX_OFFSET = 2000;
const MAX_DESCRIPTION = 6000;
/** Status checks: `/ad/{id}` answers one ad per request (~10 KB, ~0.3 s). Four workers with a pause each stay near 7 requests a second. */
const STATUS_WORKERS = 4;
const STATUS_PAUSE_MS = 150;
/** An ad whose own `last_publication_date` ended more than this long ago is no longer published, even if the endpoint still answers. */
const PUBLICATION_GRACE_MS = 36 * 3_600_000;

/** Taxonomy concept id of "Fysioterapeuter och sjukgymnaster" (SSYK 2264) in JobTech's taxonomy. */
export const PHYSIO_GROUP = 's7vU_FhY_L5Z';
const MOBILE_TITLE = /\b(flutter|dart|android|ios|swift(ui)?|kotlin|react[ -]native|mobil(e|app|apps|utvecklare|utveckling)?|app[- ]?utvecklare)\b/i;

export interface JobtechStream {
  id: string;
  /** Query-string parameters of the search. */
  params: Record<string, string>;
  /** Pages of 100 this stream may read. */
  pages: number;
  /** Keep only ads whose title matches (a text query alone also finds ads that merely mention the word). */
  titleMust?: RegExp;
}

export const JOBTECH_STREAMS: readonly JobtechStream[] = [
  { id: 'physio', params: { 'occupation-group': PHYSIO_GROUP }, pages: 4 },
  ...['flutter', 'mobilutvecklare', 'mobile developer', 'android', 'ios', 'kotlin', 'swift', 'react native'].map(
    (q): JobtechStream => ({ id: `mobile:${q}`, params: { q }, pages: 1, titleMust: MOBILE_TITLE }),
  ),
  { id: 'new', params: {}, pages: 12 },
];

/** Total pages of one full pass over every stream (the `maxPages` of the source profile). */
export const JOBTECH_PASS_PAGES = JOBTECH_STREAMS.reduce((n, s) => n + s.pages, 0);

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const obj = (v: unknown): Record<string, unknown> => (typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : {});
const label = (v: unknown): string => inlineText(str(obj(v).label));

function lastSunday(year: number, month: number): number {
  const d = new Date(Date.UTC(year, month + 1, 0));
  return Date.UTC(year, month, d.getUTCDate() - d.getUTCDay(), 1); // 01:00 UTC on the last Sunday
}

/** Platsbanken writes publication times in Swedish local time without an offset: convert with the EU summer-time rule (CET +1, CEST +2). */
export function stockholmToIso(local: unknown): string | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/.exec(str(local));
  if (!m) return null;
  const wall = Date.UTC(+m[1]!, +m[2]! - 1, +m[3]!, +m[4]!, +m[5]!, +m[6]!);
  if (!Number.isFinite(wall)) return null;
  const summer = wall - 2 * 3_600_000 >= lastSunday(+m[1]!, 2) && wall - 2 * 3_600_000 < lastSunday(+m[1]!, 9);
  return new Date(wall - (summer ? 2 : 1) * 3_600_000).toISOString();
}

function workModeOf(raw: unknown): WorkMode {
  const l = label(raw).toLowerCase();
  if (/distans/.test(l)) return 'remote';
  if (/hybrid/.test(l)) return 'hybrid';
  if (/p[åa] plats/.test(l)) return 'onsite';
  return 'unspecified';
}

export function normalizeJobtech(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = typeof r.id === 'number' ? String(r.id) : str(r.id).trim();
  if (!/^[1-9][0-9]{0,15}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  if (r.removed === true) return { ok: false, reason: 'removed', externalId: id };
  const title = inlineText(str(r.headline));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const employer = obj(r.employer);
  const company = inlineText(str(employer.name)) || inlineText(str(employer.workplace));
  if (!company) return { ok: false, reason: 'missing_company', externalId: id };
  const url = ownUrl(r.webpage_url, JOBTECH_HOST);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const desc = obj(r.description);
  let description = cleanDescription(str(desc.text) || str(desc.text_formatted));
  if (description.length > MAX_DESCRIPTION) description = `${description.slice(0, MAX_DESCRIPTION).trimEnd()}…`;
  const addr = obj(r.workplace_address);
  // Only the country the ad itself names in Swedish is mapped; anything else stays unknown (the numeric country_code is AMS's own, not ISO).
  const country = str(addr.country).trim().toLowerCase() === 'sverige' ? 'SE' : null;
  const city = inlineText(str(addr.municipality)) || inlineText(str(addr.city)) || null;
  const contract = [label(r.employment_type), label(r.working_hours_type)].filter(Boolean);
  const skills = (Array.isArray(obj(r.must_have).skills) ? (obj(r.must_have).skills as unknown[]) : []).map(label).filter(Boolean).slice(0, 12);
  return {
    ok: true,
    job: {
      source: 'jobtech', lastCheckedAt: nowIso, requirements: [], skills, language: null, status: 'open',
      externalId: id, company, title, description, country, city,
      workMode: workModeOf(r.workplace_model), contractType: contract.length ? contract.join(', ') : null,
      salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null, // `salary_type` is a category ("fixed monthly pay"), not an amount
      publishedAt: stockholmToIso(r.publication_date),
      originalUrl: url, applyUrl: url, // the application link may point anywhere; the catalogue keeps only the source's own page
      geoRestrictions: [], // an on-site Swedish ad names no eligible region: eligibility is unknown, never read as global
    } satisfies NormalizedJob,
  };
}

/** Cursor = "<stream index>:<offset>". */
function parseCursor(cursor: string | null): { stream: number; offset: number } {
  if (cursor === null) return { stream: 0, offset: 0 };
  const m = /^(\d{1,2}):(\d{1,4})$/.exec(cursor);
  const stream = m ? Number(m[1]) : -1;
  const offset = m ? Number(m[2]) : -1;
  if (!m || stream >= JOBTECH_STREAMS.length || offset > MAX_OFFSET || offset % PAGE !== 0) throw new Error('jobtech: invalid cursor');
  return { stream, offset };
}

/**
 * What `/ad/{id}` says about one stored ad. Only evidence from the source counts:
 *   404/410                                  -> closed (the ad is not published any more);
 *   200 with removed=true                    -> closed;
 *   200 whose last_publication_date ended > 36 h ago -> closed (the platform stopped publishing it);
 *   200 otherwise                            -> open;
 *   anything else (403, an unreadable answer) -> unknown, left exactly as it is.
 * 429 and 5xx are THROWN so the retry layer backs off (and honours Retry-After); they are never read as "open" or "closed".
 */
export function adStatus(status: number, body: unknown, nowMs: number): JobStatus {
  if (status === 404 || status === 410) return 'closed';
  if (status !== 200) return 'unknown';
  const ad = obj(body);
  if (ad.removed === true) return 'closed';
  const end = Date.parse(str(ad.last_publication_date));
  if (Number.isFinite(end) && nowMs - end > PUBLICATION_GRACE_MS) return 'closed';
  return typeof ad.id === 'string' || typeof ad.id === 'number' ? 'open' : 'unknown';
}

export function jobtechConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string; statusPauseMs?: number } = {}): Connector {
  const ORIGIN = (opts.origin ?? 'https://jobsearch.api.jobtechdev.se').replace(/\/+$/, '');
  const BASE = `${ORIGIN}/search`;
  return {
    id: 'jobtech',
    minIntervalMs: 1000, // no documented limit: one request a second is this adapter's own polite pace
    presenceConfirmsOpen: true,
    async checkStatuses(externalIds: string[]): Promise<Record<string, JobStatus>> {
      const out: Record<string, JobStatus> = {};
      const queue = externalIds.filter((id) => /^[1-9][0-9]{0,15}$/.test(id));
      const worker = async () => {
        for (let id = queue.shift(); id !== undefined; id = queue.shift()) {
          const res = await fetchImpl(`${ORIGIN}/ad/${id}`, { headers: { Accept: 'application/json', 'User-Agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)' }, signal: AbortSignal.timeout(20_000) });
          if (res.status === 429 || res.status >= 500) throw new HttpError(res.status, parseRetryAfter(res.headers.get('retry-after')));
          let body: unknown = null;
          if (res.status === 200) {
            try { body = JSON.parse(await res.text()); } catch { body = null; }
          } else {
            await res.arrayBuffer().catch(() => {});
          }
          out[id] = adStatus(res.status, body, now().getTime());
          const pause = opts.statusPauseMs ?? STATUS_PAUSE_MS;
          if (pause > 0) await new Promise((r) => setTimeout(r, pause));
        }
      };
      await Promise.all(Array.from({ length: Math.min(STATUS_WORKERS, queue.length) }, worker));
      return out;
    },
    async fetchPage(cursor): Promise<FetchPage> {
      const { stream: si, offset } = parseCursor(cursor);
      const stream = JOBTECH_STREAMS[si]!;
      const qs = new URLSearchParams({ ...stream.params, limit: String(PAGE), offset: String(offset), sort: 'pubdate-desc' });
      const data = await getFeed<{ total?: { value?: unknown }; hits?: unknown }>(fetchImpl, `${BASE}?${qs}`);
      if (!Array.isArray(data.hits)) throw new Error('jobtech: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data.hits) {
        const n = normalizeJobtech(raw, nowIso);
        if (!n.ok) rejected.push({ externalId: n.externalId, reason: n.reason });
        else if (stream.titleMust && !stream.titleMust.test(n.job.title)) continue; // a mention in the text is not a job of that kind
        else jobs.push(n.job);
      }
      const total = typeof data.total?.value === 'number' ? data.total.value : 0;
      const nextOffset = offset + PAGE;
      const more = data.hits.length === PAGE && nextOffset < total && nextOffset <= MAX_OFFSET && nextOffset < stream.pages * PAGE;
      const nextCursor = more ? `${si}:${nextOffset}` : si + 1 < JOBTECH_STREAMS.length ? `${si + 1}:0` : null;
      return { jobs, nextCursor, isFullSnapshot: false, rejected };
    },
  };
}
