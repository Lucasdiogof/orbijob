import { geoRestrictions, parseGeo, singleCountry } from '../geo';
import { getJson } from '../http';
import { htmlToText, inlineText } from '../text';
import type { Connector, FetchPage, JobStatus, NormalizedJob, SalaryPeriod } from '../types';

/**
 * Jobicy remote jobs API v2 (no key). Source of truth for every rule below: https://github.com/Jobicy/remote-jobs-api
 * (README, "Fair Use" and "Production Recommendations") and https://jobicy.com/api/openapi.json, read 2026-10-09.
 *
 *  - feed = jobs published in the LAST 7 DAYS only; absence from the feed does NOT mean the job is closed
 *  - cursor pagination, newest first, cursor valid 24 h, HTTP 400 on an expired/altered cursor -> start over
 *  - at most one automated sync pass per hour; pages of one pass are fetched sequentially
 *  - keep Jobicy as the source and the canonical Jobicy job URL; never present listings as our own postings
 *  - jobDescription is HTML: sanitize before use (here it is reduced to plain text)
 *  - batch status endpoint (<= 100 ids): active | closed | unknown ("unknown" is NOT proof of closure)
 */
export const JOBICY_SOURCE = {
  id: 'jobicy',
  /** Value for `job_sources`. `can_redistribute` rests on the README Fair Use text; the owner confirms it before the row is created. */
  status: 'CONDITIONAL' as const,
  attribution: 'Remote jobs via Jobicy (https://jobicy.com)',
  canRedistribute: true,
};

const BASE = 'https://jobicy.com/api/v2/remote-jobs';
const PAGE_SIZE = 100; // README: "Use 100 for smaller pages" (default and maximum are 200)
const STATUS_BATCH = 100; // README: 1-100 ids per status request

/** Jobicy listing as documented (OpenAPI schema `Job`). Everything is `unknown`: the payload is validated, not trusted. */
export type JobicyRaw = Record<string, unknown>;

export type NormalizeResult = { ok: true; job: NormalizedJob } | { ok: false; reason: string; externalId: string | null };

const PERIOD: Record<string, SalaryPeriod> = {
  hourly: 'hour', daily: 'day', weekly: 'week', monthly: 'month', yearly: 'year', annual: 'year',
};

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) && v >= 0 ? v : null);

/** Jobicy ids are positive integers; a digit string is accepted too. */
function parseId(v: unknown): string | null {
  const s = typeof v === 'number' ? (Number.isSafeInteger(v) && v > 0 ? String(v) : '') : str(v).trim();
  return /^[1-9][0-9]{0,15}$/.test(s) ? s : null;
}

/** Only https URLs on jobicy.com: the API promises the canonical Jobicy URL, anything else is rejected. */
function jobicyUrl(v: unknown): string | null {
  try {
    const u = new URL(str(v).trim());
    const host = u.hostname.toLowerCase();
    if (u.protocol !== 'https:' || u.username || u.password) return null;
    return host === 'jobicy.com' || host.endsWith('.jobicy.com') ? u.toString() : null;
  } catch {
    return null;
  }
}

function salary(r: JobicyRaw): Pick<NormalizedJob, 'salaryMin' | 'salaryMax' | 'salaryCurrency' | 'salaryPeriod'> {
  const none = { salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null };
  const min = num(r.salaryMin);
  const max = num(r.salaryMax);
  const currency = str(r.salaryCurrency).trim().toUpperCase();
  const period = PERIOD[str(r.salaryPeriod).trim().toLowerCase()];
  // A figure without currency or period would be guessed ("121000 what, per what?"), so it is not shown at all.
  if ((min === null && max === null) || !/^[A-Z]{3}$/.test(currency) || !period) return none;
  if (min !== null && max !== null && min > max) return none;
  return { salaryMin: min, salaryMax: max, salaryCurrency: currency, salaryPeriod: period };
}

