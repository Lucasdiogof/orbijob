import { spawn } from 'node:child_process';
import { createServer, type Server } from 'node:http';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
// @ts-expect-error plain JavaScript module without type declarations
import { HOUR, evaluate, renderIssueBody } from '../scripts/watchdog-core.mjs';

const NOW = Date.parse('2026-10-11T12:00:00Z');
const ago = (h: number) => new Date(NOW - h * HOUR).toISOString();
const run = (hoursAgo: number, conclusion: string | null = 'success', alerts: string[] = []) => ({ id: Math.round(hoursAgo * 100), createdAt: ago(hoursAgo), conclusion, status: conclusion ? 'completed' : 'in_progress', alerts });
const ids = (r: { alerts: { id: string }[] }) => r.alerts.map((a) => a.id).sort();
const healthyRuns = [run(1), run(7), run(13)];

describe('watchdog rules (pure)', () => {
  it('everything normal: no alert', () => {
    const r = evaluate({ nowMs: NOW, enabled: true, runs: healthyRuns, oldestCheckedAt: ago(5), visibleJobs: 299 });
    expect(r).toEqual({ alerts: [], healthy: true });
  });

  it('jobs approaching the 72 h window: warning at 48 h, critical at 60 h, quiet below', () => {
    const at = (h: number) => ids(evaluate({ nowMs: NOW, enabled: true, runs: healthyRuns, oldestCheckedAt: ago(h), visibleJobs: 299 }));
    expect(at(47.9)).toEqual([]);
    expect(at(48)).toEqual(['validity_warning']);
    expect(at(59.9)).toEqual(['validity_warning']);
    expect(at(60)).toEqual(['validity_critical']);
    expect(evaluate({ nowMs: NOW, enabled: true, runs: healthyRuns, oldestCheckedAt: ago(66), visibleJobs: 299 }).alerts[0]!.message).toMatch(/6\.0 h/);
  });

  it('the catalogue deadline is watched EVEN BEFORE the automation is switched on (that is the point of the monitor)', () => {
    const r = evaluate({ nowMs: NOW, enabled: false, runs: [], oldestCheckedAt: ago(55), visibleJobs: 299 });
    expect(ids(r)).toEqual(['validity_warning']); // and no "schedule_missed": nothing was supposed to run
  });

  it('an empty public catalogue is critical', () => {
    expect(ids(evaluate({ nowMs: NOW, enabled: false, runs: [], oldestCheckedAt: null, visibleJobs: 0 }))).toEqual(['catalog_empty']);
  });

  it('scheduled run not started: no run in 14 h, or none at all while enabled', () => {
    expect(ids(evaluate({ nowMs: NOW, enabled: true, runs: [run(13.9), run(20)], oldestCheckedAt: ago(5), visibleJobs: 1 }))).toEqual([]);
    expect(ids(evaluate({ nowMs: NOW, enabled: true, runs: [run(14.1), run(20)], oldestCheckedAt: ago(5), visibleJobs: 1 }))).toEqual(['schedule_missed']);
    expect(ids(evaluate({ nowMs: NOW, enabled: true, runs: [], oldestCheckedAt: ago(5), visibleJobs: 1 }))).toEqual(['no_recent_success', 'schedule_missed']);
  });

  it('no success for a long period', () => {
    const r = evaluate({ nowMs: NOW, enabled: true, runs: [run(1, 'failure'), run(7, 'failure'), run(25)], oldestCheckedAt: ago(30), visibleJobs: 1 });
    expect(ids(r)).toEqual(['consecutive_failures', 'no_recent_success']);
  });

  it('one failure alone is tolerated; two in a row are not', () => {
    expect(ids(evaluate({ nowMs: NOW, enabled: true, runs: [run(1, 'failure'), run(7), run(13)], oldestCheckedAt: ago(5), visibleJobs: 1 }))).toEqual([]);
    expect(ids(evaluate({ nowMs: NOW, enabled: true, runs: [run(1, 'failure'), run(7, 'failure'), run(13)], oldestCheckedAt: ago(5), visibleJobs: 1 }))).toEqual(['consecutive_failures']);
  });

  it('a run still in progress is not a failure', () => {
    expect(ids(evaluate({ nowMs: NOW, enabled: true, runs: [run(0.1, null), run(6), run(12)], oldestCheckedAt: ago(5), visibleJobs: 1 }))).toEqual([]);
  });

  it('failure kinds reported by the workflow: authentication, unreachable database, Jobicy API errors', () => {
    const base = { nowMs: NOW, enabled: true, oldestCheckedAt: ago(5), visibleJobs: 1 };
    expect(ids(evaluate({ ...base, runs: [run(1, 'failure', ['auth']), run(7)] }))).toEqual(['auth_failed']);
    expect(ids(evaluate({ ...base, runs: [run(1, 'failure', ['unreachable']), run(7)] }))).toEqual(['database_unreachable']);
    expect(ids(evaluate({ ...base, runs: [run(1, 'failure', ['api']), run(7)] }))).toEqual(['jobicy_api_errors']);
  });

  it('the issue text is plain, ordered by severity, and mentions only ids, counts and links', () => {
    const body = renderIssueBody({ alerts: [{ id: 'a', severity: 'warning', message: 'w' }, { id: 'b', severity: 'critical', message: 'c' }], nowIso: '2026-10-11T12:00:00Z', runUrl: 'https://github.com/x/y/actions/runs/1' });
    expect(body.indexOf('CRITICO')).toBeLessThan(body.indexOf('ATENCAO'));
    expect(body).toContain('docs/JOBICY_ACTIONS_AUTOMATION.md');
    expect(body).not.toMatch(/sb_secret_|eyJ/);
  });
});

