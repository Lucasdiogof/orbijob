import { env } from 'node:process';
import { describe, expect, it } from 'vitest';
import { jobicyConnector } from '../../src/connectors/jobicy';

/**
 * REAL, read-only calls to the public Jobicy API. Skipped unless JOBICY_LIVE=1, so CI and normal runs never touch the network:
 *   JOBICY_LIVE=1 npx vitest run test/live
 * One feed page (count=100) and one status request per run; no key, nothing is written anywhere. Jobicy asks for at most one
 * automated sync PASS per hour; do not loop this.
 */
describe.skipIf(env.JOBICY_LIVE !== '1')('Jobicy live API (read-only)', () => {
  const connector = jobicyConnector(fetch);

  it('the real feed still has the documented shape and our parser accepts it', async () => {
    const page = await connector.fetchPage(null, '');
    const total = page.jobs.length + (page.rejected?.length ?? 0);
    expect(total).toBeGreaterThan(0);
    expect(page.isFullSnapshot).toBe(false);
    expect(page.jobs.length / total).toBeGreaterThan(0.95); // unknown shapes would show up as mass rejections
    for (const j of page.jobs) {
      expect(new URL(j.originalUrl).hostname).toMatch(/(^|\.)jobicy\.com$/);
      expect(j.workMode).toBe('remote');
      expect(j.externalId).toMatch(/^[1-9][0-9]*$/);
      expect(j.description).not.toMatch(/<[a-z][^>]*>/i);
    }
    expect(new Set(page.jobs.map((j) => j.externalId)).size).toBe(page.jobs.length);
    console.info('live feed:', { jobs: page.jobs.length, rejected: page.rejected, hasNextCursor: !!page.nextCursor });

    const ids = page.jobs.slice(0, 5).map((j) => j.externalId);
    const st = await connector.checkStatuses!(ids);
    expect(Object.keys(st).sort()).toEqual([...ids].sort());
    for (const v of Object.values(st)) expect(['open', 'closed', 'unknown']).toContain(v);
  }, 60_000);
});
