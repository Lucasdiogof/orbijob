import { spawn } from 'node:child_process';
import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

/**
 * Rehearsal of scripts/discover-local.mjs as a REAL child process against a local stand-in for Supabase and for Jobicy.
 * Nothing leaves 127.0.0.1; every key here is made up.
 */
const RUNNER = fileURLToPath(new URL('../scripts/discover-local.mjs', import.meta.url));
const SECRET = 'sb_secret_' + 'DISCOVERYKEY'.repeat(4);
const LEGACY_JWT = 'eyJhbGciOiJIUzI1NiJ9.' + Buffer.from(JSON.stringify({ role: 'service_role' })).toString('base64url') + '.sig';
const ATTRIBUTION = 'Remote jobs via Jobicy (https://jobicy.com)';
const OLD = '2026-10-01T00:00:00.000Z';

type Row = Record<string, unknown>;
interface World {
  source: Row; jobs: Map<string, Row>; runs: Row[]; statuses: Record<string, string>; feed: Row[][];
  calls: { feed: number; status: number; jobPosts: number; patches: number; deletes: number; other: number };
  seq: number;
  /** Rewrites an existing job when the first insert arrives (a misbehaving server): the post-run verification must catch it. */
  tamper?: boolean;
  failFeedAfter?: number; failStatus?: boolean;
}
let server: Server; let base = ''; let w: World;
const json = (res: ServerResponse, code: number, body?: unknown) => { res.writeHead(code, { 'content-type': 'application/json' }); res.end(body === undefined ? '' : JSON.stringify(body)); };
const readBody = async (req: IncomingMessage) => { const p: Buffer[] = []; for await (const c of req) p.push(c as Buffer); return Buffer.concat(p).toString('utf8'); };
const listing = (id: number, title = `Role ${id}`) => ({ id, url: `https://jobicy.com/jobs/${id}-role-${id}`, jobTitle: title, companyName: `Company ${id}`, jobType: ['Full-Time'], jobGeo: 'USA', jobDescription: `<p>Description ${id}</p>`, pubDate: '2026-10-10 10:00:00' });
const stored = (id: string, over: Row = {}): Row => ({
  external_id: id, source_id: 'jobicy', status: 'open', last_checked_at: OLD, company: `Company ${id}`, title: `Role ${id}`, description: 'reviewed', original_url: `https://jobicy.com/jobs/${id}-role-${id}`,
  apply_url: `https://jobicy.com/jobs/${id}-role-${id}`, fingerprint: `company ${id}|role ${id}|US|`, canonical_url: `https://jobicy.com/jobs/${id}-role-${id}`, country: 'US', geo_restrictions: ['US'], ...over,
});

