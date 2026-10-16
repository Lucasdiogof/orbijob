// Pure classification of ONE discovery pass into the state the workflow and the monitor report (13.0). No I/O, unit-tested.
//
//   SUCCESS      the pass read the feed and imported normally (or stood down by the lease: nothing to do this hour)
//   AT_CAPACITY  a HEALTHY pass that stopped importing only because the source reached its intended catalogue ceiling (worker/src/sources.ts):
//                the feed was read (rows came back), no HTTP error, no other error class, the before/after verification passed. Planned, not a fault:
//                the workflow ends green with a notice. The ceiling still holds (nothing beyond it is stored); revalidation and expiry keep running in
//                their own jobs, and once listings expire the next pass imports again (SUCCESS).
//   PARTIAL      the pass ran but some of it failed (feed/API errors, the time budget, a page limit that is not the reading window)
//   FAILED       a real failure: refused credential, unreachable database, failed pass, verification that did not pass, or a "full" pass that read
//                NOTHING from the feed (a broken feed must never hide behind a full catalogue)
//
// Exit codes keep their meaning for the existing alert steps: 0 SUCCESS and AT_CAPACITY; 6 PARTIAL; 1 FAILED; 4 credential; 5 unreachable.
// Code 7 (the old "ceiling reached" alert) is no longer produced.

/**
 * @param {{ outcome?: { status: string, summary?: { error_class?: string|null, fetched?: number, http_errors?: number } } | null, crash?: string|null, problems?: string[] }} p
 * @returns {{ state: 'SUCCESS'|'AT_CAPACITY'|'PARTIAL'|'FAILED', code: number, reason: string }}
 */
export function classifyDiscoverRun({ outcome = null, crash = null, problems = [] }) {
  if (problems.length) return { state: 'FAILED', code: 1, reason: 'verification' };
  if (crash === 'auth') return { state: 'FAILED', code: 4, reason: 'auth' };
  if (crash === 'unreachable') return { state: 'FAILED', code: 5, reason: 'unreachable' };
  if (!outcome || outcome.status === 'failed') return { state: 'FAILED', code: 1, reason: crash ?? outcome?.summary?.error_class ?? 'failed' };
  if (outcome.status === 'skipped') return { state: 'SUCCESS', code: 0, reason: 'skipped' };
  const s = outcome.summary ?? {};
  if (outcome.status === 'partial' && s.error_class === 'catalogue_full') {
    if (!((s.fetched ?? 0) > 0)) return { state: 'FAILED', code: 1, reason: 'catalogue_full_without_feed_rows' };
    if ((s.http_errors ?? 0) > 0) return { state: 'PARTIAL', code: 6, reason: 'catalogue_full_with_http_errors' };
    return { state: 'AT_CAPACITY', code: 0, reason: 'catalogue_full' };
  }
  if (outcome.status === 'partial') return { state: 'PARTIAL', code: 6, reason: s.error_class ?? 'partial' };
  return { state: 'SUCCESS', code: 0, reason: 'ok' };
}
