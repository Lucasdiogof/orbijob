/** Normalized job posting. Every connector maps its source format to this shape. */
export type WorkMode = 'remote' | 'hybrid' | 'onsite' | 'unspecified';
export type JobStatus = 'open' | 'closed' | 'unknown';
export type SalaryPeriod = 'hour' | 'day' | 'week' | 'month' | 'year';

export interface NormalizedJob {
  source: string; // connector id, e.g. "lever"
  externalId: string;
  company: string;
  title: string;
  description: string;
  country: string | null; // ISO 3166-1 alpha-2
  city: string | null;
  language: string | null; // BCP-47, null when unknown
  workMode: WorkMode;
  contractType: string | null;
  salaryMin: number | null;
  salaryMax: number | null;
  salaryCurrency: string | null; // ISO 4217
  salaryPeriod: SalaryPeriod | null;
  publishedAt: string | null; // ISO 8601
  lastCheckedAt: string; // ISO 8601
  requirements: string[];
  skills: string[];
  originalUrl: string;
  applyUrl: string | null;
  status: JobStatus;
  geoRestrictions: string[]; // ISO alpha-2 codes or free text region names
}

export interface FetchPage {
  jobs: NormalizedJob[];
  nextCursor: string | null;
  /** True only if the source lists ALL open jobs in this scan (full snapshot). */
  isFullSnapshot: boolean;
  /** Records the connector refused to normalize (invalid URL, missing id/title). Reasons only, never content. */
  rejected?: { externalId: string | null; reason: string }[];
}

export interface Connector {
  readonly id: string;
  /** Minimum ms between requests, derived from the source's documented limits. */
  readonly minIntervalMs: number;
  fetchPage(cursor: string | null, scope: string): Promise<FetchPage>;
  /**
   * For sources whose feed is a recent-jobs window (absence means nothing): asks the source whether stored jobs are
   * still open. Returns only the ids the source answered for; 'unknown' must never be treated as closed.
   */
  checkStatuses?(externalIds: string[]): Promise<Record<string, JobStatus>>;
}
