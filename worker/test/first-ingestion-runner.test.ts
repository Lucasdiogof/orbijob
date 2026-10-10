import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import feedFixture from './fixtures/jobicy-feed.sanitized.json';

/**
 * Rehearsal of scripts/first-ingestion-local.mjs as a REAL child process against a local stand-in for Supabase (PostgREST
 * semantics for the handful of endpoints it uses) and for Jobicy. Nothing leaves 127.0.0.1; every key here is made up.
 */
const RUNNER = fileURLToPath(new URL('../scripts/first-ingestion-local.mjs', import.meta.url));
const SECRET = 'sb_secret_' + 'REHEARSALKEY'.repeat(4);
const ANON_JWT_LIKE = 'eyJhbGciOiJIUzI1NiJ9.' + Buffer.from(JSON.stringify({ role: 'service_role' })).toString('base64url') + '.sig';
const ATTRIBUTION = 'Remote jobs via Jobicy (https://jobicy.com)';
const PUBLISHABLE = readFileSync(new URL('../../app/dart_defines.web.json', import.meta.url), 'utf8').match(/sb_publishable_[A-Za-z0-9_-]+/)![0];

interface World {
  source: { id: string; status: string; attribution: string; can_redistribute: boolean };
  runs: Record<string, unknown>[]; jobs: Map<string, Record<string, unknown>>; feedCalls: number; requests: number; seq: number;
}

let server: Server; let base = ''; let w: World;
// 6 pages of 2 listings: a feed longer than the 3-page cap
const feedPages = Array.from({ length: 5 }, (_, i) => (feedFixture.jobs as unknown[]).slice(i * 2, i * 2 + 2));

const json = (res: ServerResponse, code: number, body?: unknown, extra: Record<string, string> = {}) => {
  res.writeHead(code, { 'content-type': 'application/json', ...extra }); res.end(body === undefined ? '' : JSON.stringify(body));
};
const body = async (req: IncomingMessage) => { const p: Buffer[] = []; for await (const c of req) p.push(c as Buffer); return Buffer.concat(p).toString('utf8'); };

