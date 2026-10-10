/**
 * How recently the SOURCE itself vouched for a stored job (`jobs.last_checked_at`: moved by every feed upsert and by every
 * "still active" answer of the status endpoint; never by a failed or inconclusive check).
 *
 *   fresh    vouched for within FRESH_MS: shown as open.
 *   aging    older, but within EXPIRE_MS: still shown (a pass or two may have failed), flagged in reports.
 *   expired  older than EXPIRE_MS: nobody can guarantee it is still open, so the app must NOT present it as an opportunity.
 *
 * The app applies the same EXPIRE_MS in its catalogue query (app/lib/features/search/data/supabase_job_catalog_repository.dart,
 * `maxVerificationAge`). A job is never deleted or closed just for being expired: it comes back as soon as a check confirms it.
 * With the cron every 6 hours, 12 h of fresh margin covers one missed pass and 72 h covers a long weekend of failures.
 */
export const FRESH_MS = 12 * 3600_000;
export const EXPIRE_MS = 72 * 3600_000;

export type Verification = 'fresh' | 'aging' | 'expired' | 'unverified';

/** `unverified`: the job has no check date at all (or an unreadable one, or one in the future of this clock). */
export function verificationState(lastCheckedAt: string | null | undefined, now: Date): Verification {
  const t = lastCheckedAt ? Date.parse(lastCheckedAt) : NaN;
  if (!Number.isFinite(t)) return 'unverified';
  const age = now.getTime() - t;
  if (age < 0) return 'fresh'; // a clock a little ahead of ours: the check happened, treat it as just done
  if (age <= FRESH_MS) return 'fresh';
  return age <= EXPIRE_MS ? 'aging' : 'expired';
}
