export interface RetryOptions {
  retries: number;
  baseMs: number;
  maxMs: number;
  sleep?: (ms: number) => Promise<void>;
  random?: () => number;
}

export class HttpError extends Error {
  constructor(public status: number, public retryAfterMs?: number) {
    super(`HTTP ${status}`);
  }
}

/** Retry-After as milliseconds: delta-seconds or an HTTP date. Undefined when absent/invalid. Capped at 5 min. */
export function parseRetryAfter(value: string | null, now: () => number = Date.now): number | undefined {
  if (!value) return undefined;
  const secs = Number(value);
  const ms = Number.isFinite(secs) ? secs * 1000 : Date.parse(value) - now();
  return Number.isFinite(ms) && ms >= 0 ? Math.min(ms, 300_000) : undefined;
}

/**
 * GET JSON with a hard timeout. Non-2xx responses become HttpError (so withRetry retries only 429/5xx and
 * honours Retry-After); network errors and timeouts propagate as plain errors (treated as retryable).
 */
export async function getJson<T>(fetchImpl: typeof fetch, url: string, init: RequestInit = {}, timeoutMs = 15_000): Promise<T> {
  const res = await fetchImpl(url, { ...init, signal: AbortSignal.timeout(timeoutMs) });
  if (!res.ok) throw new HttpError(res.status, parseRetryAfter(res.headers.get('retry-after')));
  return (await res.json()) as T;
}

const retryable = (s: number) => s === 429 || s >= 500;

/** Exponential backoff with full jitter; honours Retry-After. 4xx (except 429) is never retried. */
export async function withRetry<T>(fn: () => Promise<T>, o: RetryOptions): Promise<T> {
  const sleep = o.sleep ?? ((ms) => new Promise((r) => setTimeout(r, ms)));
  const rnd = o.random ?? Math.random;
  for (let attempt = 0; ; attempt++) {
    try {
      return await fn();
    } catch (e) {
      const status = e instanceof HttpError ? e.status : 0; // 0 = network error
      const canRetry = status === 0 || retryable(status);
      if (!canRetry || attempt >= o.retries) throw e;
      const backoff = Math.min(o.maxMs, o.baseMs * 2 ** attempt);
      const wait = e instanceof HttpError && e.retryAfterMs ? e.retryAfterMs : rnd() * backoff;
      await sleep(wait);
    }
  }
}

/** Token-bucket-style spacing limiter (one per connector). */
export class RateLimiter {
  private next = 0;
  constructor(private minIntervalMs: number, private now: () => number = Date.now) {}
  /** Returns ms to wait before the next request may be sent, and reserves the slot. */
  reserve(): number {
    const t = this.now();
    const start = Math.max(t, this.next);
    this.next = start + this.minIntervalMs;
    return start - t;
  }
}
