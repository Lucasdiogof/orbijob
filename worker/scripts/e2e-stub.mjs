// Stand-in for the two services the Worker talks to, for the end-to-end run in the REAL Workers runtime (workerd):
//   /api/v2/remote-jobs[/status]  the Jobicy API, served from the sanitized real fixture
//   /rest/v1/*                    the Supabase REST API: forwarded to a real PostgREST when POSTGREST_URL is set (CI),
//                                 otherwise answered by a small in-memory model of the handful of endpoints the Worker uses
// Plain JavaScript, no dependencies. Counters and state are readable at /__state (test use only; it listens on localhost).
import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';

const PORT = Number(process.env.STUB_PORT ?? 8788);
const KEY = process.env.E2E_KEY ?? '';
const POSTGREST = process.env.POSTGREST_URL?.replace(/\/+$/, '');
const feed = JSON.parse(readFileSync(fileURLToPath(new URL('../test/fixtures/jobicy-feed.sanitized.json', import.meta.url)), 'utf8')).jobs;
const pages = [feed.slice(0, 5), feed.slice(5)];

const state = { feed: 0, status: 0, supabase: 0, badAuth: 0, headers: [], jobs: new Map(), runs: [] };
let seq = 0;
const nextId = () => `00000000-0000-4000-8000-${String(++seq).padStart(12, '0')}`;
const send = (res, code, body, extra = {}) => { res.writeHead(code, { 'content-type': 'application/json', ...extra }); res.end(body === undefined ? '' : JSON.stringify(body)); };

async function readBody(req) { const parts = []; for await (const c of req) parts.push(c); return Buffer.concat(parts).toString('utf8'); }

function jobicy(url, res) {
  if (url.pathname.endsWith('/status')) {
    state.status++;
    const ids = url.searchParams.get('ids').split(',');
    return send(res, 200, { success: true, jobs: ids.map((id) => ({ id: Number(id), status: 'active' })) });
  }
  state.feed++;
  const cursor = url.searchParams.get('cursor');
  const i = cursor ? Number(cursor.replace('C', '')) : 0;
  return send(res, 200, { success: true, jobs: pages[i] ?? [], nextCursor: i + 1 < pages.length ? `C${i + 1}` : null, hasMore: i + 1 < pages.length });
}

async function supabase(req, url, res) {
  state.supabase++;
  const headers = req.headers;
  state.headers.push({ apikey: !!headers.apikey, authorization: !!headers.authorization });
  const raw = await readBody(req);
  if (POSTGREST) {
    const target = `${POSTGREST}${url.pathname.replace(/^\/rest\/v1/, '')}${url.search}`;
    const fwd = { 'content-type': 'application/json' };
    for (const h of ['authorization', 'prefer', 'accept']) if (headers[h]) fwd[h] = headers[h];
    const r = await fetch(target, { method: req.method, headers: fwd, body: ['GET', 'HEAD'].includes(req.method) ? undefined : raw });
    const text = await r.text();
    res.writeHead(r.status, { 'content-type': r.headers.get('content-type') ?? 'application/json' });
    return res.end(text);
  }
  if (headers.apikey !== KEY) { state.badAuth++; return send(res, 401, { message: 'Invalid API key' }); }
  // sb_secret_ keys are not JWTs: they must NOT arrive in Authorization
  if (KEY.startsWith('sb_secret_') && headers.authorization) { state.badAuth++; return send(res, 401, { message: 'Invalid JWT' }); }
  const table = url.pathname.replace('/rest/v1/', '');
  const body = raw ? JSON.parse(raw) : undefined;
  const q = url.searchParams;
  const eq = (k) => (q.get(k) ?? '').replace(/^eq\./, '');
  if (table === 'sync_runs') {
    if (req.method === 'GET') {
      const status = q.get('status') ?? '';
      const since = q.get('started_at')?.replace(/^gte\./, '');
      const rows = state.runs.filter((r) => r.source_id === eq('source_id')
        && (status === 'eq.running' ? r.status === 'running' : status === 'neq.running' ? r.status !== 'running' : true)
        && (!since || Date.parse(r.started_at) >= Date.parse(since)));
      return send(res, 200, rows.map((r) => ({ id: r.id, status: r.status, started_at: r.started_at, error_class: r.error_class })));
    }
    if (req.method === 'POST') {
      const row = { id: nextId(), finished_at: null, fetched: 0, upserted: 0, duplicates: 0, closed: 0, http_errors: 0, error_class: null, scope: '', ...body };
      state.runs.push(row);
      return q.get('select') ? send(res, 201, [{ id: row.id }]) : send(res, 201);
    }
    if (req.method === 'PATCH') { Object.assign(state.runs.find((r) => r.id === eq('id')) ?? {}, body); return send(res, 204); }
  }
  if (table === 'jobs') {
    if (req.method === 'POST') { for (const r of body) state.jobs.set(`${r.source_id}:${r.external_id}`, { ...(state.jobs.get(`${r.source_id}:${r.external_id}`) ?? {}), ...r }); return send(res, 201); }
    if (req.method === 'GET') {
      const ids = [...state.jobs.values()].filter((j) => j.source_id === eq('source_id') && j.status === eq('status')).map((j) => ({ external_id: j.external_id }));
      const off = Number(q.get('offset') ?? 0);
      return send(res, 200, ids.slice(off, off + Number(q.get('limit') ?? 1000)));
    }
    if (req.method === 'PATCH') {
      for (const m of (q.get('external_id') ?? '').matchAll(/"([^"]+)"/g)) { const j = state.jobs.get(`${eq('source_id')}:${m[1]}`); if (j) Object.assign(j, body); }
      return send(res, 204);
    }
  }
  return send(res, 404, { message: `unhandled ${req.method} ${table}` });
}

createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
    if (url.pathname === '/__state') {
      return send(res, 200, { feed: state.feed, status: state.status, supabase: state.supabase, badAuth: state.badAuth, headers: state.headers, jobs: state.jobs.size, openJobs: [...state.jobs.values()].filter((j) => j.status === 'open').length, runs: state.runs });
    }
    if (url.pathname.startsWith('/api/v2/')) return jobicy(url, res);
    if (url.pathname.startsWith('/rest/v1/')) return await supabase(req, url, res);
    return send(res, 404, { message: 'not found' });
  } catch (e) {
    return send(res, 500, { message: String(e) });
  }
}).listen(PORT, '127.0.0.1', () => console.log(`stub ready on ${PORT}${POSTGREST ? ` (Supabase -> ${POSTGREST})` : ' (in-memory Supabase)'}`));
