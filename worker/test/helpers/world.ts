import type { LogSink } from '../../src/log';
import feed from '../fixtures/jobicy-feed.sanitized.json';

/**
 * An in-memory stand-in for BOTH services the Worker talks to: the Supabase REST API (the handful of endpoints
 * SupabaseJobStore uses, with the same filters and headers) and the Jobicy API. The real SupabaseJobStore, lease and
 * runSync run against it; only the network is replaced. The real PostgREST is exercised by test/live/*.
 */
/** Made-up keys built by repetition: they look like nothing a secret scanner would flag, and they are worth nothing. */
export const fakeKey = (tag: string) => `sb_secret_${tag.repeat(10)}`;
export const fakePublishable = (tag: string) => `sb_publishable_${tag.repeat(10)}`;
export const SECRET_KEY = fakeKey('TESTKEY');
export const URL_SB = 'https://example.supabase.co';

export const FEED_JOBS = feed.jobs as Record<string, unknown>[];

export interface RunRow {
  id: string; source_id: string; scope: string; started_at: string; finished_at: string | null; status: string;
  fetched: number; upserted: number; duplicates: number; closed: number; http_errors: number; error_class: string | null;
}

const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

export class World {
  /** The wall clock the Worker sees. */
  clock = new Date('2026-10-10T12:00:00.000Z');
  now = () => new Date(this.clock);

  jobs = new Map<string, Record<string, unknown>>();
  runs: RunRow[] = [];
  calls = { feed: 0, status: 0, supabase: 0 };
  /** Every header set sent to Supabase, for credential-format checks. */
  supabaseHeaders: Record<string, string>[] = [];

  expectedKey = SECRET_KEY;
  /** Force every Supabase answer to this status (e.g. 401, 503). */
  supabaseStatus?: number;
  /** Make every Supabase request fail at the network level. */
  supabaseDown = false;

  feedPages: Record<string, unknown>[][] = [FEED_JOBS.slice(0, 5), FEED_JOBS.slice(5)];
  /** Called with (feed call number starting at 0, cursor); return a Response or an Error to inject a failure. */
  jobicyFault?: (call: number, cursor: string | null) => Response | Error | null;
  statuses: Record<string, string> = {};
  /** Advance the clock by this much on every feed request (for the deadline test). */
  feedTakes = 0;

  logs: string[] = [];
  sink: LogSink = {
    log: (l) => this.logs.push(l),
    warn: (l) => this.logs.push(l),
    error: (l) => this.logs.push(l),
  };

  private seq = 0;
  private nextId = () => `00000000-0000-4000-8000-${String(++this.seq).padStart(12, '0')}`;
  private yieldTick = () => new Promise<void>((r) => setTimeout(r, 0));

  fetch: typeof fetch = async (input, init) => {
    const url = new URL(String(input));
    if (url.hostname === 'jobicy.com' || url.hostname === 'localhost') return this.jobicy(url);
    if (url.hostname === 'example.supabase.co') return this.supabase(url, init ?? {});
    throw new Error(`unexpected host ${url.hostname}`);
  };

  // ───────── Jobicy ─────────
  private async jobicy(url: URL): Promise<Response> {
    if (url.pathname.endsWith('/status')) {
      this.calls.status++;
      const ids = url.searchParams.get('ids')!.split(',');
      return json(200, { success: true, jobs: ids.map((id) => ({ id: Number(id), status: this.statuses[id] ?? 'active' })) });
    }
    const call = this.calls.feed++;
    const cursor = url.searchParams.get('cursor');
    if (this.feedTakes) this.clock = new Date(this.clock.getTime() + this.feedTakes);
    const fault = this.jobicyFault?.(call, cursor);
    if (fault instanceof Error) throw fault;
    if (fault) return fault;
    const i = cursor ? Number(cursor.replace('C', '')) : 0;
    return json(200, { success: true, jobs: this.feedPages[i] ?? [], nextCursor: i + 1 < this.feedPages.length ? `C${i + 1}` : null, hasMore: i + 1 < this.feedPages.length });
  }

