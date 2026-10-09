import { describe, expect, it } from 'vitest';
import { HttpError, getJson, parseRetryAfter, withRetry } from '../src/http';
import { leverConnector } from '../src/connectors/lever';

const res = (status: number, body: unknown = [], headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers });
const opts = { retries: 3, baseMs: 10, maxMs: 100, sleep: async () => {}, random: () => 1 };

describe('parseRetryAfter', () => {
  it('parses seconds, dates, caps and rejects junk', () => {
    expect(parseRetryAfter('2')).toBe(2000);
    expect(parseRetryAfter('Thu, 01 Jan 2026 00:00:10 GMT', () => Date.parse('2026-01-01T00:00:00Z'))).toBe(10_000);
    expect(parseRetryAfter('99999')).toBe(300_000);
    expect(parseRetryAfter('nonsense')).toBeUndefined();
    expect(parseRetryAfter(null)).toBeUndefined();
  });
});

describe('getJson + withRetry', () => {
  it('maps status codes to HttpError with Retry-After', async () => {
    const f = (async () => res(429, {}, { 'retry-after': '3' })) as typeof fetch;
    await expect(getJson(f, 'https://x.invalid')).rejects.toMatchObject({ status: 429, retryAfterMs: 3000 });
  });
  it('does NOT retry a 404 (bad site slug) but retries 503 then succeeds', async () => {
    let calls = 0;
    const notFound = (async () => (calls++, res(404))) as typeof fetch;
    await expect(withRetry(() => getJson(notFound, 'https://x.invalid'), opts)).rejects.toBeInstanceOf(HttpError);
    expect(calls).toBe(1);
    let n = 0;
    const flaky = (async () => (n++ < 2 ? res(503) : res(200, [{ ok: 1 }]))) as typeof fetch;
    expect(await withRetry(() => getJson(flaky, 'https://x.invalid'), opts)).toEqual([{ ok: 1 }]);
    expect(n).toBe(3);
  });
  it('uses the Retry-After wait instead of jitter', async () => {
    const waits: number[] = [];
    let n = 0;
    const f = (async () => (n++ === 0 ? res(429, {}, { 'retry-after': '2' }) : res(200, []))) as typeof fetch;
    await withRetry(() => getJson(f, 'https://x.invalid'), { ...opts, sleep: async (ms) => void waits.push(ms) });
    expect(waits).toEqual([2000]);
  });
  it('aborts a hung request after the timeout', async () => {
    const hang = ((_u: string, init?: RequestInit) =>
      new Promise((_r, rej) => init?.signal?.addEventListener('abort', () => rej(init.signal!.reason)))) as typeof fetch;
    await expect(getJson(hang, 'https://x.invalid', {}, 20)).rejects.toBeTruthy();
  });
  it('lever connector surfaces a 404 as a non-retryable HttpError', async () => {
    const f = (async () => res(404)) as typeof fetch;
    await expect(withRetry(() => leverConnector(f).fetchPage(null, 'nope'), opts)).rejects.toMatchObject({ status: 404 });
  });
});