// ---- the script, as a real process, against local stand-ins for GitHub and the public Supabase endpoint ----
const SCRIPT = fileURLToPath(new URL('../scripts/jobicy-watchdog.mjs', import.meta.url));
const PUB = 'sb_publishable_' + 'WATCHDOGTEST'.repeat(3);
let gh: Server; let sb: Server; let ghBase = ''; let sbBase = '';
let issues: { number: number; title: string; body: string; state: string; pull_request?: unknown }[] = [];
let workflowRuns: unknown[] = [];
let oldest: string | null = null; let visible = 0;
let calls: { method: string; path: string; body?: string }[] = [];
let runJobs: unknown[] = [];

const listen = (srv: Server) => new Promise<string>((r) => srv.listen(0, '127.0.0.1', () => r(`http://127.0.0.1:${(srv.address() as { port: number }).port}`)));
beforeEach(async () => {
  issues = []; workflowRuns = []; oldest = null; visible = 0; calls = []; runJobs = [];
  gh = createServer(async (req, res) => {
    const chunks: Buffer[] = []; for await (const c of req) chunks.push(c as Buffer);
    const body = Buffer.concat(chunks).toString('utf8');
    const url = new URL(req.url!, 'http://x');
    calls.push({ method: req.method!, path: url.pathname, body });
    const send = (code: number, o: unknown) => { res.writeHead(code, { 'content-type': 'application/json' }); res.end(JSON.stringify(o)); };
    if (url.pathname.endsWith('/workflows/jobicy-revalidate.yml/runs')) return send(200, { workflow_runs: workflowRuns });
    if (/\/actions\/runs\/\d+\/jobs$/.test(url.pathname)) return send(200, { jobs: runJobs });
    if (url.pathname.endsWith('/issues') && req.method === 'GET') return send(200, issues.filter((i) => i.state === 'open'));
    if (url.pathname.endsWith('/issues') && req.method === 'POST') { const b = JSON.parse(body); const i = { number: issues.length + 1, state: 'open', ...b }; issues.push(i); return send(201, i); }
    const m = /\/issues\/(\d+)(\/comments)?$/.exec(url.pathname);
    if (m && req.method === 'PATCH') { Object.assign(issues[Number(m[1]) - 1]!, JSON.parse(body)); return send(200, {}); }
    if (m && m[2] && req.method === 'POST') return send(201, {});
    return send(404, {});
  });
  sb = createServer((req, res) => {
    calls.push({ method: req.method!, path: new URL(req.url!, 'http://x').pathname });
    if (req.headers.apikey !== PUB) { res.writeHead(401); return res.end('{}'); }
    res.writeHead(200, { 'content-type': 'application/json', 'content-range': `0-0/${visible}` });
    res.end(JSON.stringify(oldest ? [{ last_checked_at: oldest }] : []));
  });
  ghBase = await listen(gh); sbBase = await listen(sb);
});
afterEach(() => Promise.all([new Promise((r) => gh.close(r)), new Promise((r) => sb.close(r))]));

