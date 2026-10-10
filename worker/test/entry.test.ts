import { afterEach, describe, expect, it, vi } from 'vitest';
import worker from '../src/index';
import { ConfigError } from '../src/env';
import { SyncFailure } from '../src/scheduled';
import { SECRET_KEY, World, fakeKey } from './helpers/world';

const ctx = { waitUntil: () => {} };
const controller = { cron: '0 */6 * * *', scheduledTime: Date.parse('2026-10-10T12:00:00Z') };

afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals(); vi.restoreAllMocks(); });

/** Advances the fake clock until the promise settles, letting real async work (crypto) finish in between. */
async function drive(p: Promise<unknown>): Promise<void> {
  let done = false;
  void p.then(() => { done = true; }, () => { done = true; });
  for (let i = 0; i < 2000 && !done; i++) { await vi.advanceTimersByTimeAsync(1000); await new Promise<void>((r) => setImmediate(r)); }
}

/** Runs the real entry point with the platform globals replaced by the in-memory world. */
function boot(w: World, timers = false) {
  vi.stubGlobal('fetch', w.fetch);
  // `timers`: also fake setTimeout, so the production retry back-off (seconds) does not make the test wait for real
  vi.useFakeTimers({ toFake: timers ? ['Date', 'setTimeout', 'clearTimeout'] : ['Date'] });
  vi.setSystemTime(w.clock);
  const out: string[] = [];
  vi.spyOn(console, 'log').mockImplementation((l) => void out.push(String(l)));
  vi.spyOn(console, 'warn').mockImplementation((l) => void out.push(String(l)));
  vi.spyOn(console, 'error').mockImplementation((l) => void out.push(String(l)));
  return out;
}

describe('Worker entry point', () => {
  it('has no public surface: every HTTP request gets a bare 404', async () => {
    for (const method of ['GET', 'POST']) {
      const r = await worker.fetch();
      expect(r.status).toBe(404);
      expect(await r.text()).toBe('Not found');
      expect(r.headers.get('cache-control')).toBe('no-store');
      expect(method).toBeTruthy();
    }
    expect(Object.keys(worker).sort()).toEqual(['fetch', 'scheduled']); // no queue/email/tail handler and no admin route
  });

  it('a scheduled run with a valid configuration completes and writes structured logs to the console', async () => {
    const w = new World();
    const out = boot(w);
    await expect(worker.scheduled(controller, w.env(), ctx)).resolves.toBeUndefined();
    expect(w.openIds()).toHaveLength(10);
    expect(out.map((l) => JSON.parse(l).event)).toEqual(expect.arrayContaining(['sync_start', 'sync_ok']));
    expect(out.join('\n')).not.toContain(SECRET_KEY);
  });

  it('missing configuration fails the invocation visibly', async () => {
    const w = new World();
    const out = boot(w);
    await expect(worker.scheduled(controller, {}, ctx)).rejects.toBeInstanceOf(ConfigError);
    expect(JSON.parse(out[0]!)).toMatchObject({ level: 'error', event: 'config_invalid' });
    expect(w.calls.supabase + w.calls.feed).toBe(0);
  });

  it('a rejected credential fails the invocation and prints no secret', async () => {
    const w = new World();
    w.expectedKey = fakeKey('DIFFERENT');
    const out = boot(w);
    await expect(worker.scheduled(controller, w.env(), ctx)).rejects.toBeInstanceOf(SyncFailure);
    expect(out.join('\n')).not.toContain(SECRET_KEY);
    expect(w.calls.feed).toBe(0);
  });

  it('a total failure of the pass (source down) fails the invocation; a partial pass does not', async () => {
    const down = new World();
    down.jobicyFault = () => new Response('x', { status: 500 });
    boot(down, true);
    const failing = expect(worker.scheduled(controller, down.env(), ctx)).rejects.toThrow(/jobicy sync failed \(http_500\)/);
    await drive(failing);
    await failing;

    const part = new World();
    part.jobicyFault = (_c, cursor) => (cursor ? new Response('x', { status: 500 }) : null);
    boot(part, true);
    const partial = expect(worker.scheduled(controller, part.env(), ctx)).resolves.toBeUndefined();
    await drive(partial);
    await partial;
    expect(part.runs[0]!.status).toBe('partial');
  });

  it('a skipped run (another one is alive, or too soon) is not an error', async () => {
    const w = new World();
    boot(w);
    await worker.scheduled(controller, w.env(), ctx);
    await expect(worker.scheduled(controller, w.env(), ctx)).resolves.toBeUndefined();
    expect(w.runs.filter((r) => r.status === 'ok')).toHaveLength(1);
  });
});
