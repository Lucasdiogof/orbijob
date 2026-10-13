import { ARBEITNOW_HOSTS, arbeitnowConnector, remoteOkConnector, remotiveConnector } from './connectors/feeds';
import { getOnBoardConnector } from './connectors/getonboard';
import { jobicyConnector } from './connectors/jobicy';
import { jobsCoNzConnector } from './connectors/jobsconz';
import { teachingVacanciesConnector, TEACHINGVACANCIES_MAX_PAGES } from './connectors/teachingvacancies';
import { taiwanJobsConnector } from './connectors/taiwanjobs';
import { JOBTECH_PASS_PAGES, jobtechConnector } from './connectors/jobtech';
import type { Connector } from './types';

/**
 * The sources the catalogue reads. One entry per `job_sources.id`; the connector, the source row (attribution text, review status)
 * and the safe defaults of a pass live together, so nothing about a source is scattered across scripts.
 *
 * A source row is born CONDITIONAL and NOT redistributable, and is published only by scripts/supabase/ops/publish_source.sql after its
 * stored records were reviewed. `docs/SOURCES_MATRIX.md` holds the evidence (terms, limits, attribution) behind every entry.
 */
export interface SourceProfile {
  id: string;
  /** `job_sources.attribution`: shown with every job of the source. Must name the source and link to it (their terms ask for a link back). */
  attribution: string;
  /** Main host of the source. */
  host: string;
  /** Every host a stored `original_url` may be on (defaults to `host`). */
  hosts?: readonly string[];
  /** Feed pages a `discover` pass may read. */
  maxPages: number;
  /** `maxPages` is the intended reading window of a newest-first feed: reaching it is a normal end (see `SyncOptions.pageWindow`). */
  pageWindow?: boolean;
  /** New jobs one pass may add. */
  newCap: number;
  /** Ceiling on FULL jobs of this source (open, or still carrying a description). */
  catalogue: number;
  make(fetchImpl: typeof fetch, now: () => Date, origin?: string): Connector;
}

export const SOURCES: Record<string, SourceProfile> = {
  jobicy: {
    id: 'jobicy', attribution: 'Remote jobs via Jobicy (https://jobicy.com)', host: 'jobicy.com',
    maxPages: 40, newCap: 200, catalogue: 4000,
    make: (f, n, origin) => jobicyConnector(f, n, { origin }),
  },
  arbeitnow: {
    id: 'arbeitnow', attribution: 'Jobs via Arbeitnow (https://www.arbeitnow.com)', host: 'arbeitnow.com', hosts: ARBEITNOW_HOSTS,
    maxPages: 8, pageWindow: true, newCap: 300, catalogue: 2500,
    make: (f, n, origin) => arbeitnowConnector(f, n, { origin }),
  },
  remoteok: {
    id: 'remoteok', attribution: 'Remote jobs via Remote OK (https://remoteok.com)', host: 'remoteok.com',
    maxPages: 1, newCap: 150, catalogue: 300,
    make: (f, n, origin) => remoteOkConnector(f, n, { origin }),
  },
  remotive: {
    id: 'remotive', attribution: 'Remote jobs via Remotive (https://remotive.com)', host: 'remotive.com',
    maxPages: 1, newCap: 100, catalogue: 200,
    make: (f, n, origin) => remotiveConnector(f, n, { origin }),
  },
  jobtech: {
    id: 'jobtech', attribution: 'Jobs via Arbetsförmedlingen / Platsbanken (https://arbetsformedlingen.se), open data CC0 from JobTech Dev', host: 'arbetsformedlingen.se',
    maxPages: JOBTECH_PASS_PAGES, pageWindow: true, newCap: 600, catalogue: 3500,
    make: (f, n, origin) => jobtechConnector(f, n, { origin }),
  },
  twjobs: {
    id: 'twjobs',
    attribution: 'Jobs via Taiwan Jobs (臺灣就業通), Workforce Development Agency, Ministry of Labor, Taiwan (https://job.taiwanjobs.gov.tw), Open Government Data License v1.0 (https://data.gov.tw/en/datasets/44062)',
    host: 'taiwanjobs.gov.tw',
    maxPages: 3, newCap: 1000, catalogue: 1500,
    make: (f, n, origin) => taiwanJobsConnector(f, n, { origin }),
  },
  jobsconz: {
    id: 'jobsconz', attribution: 'Jobs via Jobs.co.nz (https://jobs.co.nz), New Zealand', host: 'jobs.co.nz',
    maxPages: 6, newCap: 400, catalogue: 800,
    make: (f, n, origin) => jobsCoNzConnector(f, n, { origin }),
  },
  getonboard: {
    id: 'getonboard', attribution: 'Jobs via Get on Board (https://www.getonbrd.com), tech jobs in Latin America', host: 'getonbrd.com',
    maxPages: 40, newCap: 600, catalogue: 1500,
    make: (f, n, origin) => getOnBoardConnector(f, n, { origin }),
  },
  teachingvacancies: {
    id: 'teachingvacancies',
    attribution: 'Jobs via Teaching Vacancies, Department for Education (England) (https://teaching-vacancies.service.gov.uk), Open Government Licence v3.0 (https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)',
    host: 'teaching-vacancies.service.gov.uk',
    maxPages: TEACHINGVACANCIES_MAX_PAGES, newCap: 700, catalogue: 2000,
    make: (f, n, origin) => teachingVacanciesConnector(f, n, { origin }),
  },
};

export const SOURCE_IDS = Object.keys(SOURCES);