function watchdog(env: Record<string, string> = {}, args: string[] = []) {
  return new Promise<{ code: number; out: string }>((resolve) => {
    const p = spawn(process.execPath, [SCRIPT, ...args], {
      env: { ...process.env, WATCHDOG_GITHUB_API: ghBase, WATCHDOG_SUPABASE_URL: sbBase, SUPABASE_PUBLISHABLE_KEY: PUB, GITHUB_TOKEN: 'ghs_faketoken', GITHUB_REPOSITORY: 'o/r', JOBICY_REVALIDATION_ENABLED: 'true', NO_COLOR: '1', ...env },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let out = ''; p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (out += d));
    p.on('exit', (code) => resolve({ code: code ?? -1, out }));
  });
}
const ghRun = (hoursAgo: number, conclusion: string | null) => ({ id: Math.round(hoursAgo * 100) + 1, created_at: ago(hoursAgo + 0), conclusion, status: conclusion ? 'completed' : 'in_progress', html_url: 'https://github.com/o/r/actions/runs/1' });
// the stand-in uses wall-clock "now", so build the fixtures relative to the real clock
const realAgo = (h: number) => new Date(Date.now() - h * HOUR).toISOString();

describe('jobicy-watchdog.mjs (real process, local stand-ins)', () => {
  it('healthy: no issue is opened, exit 0, only reads', async () => {
    oldest = realAgo(5); visible = 299;
    workflowRuns = [{ ...ghRun(1, 'success'), created_at: realAgo(1) }, { ...ghRun(7, 'success'), created_at: realAgo(7) }];
    const r = await watchdog();
    expect(r.code).toBe(0);
    expect(r.out).toContain('tudo normal');
    expect(issues).toEqual([]);
    expect(calls.filter((c) => c.method !== 'GET')).toEqual([]);
  });

  it('a critical alert opens ONE issue, fails the job (so GitHub e-mails), and a second run updates it instead of opening another', async () => {
    oldest = realAgo(65); visible = 299;
    workflowRuns = [{ ...ghRun(1, 'success'), created_at: realAgo(1) }];
    const a = await watchdog();
    expect(a.code).toBe(1);
    expect(issues).toHaveLength(1);
    expect(issues[0]!.title).toMatch(/revalidacao/);
    expect(issues[0]!.body).toContain('validity_critical');
    expect((issues[0] as unknown as { labels: string[] }).labels).toEqual(['jobicy-alert']);
    await watchdog();
    expect(issues).toHaveLength(1);
  });

  it('closes the issue by itself when everything is normal again', async () => {
    issues = [{ number: 1, title: 't', body: 'b', state: 'open' }];
    oldest = realAgo(5); visible = 299;
    workflowRuns = [{ ...ghRun(1, 'success'), created_at: realAgo(1) }];
    const r = await watchdog();
    expect(r.code).toBe(0);
    expect(issues[0]!.state).toBe('closed');
  });

  it('reads the ALERT auth marker of the last failed run and reports an authentication failure', async () => {
    oldest = realAgo(5); visible = 299;
    workflowRuns = [{ ...ghRun(1, 'failure'), created_at: realAgo(1) }, { ...ghRun(7, 'success'), created_at: realAgo(7) }];
    runJobs = [{ steps: [{ name: 'Revalidate (stored jobs only; no import, no delete)', conclusion: 'failure' }, { name: 'ALERT auth: Supabase refused the credential', conclusion: 'success' }, { name: 'ALERT api: Jobicy status API errors (nothing was closed because of them)', conclusion: 'skipped' }] }];
    const r = await watchdog();
    expect(r.out).toContain('auth_failed');
    expect(r.code).toBe(1);
  });

  it('with the automation OFF only the catalogue is judged (no "schedule missed")', async () => {
    oldest = realAgo(20); visible = 299;
    const r = await watchdog({ JOBICY_REVALIDATION_ENABLED: '' });
    expect(r.code).toBe(0);
    expect(r.out).toContain('automacao desligada');
    expect(r.out).not.toContain('schedule_missed');
  });

  it('--dry-run never writes anything to GitHub', async () => {
    oldest = realAgo(65); visible = 299;
    const r = await watchdog({}, ['--dry-run']);
    expect(r.code).toBe(0);
    expect(calls.filter((c) => c.method !== 'GET')).toEqual([]);
  });

  it('refuses a secret key in place of the publishable one, and a non-local test address', async () => {
    const a = await watchdog({ SUPABASE_PUBLISHABLE_KEY: 'sb_secret_' + 'X'.repeat(30) });
    expect(a.code).toBe(1);
    expect(a.out).toMatch(/publishable/i);
    expect(a.out).not.toContain('XXXX');
    const b = await watchdog({ WATCHDOG_GITHUB_API: 'https://evil.example' });
    expect(b.code).toBe(1);
  });
});
