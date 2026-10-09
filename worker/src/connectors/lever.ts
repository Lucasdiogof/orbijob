import { getJson } from '../http';
import type { Connector, FetchPage, NormalizedJob, SalaryPeriod, WorkMode } from '../types';

/** Subset of the documented Lever Postings API response (github.com/lever/postings-api). */
export interface LeverPosting {
  id: string;
  text: string;
  hostedUrl: string;
  applyUrl: string;
  createdAt?: number;
  country?: string;
  workplaceType?: 'unspecified' | 'on-site' | 'remote' | 'hybrid';
  descriptionPlain?: string;
  categories?: { commitment?: string; location?: string; team?: string; department?: string };
  salaryRange?: { currency: string; interval: string; min: number; max: number };
  lists?: { text: string; content: string }[];
}

const MODE: Record<string, WorkMode> = { remote: 'remote', hybrid: 'hybrid', 'on-site': 'onsite' };
const PERIOD: Record<string, SalaryPeriod> = {
  'per-hour': 'hour', 'per-day': 'day', 'per-week': 'week',
  'per-month': 'month', 'per-year': 'year', 'per-year-salary': 'year',
};

export function normalizeLever(site: string, p: LeverPosting, nowIso: string): NormalizedJob {
  const r = p.salaryRange;
  return {
    source: 'lever',
    externalId: p.id,
    company: site,
    title: p.text,
    description: p.descriptionPlain ?? '',
    country: p.country ?? null,
    city: p.categories?.location ?? null,
    language: null,
    workMode: MODE[p.workplaceType ?? ''] ?? 'unspecified',
    contractType: p.categories?.commitment ?? null,
    salaryMin: r?.min ?? null,
    salaryMax: r?.max ?? null,
    salaryCurrency: r?.currency ?? null,
    salaryPeriod: r ? PERIOD[r.interval] ?? null : null,
    publishedAt: p.createdAt ? new Date(p.createdAt).toISOString() : null,
    lastCheckedAt: nowIso,
    requirements: (p.lists ?? []).map((l) => l.text),
    skills: [],
    originalUrl: p.hostedUrl,
    applyUrl: p.applyUrl,
    status: 'open',
    geoRestrictions: [],
  };
}

/** Lever per-company-site connector. `scope` = Lever site slug. Read endpoint is public (no key). */
export function leverConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date()): Connector {
  const PAGE = 100;
  return {
    id: 'lever',
    minIntervalMs: 500,
    async fetchPage(cursor, site): Promise<FetchPage> {
      const skip = cursor ? Number(cursor) : 0;
      const data = await getJson<LeverPosting[]>(
        fetchImpl,
        `https://api.lever.co/v0/postings/${encodeURIComponent(site)}?mode=json&skip=${skip}&limit=${PAGE}`,
      );
      const full = data.length < PAGE; // short page => end of board
      return {
        jobs: data.map((p) => normalizeLever(site, p, now().toISOString())),
        nextCursor: full ? null : String(skip + PAGE),
        // Only meaningful on the LAST page of a complete walk; the sync job must have
        // consumed every earlier page before acting on it (see shouldMarkClosed).
        isFullSnapshot: full,
      };
    },
  };
}
