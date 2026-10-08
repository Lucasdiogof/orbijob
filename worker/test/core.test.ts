import { describe, expect, it } from 'vitest';
import { dedupe, shouldMarkClosed, canonicalUrl } from '../src/dedupe';
import { HttpError, RateLimiter, withRetry } from '../src/http';
import { leverConnector, normalizeLever, type LeverPosting } from '../src/connectors/lever';
import fixture from './fixtures/lever-contract.json';

const NOW = '2026-10-08T00:00:00.000Z';
const postings = fixture as LeverPosting[];

describe('lever contract (synthetic fixture shaped by documented schema; NOT real data)', () => {
  it('normalizes salary, mode, country and strips nothing it does not know', () => {
    const j = normalizeLever('example', postings[0]!, NOW);
    expect(j).toMatchObject({
      source: 'lever', title: 'Fisioterapeuta Pélvica', country: 'BR', city: 'Goiânia',
      workMode: 'onsite', salaryMin: 6000, salaryMax: 8000, salaryCurrency: 'BRL', salaryPeriod: 'month',
    });
  });
  it('leaves unknown fields null instead of inventing them', () => {
    const j = normalizeLever('example', postings[2]!, NOW);
    expect(j.salaryMin).toBeNull();
    expect(j.country).toBeNull();
    expect(j.workMode).toBe('unspecified');
    expect(j.publishedAt).toBeNull();
  });
  it('paginates with skip/limit and flags the last page', async () => {
    const urls: string[] = [];
    const f = (async (u: string) => {
      urls.push(u);
      return { ok: true, status: 200, json: async () => postings } as Response;
    }) as unknown as typeof fetch;
    const page = await leverConnector(f, () => new Date(NOW)).fetchPage(null, 'example');
    expect(urls[0]).toContain('skip=0&limit=100');
    expect(page.nextCursor).toBeNull();
    expect(page.isFullSnapshot).toBe(true);
    expect(page.jobs).toHaveLength(3);
  });
});

describe('dedupe', () => {
  const base = normalizeLever('example', postings[1]!, NOW);
  it('removes same job seen via different tracking URLs', () => {
    const a = { ...base, source: 'a', externalId: '1', originalUrl: 'https://x.com/j/1?utm_source=a' };
    const b = { ...base, source: 'b', externalId: '2', company: 'Other', title: 'Other', originalUrl: 'https://X.com/j/1/' };
    expect(dedupe([a, b]).unique).toHaveLength(1);
  });
  it('removes same company+title+place across sources, accent-insensitive', () => {
    const a = { ...base, source: 'a', externalId: '1', originalUrl: 'https://a.com/1', applyUrl: null, title: 'Fisioterapeuta Pélvica' };
    const b = { ...a, source: 'b', externalId: '9', originalUrl: 'https://b.com/9', title: 'fisioterapeuta pelvica' };
    expect(dedupe([a, b]).duplicates).toHaveLength(1);
  });
  it('keeps different jobs', () => {
    const a = normalizeLever('example', postings[0]!, NOW);
    const b = normalizeLever('example', postings[1]!, NOW);
    expect(dedupe([a, b]).unique).toHaveLength(2);
  });
  it('canonicalUrl drops tracking params', () => {
    expect(canonicalUrl('https://A.com/x/?utm_medium=z&id=3#f')).toBe('https://a.com/x?id=3');
  });
});

describe('closure rule', () => {
  it('never closes jobs based on a non-snapshot feed', () => {
    expect(shouldMarkClosed({ isFullSnapshot: false }, ['1', '2'], new Set(['1']))).toEqual([]);
  });
  it('closes only missing ids on a full snapshot', () => {
    expect(shouldMarkClosed({ isFullSnapshot: true }, ['1', '2'], new Set(['1']))).toEqual(['2']);
  });
});

describe('retry/backoff and rate limiting', () => {
  it('retries 429/5xx with growing bounded waits and then succeeds', async () => {
    const waits: number[] = [];
    let n = 0;
    const out = await withRetry(
      async () => { if (++n < 4) throw new HttpError(n === 1 ? 429 : 503); return 'ok'; },
      { retries: 5, baseMs: 100, maxMs: 250, sleep: async (ms) => { waits.push(ms); }, random: () => 1 },
    );
    expect(out).toBe('ok');
    expect(waits).toEqual([100, 200, 250]);
  });
  it('does not retry 404', async () => {
    let n = 0;
    await expect(withRetry(async () => { n++; throw new HttpError(404); }, { retries: 3, baseMs: 1, maxMs: 1, sleep: async () => {} })).rejects.toThrow('404');
    expect(n).toBe(1);
  });
  it('honours Retry-After', async () => {
    const waits: number[] = [];
    let n = 0;
    await withRetry(async () => { if (n++ === 0) throw new HttpError(429, 7000); }, { retries: 1, baseMs: 1, maxMs: 1, sleep: async (m) => { waits.push(m); } });
    expect(waits).toEqual([7000]);
  });
  it('spaces requests by the configured interval', () => {
    let t = 0;
    const rl = new RateLimiter(500, () => t);
    expect([rl.reserve(), rl.reserve(), rl.reserve()]).toEqual([0, 500, 1000]);
    t = 5000;
    expect(rl.reserve()).toBe(0);
  });
});