async function handle(req: IncomingMessage, res: ServerResponse) {
  const url = new URL(req.url!, base);
  if (url.pathname.endsWith('/status')) {
    w.calls.status++;
    if (w.failStatus) return json(res, 500, {});
    const ids = url.searchParams.get('ids')!.split(',');
    return json(res, 200, { success: true, jobs: ids.map((id) => ({ id: Number(id), status: w.statuses[id] ?? 'active' })) });
  }
  if (url.pathname.startsWith('/api/v2/')) {
    const n = w.calls.feed++;
    if (w.failFeedAfter !== undefined && n >= w.failFeedAfter) return json(res, 500, {});
    const i = url.searchParams.get('cursor') ? Number(url.searchParams.get('cursor')!.replace('C', '')) : 0;
    return json(res, 200, { success: true, jobs: w.feed[i] ?? [], nextCursor: i + 1 < w.feed.length ? `C${i + 1}` : null });
  }
  if (req.headers.apikey !== SECRET) return json(res, 401, { message: 'Invalid API key' });
  const table = url.pathname.replace('/rest/v1/', '');
  const q = url.searchParams;
  const eq = (k: string) => (q.get(k) ?? '').replace(/^eq\./, '');
  const raw = await readBody(req);
  const payload = raw ? JSON.parse(raw) : undefined;
  if (req.method === 'DELETE') { w.calls.deletes++; return json(res, 204); }
  if (table === 'job_sources') return json(res, 200, q.get('id') === 'eq.jobicy' ? [w.source] : []);
  if (table === 'sync_runs') {
    if (req.method === 'GET') {
      const status = q.get('status') ?? '';
      const lo = q.getAll('started_at').find((b) => b.startsWith('gte.'))?.slice(4);
      const hi = q.getAll('started_at').find((b) => b.startsWith('lte.'))?.slice(4);
      const rows = w.runs.filter((r) => (status === 'eq.running' ? r.status === 'running' : status === 'neq.running' ? r.status !== 'running' : true)
        && (!lo || Date.parse(String(r.started_at)) >= Date.parse(lo)) && (!hi || Date.parse(String(r.started_at)) <= Date.parse(hi)))
        .sort((a, b) => String(b.started_at).localeCompare(String(a.started_at)));
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
    if (req.method === 'POST') {
      w.calls.jobPosts++;
      if (!String(req.headers.prefer).includes('ignore-duplicates')) return json(res, 400, { message: 'discovery must insert-only' });
      if (w.tamper) { const first = [...w.jobs.values()][0]; if (first) first.description = 'OVERWRITTEN'; }
      const inserted: Row[] = [];
      for (const r of payload as Row[]) { if (w.jobs.has(String(r.external_id))) continue; w.jobs.set(String(r.external_id), { ...r }); inserted.push({ external_id: r.external_id }); }
      return json(res, 201, inserted);
    }
    if (req.method === 'GET' && String(req.headers.prefer ?? '').includes('count=exact')) {
      const n = [...w.jobs.values()].filter((r) => r.status !== 'closed' || String(r.description ?? '') !== '').length;
      res.writeHead(206, { 'content-type': 'application/json', 'content-range': `0-0/${n}` });
      return res.end('[]');
    }
    if (req.method === 'GET') {
      const cols = (q.get('select') ?? 'external_id').split(',');
      const rows = [...w.jobs.values()].sort((a, b) => String(a.external_id).localeCompare(String(b.external_id)));
      const off = Number(q.get('offset') ?? 0);
      return json(res, 200, rows.slice(off, off + Number(q.get('limit') ?? 1000)).map((r) => Object.fromEntries(cols.map((c) => [c, r[c] ?? null]))));
    }
    if (req.method === 'PATCH') { w.calls.patches++; return json(res, 204); }
  }
  w.calls.other++;
  return json(res, 404, { message: `unhandled ${req.method} ${table}` });
}

beforeEach(async () => {
  w = {
    source: { id: 'jobicy', status: 'CONDITIONAL', attribution: ATTRIBUTION, can_redistribute: true },
    jobs: new Map([['101', stored('101')], ['102', stored('102', { status: 'closed' })]]),
    runs: [], statuses: {}, feed: [[listing(101, 'Changed title'), listing(103), listing(104)], [listing(102), listing(105)]],
    calls: { feed: 0, status: 0, jobPosts: 0, patches: 0, deletes: 0, other: 0 }, seq: 0,
  };
  server = createServer((req, res) => { handle(req, res).catch((e) => json(res, 500, { message: String(e) })); });
  await new Promise<void>((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${(server.address() as { port: number }).port}`;
});
afterEach(() => new Promise<void>((r) => server.close(() => r())));

function runner(args: string[], env: Record<string, string | undefined> = {}) {
  return new Promise<{ code: number; out: string }>((resolve) => {
    const p = spawn(process.execPath, [RUNNER, ...args], {
      env: { ...process.env, ORBIJOB_REHEARSAL_BASE: base, ORBIJOB_REHEARSAL_JOBICY: base, ORBIJOB_SUPABASE_SECRET: SECRET, NO_COLOR: '1', ...env } as NodeJS.ProcessEnv,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let out = '';
    p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (out += d));
    p.on('exit', (code) => resolve({ code: code ?? -1, out }));
  });
}

describe('scripts/discover-local.mjs (rehearsal against a local stand-in)', () => {
  it('one real pass: inserts only the new active listings, leaves the stored ones (even the closed one) exactly as they were, source untouched', async () => {
    const before = JSON.stringify([...w.jobs.entries()]);
    const r = await runner(['run', '--yes']);
    expect(r.out).toContain('verificacao: OK');
    expect(r.code).toBe(0);
    expect(r.out).toContain('importadas=3');
    expect(r.out).toMatch(/metricas: lidas=5 importadas=3 ja_conhecidas=2 duplicadas=0 inativas=0 rejeitadas=0 adiadas_pelo_limite=0 atualizadas=0 fechadas=0/);
    expect([...w.jobs.keys()].sort()).toEqual(['101', '102', '103', '104', '105']);
    expect(JSON.stringify(w.jobs.get('101'))).toBe(JSON.stringify(JSON.parse(before)[0][1]));
    expect(w.jobs.get('102')?.status).toBe('closed');
    expect(w.jobs.get('103')).toMatchObject({ source_id: 'jobicy', status: 'open', original_url: 'https://jobicy.com/jobs/103-role-103' });
    expect(w.runs).toHaveLength(1);
    expect(w.runs[0]).toMatchObject({ scope: 'discover', status: 'ok', upserted: 3 });
    expect(w.calls).toMatchObject({ patches: 0, deletes: 0, other: 0 });
    expect(r.out).not.toContain(SECRET);
  });

  it('does not import what the status endpoint does not confirm active', async () => {
    w.statuses = { '104': 'closed', '105': 'unknown' };
    const r = await runner(['run', '--yes']);
    expect(r.code).toBe(0);
    expect([...w.jobs.keys()].sort()).toEqual(['101', '102', '103']);
    expect(r.out).toContain('inativas=2');
  });

  it('honours the per-pass cap', async () => {
    const r = await runner(['run', '--yes'], { SYNC_MAX_NEW_JOBS: '1' });
    expect(r.code).toBe(0);
    expect(w.jobs.size).toBe(3);
    expect(r.out).toContain('adiadas_pelo_limite=2');
  });

  it('preflight is read-only; preview writes NOTHING and says what would be imported', async () => {
    const pf = await runner(['preflight']);
    expect(pf.code).toBe(0);
    expect(pf.out).toContain('vagas_gravadas=2');
    const pv = await runner(['preview']);
    expect(pv.code).toBe(0);
    expect(pv.out).toContain('NADA FOI GRAVADO');
    expect(pv.out).toContain('seriam_importadas=3');
    expect(w.calls.jobPosts).toBe(0);
    expect(w.runs).toEqual([]);
    expect(w.jobs.size).toBe(2);
  });

  it('refuses to run without --yes, without a key, and with the legacy JWT key', async () => {
    expect((await runner(['run'])).code).toBe(1);
    expect((await runner(['run', '--yes'], { ORBIJOB_SUPABASE_SECRET: '' })).code).toBe(1);
    const legacy = await runner(['run', '--yes'], { ORBIJOB_SUPABASE_SECRET: LEGACY_JWT });
    expect(legacy.code).toBe(1);
    expect(legacy.out).toContain('credencial recusada');
    expect(w.calls.jobPosts).toBe(0);
    expect(w.calls.feed).toBe(0);
  });

  it('the catalogue ceiling stops the import, keeps what fits, and exits 7 (a distinct alert)', async () => {
    const r = await runner(['run', '--yes'], { SYNC_MAX_CATALOGUE: '3' });
    expect(r.code).toBe(7);
    expect(w.jobs.size).toBe(3);
    expect(w.runs[0]).toMatchObject({ status: 'partial', error_class: 'catalogue_full' });
  });

  it('a second pass within the hour is refused before reading the feed (one pass per hour)', async () => {
    expect((await runner(['run', '--yes'])).code).toBe(0);
    const feedCalls = w.calls.feed;
    const again = await runner(['run', '--yes']);
    expect(again.code).toBe(1);
    expect(again.out).toContain('ultima hora');
    expect(w.calls.feed).toBe(feedCalls);
  });

  it('a stand-in that rewrites a stored job is caught by the verification (exit 1)', async () => {
    w.tamper = true;
    const r = await runner(['run', '--yes']);
    expect(r.code).toBe(1);
    expect(r.out).toContain('verificacao: REPROVADO');
    expect(r.out).toContain('conteudo de uma vaga existente mudou');
  });

  it('exit codes: wrong key 4, feed failing after the first page 6 (partial), status endpoint failing 1', async () => {
    expect((await runner(['run', '--yes'], { ORBIJOB_SUPABASE_SECRET: 'sb_secret_' + 'WRONG'.repeat(10) })).code).toBe(4);
    w.failFeedAfter = 1;
    const partial = await runner(['run', '--yes']);
    expect(partial.code).toBe(6);
    expect(w.jobs.size).toBe(4); // 103 and 104 from the first page
    w.failFeedAfter = undefined; w.runs = []; w.jobs.delete('103'); w.jobs.delete('104'); w.failStatus = true;
    expect((await runner(['run', '--yes'])).code).toBe(1);
    expect(w.jobs.size).toBe(2);
  }, 120_000);
});
