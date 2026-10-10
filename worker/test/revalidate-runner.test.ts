import { spawn } from 'node:child_process';
import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

/**
 * Rehearsal of scripts/revalidate-local.mjs as a REAL child process against a local stand-in for Supabase and for Jobicy.
 * Nothing leaves 127.0.0.1; every key here is made up.
 */
const RUNNER = fileURLToPath(new URL('../scripts/revalidate-local.mjs', import.meta.url));
const SECRET = 'sb_secret_' + 'REVALIDATEKEY'.repeat(4);
const LEGACY_JWT = 'eyJhbGciOiJIUzI1NiJ9.' + Buffer.from(JSON.stringify({ role: 'service_role' })).toString('base64url') + '.sig';
const ATTRIBUTION = 'Remote jobs via Jobicy (https://jobicy.com)';
const OLD = '2026-10-01T00:00:00.000Z';

interface World {
  source: Record<string, unknown>;
  jobs: Map<string, { external_id: string; status: string; last_checked_at: string }>;
  runs: Record<string, unknown>[];
  statuses: Record<string, string>;
  calls: { feed: number; status: number; requests: number; jobPosts: number; deletes: number };
  seq: number;
  /** Status calls after this many answer HTTP 500. */
  failStatusAfter?: number;
}
let server: Server; let base = ''; let w: World;
const json = (res: ServerResponse, code: number, body?: unknown) => { res.writeHead(code, { 'content-type': 'application/json' }); res.end(body === undefined ? '' : JSON.stringify(body)); };
const readBody = async (req: IncomingMessage) => { const p: Buffer[] = []; for await (const c of req) p.push(c as Buffer); return Buffer.concat(p).toString('utf8'); };

async function handle(req: IncomingMessage, res: ServerResponse) {
  const url = new URL(req.url!, base);
  if (url.pathname.endsWith('/status')) {
    w.calls.status++;
    if (w.failStatusAfter !== undefined && w.calls.status > w.failStatusAfter) return json(res, 500, {});
    const ids = url.searchParams.get('ids')!.split(',');
    return json(res, 200, { success: true, jobs: ids.filter((id) => w.statuses[id] !== 'silent').map((id) => ({ id: Number(id), status: w.statuses[id] ?? 'active' })) });
  }
  if (url.pathname.startsWith('/api/v2/')) { w.calls.feed++; return json(res, 200, { success: true, jobs: [], nextCursor: null, hasMore: false }); }
  w.calls.requests++;
  if (req.method === 'DELETE') w.calls.deletes++;
  if (req.headers.apikey !== SECRET) return json(res, 401, { message: 'Invalid API key' });
  const table = url.pathname.replace('/rest/v1/', '');
  const q = url.searchParams;
  const eq = (k: string) => (q.get(k) ?? '').replace(/^eq\./, '');
  const raw = await readBody(req);
  const payload = raw ? JSON.parse(raw) : undefined;
  if (table === 'job_sources') return json(res, 200, q.get('id') === 'eq.jobicy' ? [w.source] : []);
  if (table === 'sync_runs') {
    if (req.method === 'GET') {
      const status = q.get('status') ?? '';
      const lo = q.getAll('started_at').find((b) => b.startsWith('gte.'))?.slice(4);
      const hi = q.getAll('started_at').find((b) => b.startsWith('lte.'))?.slice(4);
      const rows = w.runs.filter((r) => (status === 'eq.running' ? r.status === 'running' : status === 'neq.running' ? r.status !== 'running' : true)
        && (!lo || Date.parse(String(r.started_at)) >= Date.parse(lo)) && (!hi || Date.parse(String(r.started_at)) <= Date.parse(hi)));
      return json(res, 200, rows.map((r) => ({ id: r.id, status: r.status, started_at: r.started_at, error_class: r.error_class })));
    }
    if (req.method === 'POST') {
      if (payload.id && w.runs.some((r) => r.id === payload.id)) return json(res, 409, { code: '23505' });
      const row = { id: payload.id ?? `00000000-0000-4000-8000-${String(++w.seq).padStart(12, '0')}`, finished_at: null, fetched: 0, upserted: 0, duplicates: 0, closed: 0, http_errors: 0, error_class: null, ...payload };
      w.runs.push(row);
      return q.get('select') ? json(res, 201, [{ id: row.id }]) : json(res, 201);
    }
    if (req.method === 'PATCH') { Object.assign(w.runs.find((r) => r.id === eq('id')) ?? {}, payload); return json(res, 204); }
  }
  if (table === 'jobs') {
    if (req.method === 'POST') { w.calls.jobPosts++; return json(res, 201); }
    if (req.method === 'GET') {
      const rows = [...w.jobs.values()].filter((j) => !q.get('status') || j.status === eq('status')).sort((a, b) => a.external_id.localeCompare(b.external_id));
      const off = Number(q.get('offset') ?? 0);
      return json(res, 200, rows.slice(off, off + Number(q.get('limit') ?? 1000)));
    }
    if (req.method === 'PATCH') {
      for (const m of (q.get('external_id') ?? '').matchAll(/"([^"]+)"/g)) { const j = w.jobs.get(m[1]!); if (j && (!q.get('status') || j.status === eq('status'))) Object.assign(j, payload); }
      return json(res, 204);
    }
  }
  return json(res, 404, { message: `unhandled ${req.method} ${table}` });
}

