import { HttpError, parseRetryAfter } from '../http';
import type { Connector, FetchPage, NormalizedJob } from '../types';
import type { Normalized } from './feeds';

/**
 * The shell shared by the sources that publish their WHOLE current list of offers in one file (the regional employment services of Spain: Murcia, Catalonia,
 * Castilla y León, the Basque Country). It exists because four connectors, written one after the other from real feeds, turned out to differ only in how the body is
 * turned into records and how one record is turned into a job; everything else was identical and is kept here once:
 *
 * * one GET with the project's User-Agent and a time limit; an HTTP error surfaces with its Retry-After (the retry layer decides), a non-feed body is a non-retryable
 *   403 (a challenge page must not be hammered);
 * * the records go through `normalize`; a refusal is reported by REASON only, except the reasons in `quiet` (an expired or too-old offer is not a defect);
 * * `presenceConfirmsOpen`: the file lists only open offers, so being in it stamps a stored offer and leaving it only stops the stamping (never closes anything);
 * * no cursor: one request is the whole pass.
 */
export interface SnapshotOptions {
  id: string;
  fetchImpl: typeof fetch;
  now: () => Date;
  url: string;
  accept: string;
  timeoutMs: number;
  /** The records of the response; throws `HttpError(403)` for a body that is not the expected feed. */
  records(res: Response): Promise<unknown[]>;
  normalize(raw: unknown, nowIso: string): Normalized;
  /** Refusal reasons that are normal and not reported ("expired", "stale"). */
  quiet?: string[];
  /** A feed that answers with no record at all is an error (a broken export), not an empty catalogue. */
  emptyIsError?: boolean;
}

const USER_AGENT = 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)';

export function snapshotConnector(o: SnapshotOptions): Connector {
  const quiet = new Set(o.quiet ?? ['expired', 'stale']);
  return {
    id: o.id,
    minIntervalMs: 1500,
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      if (cursor) throw new Error(`${o.id}: invalid cursor`);
      const res = await o.fetchImpl(o.url, { headers: { Accept: o.accept, 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(o.timeoutMs) });
      if (!res.ok) throw new HttpError(res.status, parseRetryAfter(res.headers.get('retry-after')));
      const records = await o.records(res);
      if (!Array.isArray(records)) throw new Error(`${o.id}: unexpected response`);
      const nowIso = o.now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of records) {
        const n = o.normalize(raw, nowIso);
        if (n.ok) jobs.push(n.job); else if (!quiet.has(n.reason)) rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      if (o.emptyIsError && jobs.length === 0 && rejected.length === 0) throw new Error(`${o.id}: the feed holds no offers`);
      return { jobs, nextCursor: null, isFullSnapshot: false, rejected };
    },
  };
}

/** The body as a JSON array; anything that is not JSON is a non-retryable 403. */
export async function jsonRecords(res: Response, decode: (bytes: ArrayBuffer) => string = (b) => new TextDecoder('utf-8').decode(b)): Promise<unknown[]> {
  let data: unknown;
  try {
    data = JSON.parse(decode(await res.arrayBuffer()));
  } catch {
    throw new HttpError(403);
  }
  return data as unknown[];
}
