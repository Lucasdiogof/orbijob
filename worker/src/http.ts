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