export function normalizeJobicy(raw: unknown, nowIso: string): NormalizeResult {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as JobicyRaw;
  const externalId = parseId(r.id);
  if (!externalId) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(r.jobTitle));
  if (!title) return { ok: false, reason: 'missing_title', externalId };
  const url = jobicyUrl(r.url);
  if (!url) return { ok: false, reason: 'invalid_url', externalId };

  const geo = parseGeo(r.jobGeo);
  const types = Array.isArray(r.jobType) ? r.jobType.map((t) => inlineText(str(t))).filter(Boolean) : [];
  const published = Date.parse(str(r.pubDate));
  const description = htmlToText(str(r.jobDescription)) || htmlToText(str(r.jobExcerpt));

  return {
    ok: true,
    job: {
      source: JOBICY_SOURCE.id,
      externalId,
      company: inlineText(str(r.companyName)), // may be empty: the API says so; it is not invented
      title,
      description,
      country: singleCountry(geo),
      city: null, // the feed has eligibility regions, not a workplace city
      language: null, // not provided
      workMode: 'remote', // every Jobicy listing is a remote job (the endpoint is /remote-jobs)
      contractType: types.length ? types.join(', ') : null,
      ...salary(r),
      publishedAt: Number.isFinite(published) ? new Date(published).toISOString() : null,
      lastCheckedAt: nowIso,
      requirements: [],
      skills: [],
      originalUrl: url,
      applyUrl: url, // the feed's own instruction: application buttons go to the Jobicy URL given in the feed
      status: 'open',
      geoRestrictions: geoRestrictions(geo),
    },
  };
}

interface JobicyPage {
  success?: boolean;
  error?: string;
  jobs?: unknown;
  nextCursor?: unknown;
}

/** `scope` is an optional filter query string such as `geo=usa&industry=engineering` ('' = all remote jobs). */
export function jobicyConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date()): Connector {
  return {
    id: JOBICY_SOURCE.id,
    // Not a documented limit: Jobicy publishes no request quota. One request per second is this adapter's own
    // conservative pacing between the pages of a pass (the documented rule is one PASS per hour, see runSync).
    minIntervalMs: 1000,

    async fetchPage(cursor, scope): Promise<FetchPage> {
      const q = new URLSearchParams(scope);
      q.set('count', String(PAGE_SIZE));
      if (cursor) q.set('cursor', cursor);
      const data = await getJson<JobicyPage>(fetchImpl, `${BASE}?${q}`, { headers: { Accept: 'application/json' } });
      if (!data || data.success === false || !Array.isArray(data.jobs)) {
        throw new Error(`jobicy: unexpected response${data?.error ? ` (${String(data.error).slice(0, 80)})` : ''}`);
      }
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data.jobs) {
        const n = normalizeJobicy(raw, nowIso);
        if (n.ok) jobs.push(n.job);
        else rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      const next = typeof data.nextCursor === 'string' && data.nextCursor ? data.nextCursor : null;
      // The feed is a 7-day window, never a snapshot of every open job.
      return { jobs, nextCursor: next, isFullSnapshot: false, rejected };
    },

    async checkStatuses(ids): Promise<Record<string, JobStatus>> {
      const out: Record<string, JobStatus> = {};
      const valid = ids.filter((id) => /^[1-9][0-9]{0,15}$/.test(id));
      for (let i = 0; i < valid.length; i += STATUS_BATCH) {
        const batch = valid.slice(i, i + STATUS_BATCH);
        const data = await getJson<{ success?: boolean; jobs?: { id?: unknown; status?: unknown }[] }>(
          fetchImpl,
          `${BASE}/status?ids=${batch.join(',')}`,
          { headers: { Accept: 'application/json' } },
        );
        if (!data || data.success === false || !Array.isArray(data.jobs)) throw new Error('jobicy: unexpected status response');
        for (const j of data.jobs) {
          const id = parseId(j.id);
          if (!id || !batch.includes(id)) continue; // ignore ids we did not ask about
          // active -> open, closed -> closed; "unknown" (and anything unrecognised) stays unknown, never closed.
          out[id] = j.status === 'active' ? 'open' : j.status === 'closed' ? 'closed' : 'unknown';
        }
      }
      return out;
    },
  };
}