async function handle(req: IncomingMessage, res: ServerResponse) {
  const url = new URL(req.url!, base);
  if (url.pathname.startsWith('/api/v2/')) {
    w.feedCalls++;
    const i = url.searchParams.get('cursor') ? Number(url.searchParams.get('cursor')!.slice(1)) : 0;
    return json(res, 200, { success: true, jobs: feedPages[i] ?? [], nextCursor: i + 1 < feedPages.length ? `C${i + 1}` : null, hasMore: i + 1 < feedPages.length });
  }
  w.requests++;
  const key = String(req.headers.apikey ?? '');
  const isService = key === SECRET;
  const isAnon = key === PUBLISHABLE;
  if (!isService && !isAnon) return json(res, 401, { message: 'Invalid API key' });
  if (isService && req.headers.authorization) return json(res, 401, { message: 'Invalid JWT' }); // sb_secret_ only in apikey
  const table = url.pathname.replace('/rest/v1/', '');
  const q = url.searchParams;
  const eq = (k: string) => (q.get(k) ?? '').replace(/^eq\./, '');
  const raw = await body(req);
  const payload = raw ? JSON.parse(raw) : undefined;
  const range = (rows: unknown[]) => ({ 'content-range': `${rows.length ? `0-${rows.length - 1}` : '*'}/${rows.length}` });
  const wantsCount = String(req.headers.prefer ?? '').includes('count=exact');

  if (table === 'job_sources') return json(res, 200, q.get('id') === 'eq.jobicy' ? [w.source] : []);
  if (table === 'sync_runs') {
    if (!isService) return json(res, 401, { code: '42501', message: 'permission denied for table sync_runs' });
    if (req.method === 'GET') {
      const status = q.get('status') ?? '';
      const lo = q.getAll('started_at').find((b) => b.startsWith('gte.'))?.slice(4);
      const hi = q.getAll('started_at').find((b) => b.startsWith('lte.'))?.slice(4);
      const rows = w.runs.filter((r) => (!q.get('source_id') || r.source_id === eq('source_id'))
        && (status === 'eq.running' ? r.status === 'running' : status === 'neq.running' ? r.status !== 'running' : true)
        && (!lo || Date.parse(String(r.started_at)) >= Date.parse(lo)) && (!hi || Date.parse(String(r.started_at)) <= Date.parse(hi)));
      return json(res, 200, wantsCount ? [] : rows, wantsCount ? range(rows) : {});
    }
    if (req.method === 'POST') {
      if (payload.id && w.runs.some((r) => r.id === payload.id)) return json(res, 409, { code: '23505', message: 'duplicate key' });
      const row = { id: `00000000-0000-4000-8000-${String(++w.seq).padStart(12, '0')}`, finished_at: null, fetched: 0, upserted: 0, duplicates: 0, closed: 0, http_errors: 0, error_class: null, scope: '', ...payload };
      w.runs.push(row);
      return q.get('select') ? json(res, 201, [{ id: row.id }]) : json(res, 201);
    }
    if (req.method === 'PATCH') { Object.assign(w.runs.find((r) => r.id === eq('id')) ?? {}, payload); return json(res, 204); }
  }
  if (table === 'jobs') {
    if (req.method === 'POST') {
      if (!isService) return json(res, 401, { message: 'permission denied' });
      for (const r of payload as Record<string, unknown>[]) w.jobs.set(`${r.source_id}:${r.external_id}`, { ...(w.jobs.get(`${r.source_id}:${r.external_id}`) ?? {}), ...r });
      return json(res, 201);
    }
    if (req.method === 'GET') {
      // clients (anon) only see jobs of redistributable sources: the RLS policy jobs_read
      let rows = [...w.jobs.values()].filter((j) => isService || (w.source.can_redistribute && ['READY', 'CONDITIONAL'].includes(w.source.status)));
      if (q.get('source_id')?.startsWith('eq.')) rows = rows.filter((j) => j.source_id === eq('source_id'));
      if (q.get('source_id')?.startsWith('neq.')) rows = rows.filter((j) => j.source_id !== q.get('source_id')!.slice(4));
      if (q.get('status')) rows = rows.filter((j) => j.status === eq('status'));
      return json(res, 200, wantsCount ? [] : rows.slice(Number(q.get('offset') ?? 0), Number(q.get('offset') ?? 0) + Number(q.get('limit') ?? 1000)), wantsCount ? range(rows) : {});
    }
    if (req.method === 'PATCH') return json(res, 204);
  }
  return json(res, 404, { message: `unhandled ${req.method} ${table}` });
}

