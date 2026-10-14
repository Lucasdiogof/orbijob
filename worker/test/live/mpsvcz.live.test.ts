import { env } from 'node:process';
import { describe, expect, it } from 'vitest';
import { mpsvCzConnector } from '../../src/connectors/mpsvcz';
import { maskPersonalEmails } from '../../src/description';

/**
 * REAL, read-only download of the Czech open data "Volná pracovní místa" (~190 MB, streamed). Skipped unless MPSVCZ_LIVE=1, so CI and normal runs
 * never touch the network:   MPSVCZ_LIVE=1 npx vitest run test/live/mpsvcz.live.test.ts
 * One pass = three small code lists + one file; the publisher refreshes it once a day, do not loop this.
 */
describe.skipIf(env.MPSVCZ_LIVE !== '1')('MPSV live open data (read-only)', () => {
  it('the real file still has the documented shape, our window is sane, and nothing personal is kept', async () => {
    const t0 = Date.now();
    const page = await mpsvCzConnector(fetch).fetchPage(null, '');
    const seconds = (Date.now() - t0) / 1000;
    console.log(`mpsvcz live: ${page.jobs.length} jobs, ${page.rejected?.length ?? 0} rejected, ${seconds.toFixed(1)} s`);
    expect(page.jobs.length).toBeGreaterThan(500);
    expect(page.jobs.length).toBeLessThanOrEqual(3000);
    expect((page.rejected?.length ?? 0) / (page.jobs.length + (page.rejected?.length ?? 0))).toBeLessThan(0.02);
    const ids = new Set<string>();
    for (const j of page.jobs) {
      expect(ids.has(j.externalId)).toBe(false);
      ids.add(j.externalId);
      expect(j.originalUrl).toMatch(/^https:\/\/up\.gov\.cz\/volna-mista-v-cr#\/volna-mista-detail\/\d+$/);
      expect(j.country).toBe('CZ');
      expect(j.title.length).toBeGreaterThan(1);
      expect(j.company.length).toBeGreaterThan(1);
      // an address that is still there passed the shared personal-address rule (role addresses such as hr@ stay): masking again changes nothing
      for (const m of j.description.match(/[\w.+-]+@[\w-]+\.[\w.-]+/g) ?? []) expect(maskPersonalEmails(m), j.externalId).toBe(m);
      expect(j.description).not.toMatch(/\b\d{3}[ .-]\d{3}[ .-]\d{3}\b/);
      if (j.salaryMin !== null) expect(j.salaryCurrency).toBe('CZK');
    }
    const withCity = page.jobs.filter((j) => j.city).length;
    console.log(`mpsvcz live: with town ${withCity}, with salary ${page.jobs.filter((j) => j.salaryMin !== null).length}, with description ${page.jobs.filter((j) => j.description.length > 60).length}`);
    expect(withCity / page.jobs.length).toBeGreaterThan(0.5);
  }, 300_000);
});
