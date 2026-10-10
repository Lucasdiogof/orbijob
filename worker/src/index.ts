import type { Env, ExecutionContext, ScheduledController } from './env';
import { consoleSink } from './log';
import { runScheduledSync } from './scheduled';

/**
 * Cloudflare Worker entry point: Jobicy catalogue sync, driven only by the Cron Trigger in wrangler.toml.
 *
 * - `scheduled` is the only way in. It is awaited (not detached with waitUntil) so a failure is attributed to the
 *   invocation and shows as an error in the dashboard; waitUntil would only hide it.
 * - `fetch` answers 404 to everything. The Worker has no public route (wrangler.toml turns off workers.dev), and there is
 *   deliberately no administrative HTTP endpoint: a manual run is done by Cloudflare's own dev tooling locally, or by
 *   temporarily changing the cron (docs/FIRST_INGESTION_RUNBOOK.md).
 */
export default {
  async scheduled(_controller: ScheduledController, env: Env, _ctx: ExecutionContext): Promise<void> {
    const outcome = await runScheduledSync(env, {
      // arrows, not `fetch` itself: Workers throw "Illegal invocation" if a platform function is called with another `this`
      fetch: (input, init) => fetch(input, init),
      now: () => new Date(),
      sink: consoleSink,
    });
    // A total failure must show as a failed invocation. A partial pass does not: it stored what it could and closed nothing.
    if (outcome.status === 'failed') throw new Error(`jobicy sync failed (${outcome.summary.error_class ?? 'unknown'})`);
  },

  async fetch(): Promise<Response> {
    return new Response('Not found', { status: 404, headers: { 'cache-control': 'no-store' } });
  },
};