  // ───────── Supabase REST ─────────
  private async supabase(url: URL, init: RequestInit): Promise<Response> {
    this.calls.supabase++;
    if (this.supabaseDown) throw new TypeError('fetch failed');
    const headers = Object.fromEntries(Object.entries((init.headers ?? {}) as Record<string, string>));
    this.supabaseHeaders.push(headers);
    await this.yieldTick(); // lets two concurrent Workers interleave, like two isolates would
    if (this.supabaseStatus) return json(this.supabaseStatus, { message: 'forced', hint: this.expectedKey });
    if (headers.apikey !== this.expectedKey) return json(401, { message: 'Invalid API key' });
    const table = url.pathname.replace('/rest/v1/', '');
    const method = init.method ?? 'GET';
    const body = init.body ? JSON.parse(String(init.body)) : undefined;
    const q = url.searchParams;
    const eq = (k: string) => (q.get(k) ?? '').replace(/^eq\./, '');

    if (table === 'sync_runs') {
      if (method === 'GET') {
        const status = q.get('status') ?? '';
        const bounds = q.getAll('started_at'); // [gte.<since>, lte.<until>]: PostgREST ANDs repeated filters on one column
        const lo = bounds.find((b) => b.startsWith('gte.'))?.slice(4);
        const hi = bounds.find((b) => b.startsWith('lte.'))?.slice(4);
        const rows = this.runs.filter((r) => r.source_id === eq('source_id')
          && (status === 'eq.running' ? r.status === 'running' : status === 'neq.running' ? r.status !== 'running' : true)
          && (!lo || Date.parse(r.started_at) >= Date.parse(lo)) && (!hi || Date.parse(r.started_at) <= Date.parse(hi)));
        return json(200, rows.map((r) => ({ id: r.id, status: r.status, started_at: r.started_at, error_class: r.error_class })));
      }
      if (method === 'POST') {
        // the primary key: an id that already exists is refused (unique violation -> HTTP 409), atomically
        if (body.id && this.runs.some((r) => r.id === body.id)) return json(409, { code: '23505', message: 'duplicate key value violates unique constraint "sync_runs_pkey"' });
        const row: RunRow = { id: this.nextId(), finished_at: null, fetched: 0, upserted: 0, duplicates: 0, closed: 0, http_errors: 0, error_class: null, scope: '', ...body };
        this.runs.push(row); // (an explicit body.id overrides the generated one above)
        return q.get('select') ? json(201, [{ id: row.id }]) : new Response(null, { status: 201 });
      }
      if (method === 'PATCH') {
        const row = this.runs.find((r) => r.id === eq('id'));
        if (row) Object.assign(row, body);
        return new Response(null, { status: 204 });
      }
    }

    if (table === 'jobs') {
      if (method === 'POST') {
        for (const r of body as Record<string, unknown>[]) this.jobs.set(`${r.source_id}:${r.external_id}`, { ...(this.jobs.get(`${r.source_id}:${r.external_id}`) ?? {}), ...r });
        return new Response(null, { status: 201 });
      }
      if (method === 'GET') {
        const ids = [...this.jobs.values()].filter((j) => j.source_id === eq('source_id') && j.status === eq('status')).map((j) => ({ external_id: j.external_id }));
        const off = Number(q.get('offset') ?? 0);
        return json(200, ids.slice(off, off + Number(q.get('limit') ?? 1000)));
      }
      if (method === 'PATCH') {
        const wanted = [...(q.get('external_id') ?? '').matchAll(/"([^"]+)"/g)].map((m) => m[1]);
        for (const id of wanted) {
          const j = this.jobs.get(`${eq('source_id')}:${id}`);
          if (j) Object.assign(j, body);
        }
        return new Response(null, { status: 204 });
      }
    }
    return json(404, { message: `unhandled ${method} ${table}` });
  }

  // ───────── helpers for assertions ─────────
  openIds = () => [...this.jobs.values()].filter((j) => j.status === 'open').map((j) => String(j.external_id)).sort();
  status = (id: string) => this.jobs.get(`jobicy:${id}`)?.status;
  allLogs = () => this.logs.join('\n');
  env = (over: Record<string, string | undefined> = {}) => ({ SUPABASE_URL: URL_SB, SUPABASE_SERVICE_ROLE_KEY: SECRET_KEY, ...over });
  deps = (extra: Record<string, unknown> = {}) => ({ fetch: this.fetch, now: this.now, sink: this.sink, sleep: async () => {}, retry: { retries: 1, baseMs: 1, maxMs: 1 }, ...extra });
}

/** An open job as it would already be stored, for tests that start from existing data. */
export const storedJob = (externalId: string, status: 'open' | 'closed' = 'open') => ({
  source_id: 'jobicy', external_id: externalId, company: 'c', title: `t ${externalId}`, status,
  original_url: `https://jobicy.com/jobs/${externalId}`, canonical_url: `https://jobicy.com/jobs/${externalId}`, fingerprint: `fp-${externalId}`,
});