beforeEach(async () => {
  w = {
    source: { id: 'jobicy', status: 'CONDITIONAL', attribution: ATTRIBUTION, can_redistribute: true },
    jobs: new Map(['111', '222', '333'].map((id) => [id, { external_id: id, status: 'open', last_checked_at: OLD }])),
    runs: [], statuses: { '111': 'closed', '222': 'active', '333': 'unknown' },
    calls: { feed: 0, status: 0, requests: 0, jobPosts: 0, deletes: 0 }, seq: 0,
  };
  server = createServer((req, res) => { handle(req, res).catch((e) => json(res, 500, { message: String(e) })); });
  await new Promise<void>((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${(server.address() as { port: number }).port}`;
});
afterEach(() => new Promise<void>((r) => server.close(() => r())));

function runner(args: string[], env: Record<string, string> = {}) {
  return new Promise<{ code: number; out: string }>((resolve) => {
    const p = spawn(process.execPath, [RUNNER, ...args], {
      env: { ...process.env, ORBIJOB_REHEARSAL_BASE: base, ORBIJOB_REHEARSAL_JOBICY: base, ORBIJOB_SUPABASE_SECRET: SECRET, NO_COLOR: '1', ...env },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let out = '';
    p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (out += d));
    p.on('exit', (code) => resolve({ code: code ?? -1, out }));
  });
}

describe('scripts/revalidate-local.mjs (rehearsal against a local stand-in)', () => {
  it('one revalidation: closes the confirmed closed, stamps the confirmed open, leaves unknown alone, imports nothing, source untouched', async () => {
    const r = await runner(['run', '--yes']);
    expect(r.code).toBe(0);
    expect(r.out).toContain('fechadas=1 confirmadas=1 sem_resposta=1');
    expect(r.out).toContain('verificacao: OK');
    expect([...w.jobs.values()].map((j) => j.status)).toEqual(['closed', 'open', 'open']);
    expect(w.jobs.get('222')!.last_checked_at).not.toBe(OLD);
    expect(w.jobs.get('333')!.last_checked_at).toBe(OLD);
    expect(w.jobs.size).toBe(3);
    expect(w.calls).toMatchObject({ feed: 0, jobPosts: 0, deletes: 0 });
    expect(w.source).toEqual({ id: 'jobicy', status: 'CONDITIONAL', attribution: ATTRIBUTION, can_redistribute: true });
    expect(w.runs).toHaveLength(1);
    expect(r.out).not.toContain(SECRET);
    expect(r.out).not.toContain('REVALIDATEKEY');
  });

  it('preflight is read-only', async () => {
    const r = await runner(['preflight']);
    expect(r.code).toBe(0);
    expect(r.out).toContain('preflight: OK');
    expect(w.runs).toHaveLength(0);
    expect(w.calls.status).toBe(0);
  });

  it('without --yes it refuses and writes nothing', async () => {
    const r = await runner(['run']);
    expect(r.code).toBe(1);
    expect(r.out).toMatch(/--yes/);
    expect(w.runs).toHaveLength(0);
    expect([...w.jobs.values()].every((j) => j.status === 'open' && j.last_checked_at === OLD)).toBe(true);
  });

  it('nothing to revalidate (empty catalogue): fails the preflight and asks the source nothing', async () => {
    w.jobs.clear();
    const r = await runner(['run', '--yes']);
    expect(r.code).toBe(1);
    expect(r.out).toMatch(/nao ha vagas/);
    expect(w.calls.status).toBe(0);
    expect(w.runs).toHaveLength(0);
  });

  it('a pass already running blocks it', async () => {
    w.runs.push({ id: '00000000-0000-4000-8000-0000000000aa', source_id: 'jobicy', status: 'running', started_at: new Date().toISOString(), error_class: null });
    const r = await runner(['run', '--yes']);
    expect(r.code).toBe(1);
    expect(r.out).toMatch(/andamento/);
    expect(w.calls.status).toBe(0);
  });

  it('the legacy JWT key is refused before any request', async () => {
    const r = await runner(['run', '--yes'], { ORBIJOB_SUPABASE_SECRET: LEGACY_JWT });
    expect(r.code).toBe(1);
    expect(r.out).toMatch(/credencial recusada/);
    expect(w.calls.requests).toBe(0);
    expect(r.out).not.toContain(LEGACY_JWT);
  });

  it('the status endpoint failing closes nothing and the run reports failure', async () => {
    const orig = w.statuses; w.statuses = new Proxy(orig, { get: () => { throw new Error('boom'); } });
    const r = await runner(['run', '--yes']);
    expect(r.code).toBe(1);
    expect([...w.jobs.values()].every((j) => j.status === 'open' && j.last_checked_at === OLD)).toBe(true);
  }, 40_000); // the real retry back-off runs in the child process

  it('exit codes the workflow relies on: 4 credential refused, 5 database unreachable, 6 partial pass, 1 pass failed', async () => {
    const refused = await runner(['run', '--yes'], { ORBIJOB_SUPABASE_SECRET: 'sb_secret_' + 'ANOTHERKEY'.repeat(5) });
    expect(refused.code).toBe(4);
    expect(refused.out).toMatch(/credencial foi recusada/);
    expect(refused.out).not.toContain('ANOTHERKEY');
    expect(w.calls.status).toBe(0);

    const closed = await new Promise<number>((resolve) => { const s2 = createServer(); s2.listen(0, '127.0.0.1', () => { const port = (s2.address() as { port: number }).port; s2.close(() => resolve(port)); }); });
    const unreachable = await runner(['run', '--yes'], { ORBIJOB_REHEARSAL_BASE: `http://127.0.0.1:${closed}` });
    expect(unreachable.code).toBe(5);

    w.jobs.clear();
    for (let i = 0; i < 150; i++) w.jobs.set(String(5000 + i), { external_id: String(5000 + i), status: 'open', last_checked_at: OLD });
    w.statuses = {}; // everything active
    w.failStatusAfter = 1; // the second batch fails
    const partial = await runner(['run', '--yes']);
    expect(partial.code).toBe(6);
    expect(partial.out).toMatch(/codigo de saida: 6/);
    expect([...w.jobs.values()].filter((j) => j.last_checked_at !== OLD)).toHaveLength(100); // the first batch stays proven
    expect([...w.jobs.values()].every((j) => j.status === 'open')).toBe(true); // nothing closed because of the failure
  }, 60_000);
});
