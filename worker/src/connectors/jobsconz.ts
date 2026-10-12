import { cleanDescription } from '../description';
import { HttpError, parseRetryAfter } from '../http';
import { inlineText } from '../text';
import type { Connector, FetchPage, JobStatus, NormalizedJob, SalaryPeriod, WorkMode } from '../types';
import { getFeed, ownUrl, type Normalized } from './feeds';

/**
 * Jobs.co.nz, a New Zealand job board with a public read API:
 *
 *   https://jobs.co.nz/api/v1/jobs            live listings, no key, 120 requests a minute per IP (X-RateLimit-* headers, 429 + Retry-After)
 *   https://jobs.co.nz/api/v1/jobs/{id}       one live listing; 404 "No live listing with that id." once it is gone
 *
 * Terms (jobs.co.nz/terms, section 8) forbid scraping the site but point automated collection to this API; section 4 says expired listings are taken
 * down, so every stored listing is re-verified by id (`checkStatuses`) and the listing's own `expires_at` is honoured. The terms say nothing about storage
 * or attribution; the catalogue names the source and links every listing back to its page. All professions, all of New Zealand (Oceania).
 * Nothing is translated or guessed: the country is New Zealand because the site is the New Zealand board; a salary is shown only with its stated period.
 */

export const JOBSCONZ_HOST = 'jobs.co.nz';
const PAGE = 100;
const MAX_DESCRIPTION = 6000;
const STATUS_WORKERS = 2;
const STATUS_PAUSE_MS = 700; // two workers, ~0.7 s each: about 170 requests a minute is too many, so the pause keeps it near 100/min

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const obj = (v: unknown): Record<string, unknown> => (typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : {});
const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) && v >= 0 ? v : null);

/** The API writes timestamps without an offset ("2026-10-09T16:08:26"); they are read as UTC. */
function utcIso(v: unknown): string | null {
  const s = str(v);
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(s)) return null;
  const t = Date.parse(/(Z|[+-]\d{2}:?\d{2})$/.test(s) ? s : `${s}Z`);
  return Number.isFinite(t) ? new Date(t).toISOString() : null;
}

const MODE: Record<string, WorkMode> = { onsite: 'onsite', hybrid: 'hybrid', remote: 'remote' };
const PERIOD: Record<string, SalaryPeriod> = { year: 'year', hour: 'hour' };

export function normalizeJobsCoNz(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = typeof r.id === 'number' ? String(r.id) : str(r.id).trim();
  if (!/^[1-9][0-9]{0,15}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(r.title));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const company = inlineText(str(r.company));
  if (!company) return { ok: false, reason: 'missing_company', externalId: id };
  const url = ownUrl(r.url, JOBSCONZ_HOST);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const expires = utcIso(r.expires_at);
  if (expires !== null && Date.parse(expires) < Date.parse(nowIso)) return { ok: false, reason: 'expired', externalId: id };

  let description = cleanDescription(str(r.description));
  if (description.length > MAX_DESCRIPTION) description = `${description.slice(0, MAX_DESCRIPTION).trimEnd()}…`;
  const sal = obj(r.salary);
  const period = PERIOD[str(sal.period)] ?? null;
  const lo = num(sal.min);
  const hi = num(sal.max);
  const currency = /^[A-Z]{3}$/.test(str(sal.currency)) ? str(sal.currency) : null;
  const salaryOk = period !== null && currency !== null && lo !== null && lo > 0 && (hi === null || hi >= lo);
  const town = inlineText(str(r.town));
  const region = inlineText(str(r.region));
  const type = inlineText(str(r.employment_type));
  return {
    ok: true,
    job: {
      source: 'jobsconz', lastCheckedAt: nowIso, requirements: [], skills: [], language: null, status: 'open',
      externalId: id, company, title, description,
      country: 'NZ', city: town || region || null,
      workMode: MODE[str(r.work_mode)] ?? 'unspecified', contractType: type || null,
      salaryMin: salaryOk ? lo : null, salaryMax: salaryOk ? (hi ?? lo) : null, salaryCurrency: salaryOk ? currency : null, salaryPeriod: salaryOk ? period : null,
      publishedAt: utcIso(r.published_at), originalUrl: url, applyUrl: url,
      geoRestrictions: [],
    } satisfies NormalizedJob,
  };
}

/** What `/api/v1/jobs/{id}` says about one stored listing. 404/410: gone. 200: open unless its own `expires_at` passed. 429/5xx are thrown. Anything else: unknown. */
export function listingStatus(status: number, body: unknown, nowMs: number): JobStatus {
  if (status === 404 || status === 410) return 'closed';
  if (status !== 200) return 'unknown';
  const d = obj(obj(body).data);
  if (!(typeof d.id === 'number' || typeof d.id === 'string')) return 'unknown';
  const exp = utcIso(d.expires_at);
  if (exp !== null && Date.parse(exp) < nowMs) return 'closed';
  return 'open';
}

export function jobsCoNzConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string; statusPauseMs?: number } = {}): Connector {
  const ORIGIN = (opts.origin ?? 'https://jobs.co.nz').replace(/\/+$/, '');
  const UA = 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)';
  return {
    id: 'jobsconz',
    minIntervalMs: 2000,
    presenceConfirmsOpen: true,
    async checkStatuses(externalIds: string[]): Promise<Record<string, JobStatus>> {
      const out: Record<string, JobStatus> = {};
      const queue = externalIds.filter((id) => /^[1-9][0-9]{0,15}$/.test(id));
      const worker = async () => {
        for (let id = queue.shift(); id !== undefined; id = queue.shift()) {
          const res = await fetchImpl(`${ORIGIN}/api/v1/jobs/${id}`, { headers: { Accept: 'application/json', 'User-Agent': UA }, signal: AbortSignal.timeout(20_000) });
          if (res.status === 429 || res.status >= 500) throw new HttpError(res.status, parseRetryAfter(res.headers.get('retry-after')));
          let body: unknown = null;
          if (res.status === 200) {
            try { body = JSON.parse(await res.text()); } catch { body = null; }
          } else {
            await res.arrayBuffer().catch(() => {});
          }
          out[id] = listingStatus(res.status, body, now().getTime());
          const pause = opts.statusPauseMs ?? STATUS_PAUSE_MS;
          if (pause > 0) await new Promise((r) => setTimeout(r, pause));
        }
      };
      await Promise.all(Array.from({ length: Math.min(STATUS_WORKERS, queue.length) }, worker));
      return out;
    },
    async fetchPage(cursor): Promise<FetchPage> {
      const offset = cursor ? Number(cursor) : 0;
      if (!Number.isInteger(offset) || offset < 0 || offset % PAGE !== 0 || offset > 100 * PAGE) throw new Error('jobsconz: invalid cursor');
      const data = await getFeed<{ data?: unknown; pagination?: { has_more?: unknown; total?: unknown } }>(fetchImpl, `${ORIGIN}/api/v1/jobs?limit=${PAGE}&offset=${offset}`);
      if (!Array.isArray(data.data)) throw new Error('jobsconz: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data.data) {
        const n = normalizeJobsCoNz(raw, nowIso);
        if (n.ok) jobs.push(n.job); else if (n.reason !== 'expired') rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      const more = data.pagination?.has_more === true && data.data.length === PAGE;
      return { jobs, nextCursor: more ? String(offset + PAGE) : null, isFullSnapshot: false, rejected };
    },
  };
}