beforeEach(async () => {
  w = { source: { id: 'jobicy', status: 'CONDITIONAL', attribution: ATTRIBUTION, can_redistribute: false }, runs: [], jobs: new Map(), feedCalls: 0, requests: 0, seq: 0 };
  server = createServer((req, res) => { handle(req, res).catch((e) => json(res, 500, { message: String(e) })); });
  await new Promise<void>((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${(server.address() as { port: number }).port}`;
});
afterEach(() => new Promise<void>((r) => server.close(() => r())));

function runner(args: string[], env: Record<string, string> = {}) {
  return new Promise<{ code: number | null; out: string }>((resolve) => {
    const p = spawn(process.execPath, [RUNNER, ...args], {
      env: { ...process.env, ORBIJOB_SUPABASE_SECRET: SECRET, ORBIJOB_REHEARSAL_BASE: base, ORBIJOB_REHEARSAL_JOBICY: base, ...env },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let out = '';
    p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (out += d));
    p.on('close', (code) => resolve({ code, out }));
  });
}

describe('first-ingestion-local.mjs (rehearsal against a local stand-in)', () => {
  it('preflight on the confirmed state passes and writes nothing', async () => {
    const r = await runner(['preflight']);
    expect(r.code).toBe(0);
    expect(r.out).toContain('preflight: OK');
    expect(w.runs).toHaveLength(0); expect(w.jobs.size).toBe(0); expect(w.feedCalls).toBe(0);
  });

  it('refuses to write without --yes', async () => {
    const r = await runner(['run']);
    expect(r.code).toBe(1);
    expect(r.out).toContain('--yes');
    expect(w.feedCalls).toBe(0); expect(w.runs).toHaveLength(0);
  });

  it('one pass: exactly 3 pages, partial/max_pages, source untouched and still unpublished, nothing public, key never printed', async () => {
    const r = await runner(['run', '--yes']);
    expect(r.code).toBe(0);
    expect(w.feedCalls).toBe(3);
    expect(w.runs).toHaveLength(1);
    expect(w.runs[0]).toMatchObject({ source_id: 'jobicy', status: 'partial', error_class: 'max_pages', upserted: 6, closed: 0 });
    expect(w.jobs.size).toBe(6);
    expect(w.source).toEqual({ id: 'jobicy', status: 'CONDITIONAL', attribution: ATTRIBUTION, can_redistribute: false });
    expect(r.out).toContain('verificacao: OK');
    expect(r.out).toContain('visiveis ao publico (anon): 0');
    expect(r.out).not.toContain('REHEARSALKEY');
    expect(r.out).not.toContain(SECRET);
  });

  it('a second run is refused by the preflight and does not touch the source again', async () => {
    await runner(['run', '--yes']);
    const feedBefore = w.feedCalls;
    const r = await runner(['run', '--yes']);
    expect(r.code).toBe(1);
    expect(r.out).toContain('preflight: REPROVADO');
    expect(w.feedCalls).toBe(feedBefore);
    expect(w.runs).toHaveLength(1);
  });

  it('the page cap is enforced even if a larger value is requested', async () => {
    const r = await runner(['run', '--yes'], { SYNC_MAX_PAGES: '9' });
    expect(r.code).toBe(1);
    expect(r.out).toContain('SYNC_MAX_PAGES invalido');
    expect(w.feedCalls).toBe(0);
  });

  it('refuses the legacy service_role JWT before any write', async () => {
    const r = await runner(['run', '--yes'], { ORBIJOB_SUPABASE_SECRET: ANON_JWT_LIKE });
    expect(r.code).toBe(1);
    expect(r.out).toContain('credencial recusada');
    expect(w.requests).toBe(0); // not even a read: the key is never sent anywhere
    expect(w.feedCalls).toBe(0); expect(w.runs).toHaveLength(0);
    expect(r.out).not.toContain(ANON_JWT_LIKE);
  });

  it('refuses when the source is already published', async () => {
    w.source.can_redistribute = true;
    const r = await runner(['run', '--yes']);
    expect(r.code).toBe(1);
    expect(r.out).toContain('can_redistribute deve ser false');
    expect(w.feedCalls).toBe(0);
  });

  it('verify alone (a separate process, after the run) re-reads the database and passes', async () => {
    await runner(['run', '--yes']);
    const r = await runner(['verify']);
    expect(r.code).toBe(0);
    expect(r.out).toContain('verificacao: OK');
  });

  it('verify alone detects a published source / public leak', async () => {
    await runner(['run', '--yes']);
    w.source.can_redistribute = true; // someone flipped the flag: the public would now see the jobs
    const r = await runner(['verify']);
    expect(r.code).toBe(1);
    expect(r.out).toContain('REPROVADO');
  });

  it('rejects rehearsal targets that are not localhost (the key can never be pointed at another host)', async () => {
    const r = await runner(['preflight'], { ORBIJOB_REHEARSAL_BASE: 'http://example.com' });
    expect(r.code).toBe(1);
    expect(r.out).toContain('so aceita http://127.0.0.1');
    expect(w.requests).toBe(0);
  });
});
