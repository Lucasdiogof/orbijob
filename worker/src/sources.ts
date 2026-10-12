import { ARBEITNOW_HOSTS, arbeitnowConnector, remoteOkConnector, remotiveConnector } from './connectors/feeds';
import { jobicyConnector } from './connectors/jobicy';
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
    maxPages: 5, pageWindow: true, newCap: 300, catalogue: 1500,
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
};

export const SOURCE_IDS = Object.keys(SOURCES);
