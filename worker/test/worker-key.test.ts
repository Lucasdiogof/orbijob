import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createServer, type Server } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

/**
 * The procedure that gives the Worker its OWN key: scripts/worker-key-check.mjs (read-only authentication checks) and
 * scripts/worker-secrets.mjs (sends the secrets through stdin). Real child processes against a local stand-in for Supabase and a
 * stand-in for wrangler. Nothing leaves 127.0.0.1; every key here is made up.
 */
const CHECK = fileURLToPath(new URL('../scripts/worker-key-check.mjs', import.meta.url));
const SECRETS = fileURLToPath(new URL('../scripts/worker-secrets.mjs', import.meta.url));
const KEY = 'sb_secret_' + 'WORKERKEYTEST'.repeat(4);
const LEGACY = 'eyJhbGciOiJIUzI1NiJ9.' + Buffer.from(JSON.stringify({ role: 'service_role' })).toString('base64url') + '.sig';
const PUBLISHABLE = 'sb_publishable_' + 'WORKERPUB'.repeat(3);
const USER_TABLES = ['professional_profiles', 'saved_jobs', 'applications', 'user_preferences', 'credentials', 'education', 'experiences', 'reminders', 'saved_searches', 'viewed_jobs', 'application_events'];

let server: Server; let base = ''; let dir = '';
let requests: { method: string; table: string }[] = [];
let overPrivileged = false;

beforeEach(async () => {
  requests = []; overPrivileged = false;
  dir = mkdtempSync(join(tmpdir(), 'orbijob-wk-'));
  server = createServer((req, res) => {
    const table = new URL(req.url!, 'http://x').pathname.replace('/rest/v1/', '');
    requests.push({ method: req.method ?? '', table });
    const send = (code: number, body: unknown) => { res.writeHead(code, { 'content-type': 'application/json' }); res.end(JSON.stringify(body)); };
    if (req.headers.apikey !== KEY) return send(401, { message: 'Invalid API key' });
    if (['job_sources', 'jobs', 'sync_runs'].includes(table)) return send(200, []);
    if (USER_TABLES.includes(table)) return overPrivileged && table === 'applications' ? send(200, []) : send(401, { code: '42501', message: 'permission denied' });
    return send(404, {});
  });
  await new Promise<void>((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${(server.address() as { port: number }).port}`;
  // a stand-in for wrangler: records its arguments and what arrives on stdin
  writeFileSync(join(dir, 'fake-wrangler.js'), `
    const fs = require('node:fs'); let input = '';
    process.stdin.on('data', (d) => (input += d)).on('end', () => {
      fs.appendFileSync(process.env.WRANGLER_LOG, JSON.stringify({ argv: process.argv.slice(2), stdin: input }) + '\\n');
    });`);
});
afterEach(() => { rmSync(dir, { recursive: true, force: true }); return new Promise<void>((r) => server.close(() => r())); });

function run(script: string, args: string[], env: Record<string, string> = {}) {
  return new Promise<{ code: number; out: string }>((resolve) => {
    const p = spawn(process.execPath, [script, ...args], {
      env: { ...process.env, ORBIJOB_REHEARSAL_BASE: base, ORBIJOB_WORKER_KEY: KEY, ORBIJOB_WRANGLER_JS: join(dir, 'fake-wrangler.js'), WRANGLER_LOG: join(dir, 'wrangler.log'), NO_COLOR: '1', ...env },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let out = '';
    p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (out += d));
    p.on('exit', (code) => resolve({ code: code ?? -1, out }));
  });
}
const wranglerCalls = () => { try { return readFileSync(join(dir, 'wrangler.log'), 'utf8').trim().split('\n').filter(Boolean).map((l) => JSON.parse(l) as { argv: string[]; stdin: string }); } catch { return []; } };

describe('worker-key-check.mjs (read-only authentication checks)', () => {
  it('approves a proper key: reads the catalogue tables, is refused on every user table, sends only GET', async () => {
    const r = await run(CHECK, []);
    expect(r.code).toBe(0);
    expect(r.out).toContain('APROVADA');
    expect(requests.length).toBe(3 + USER_TABLES.length);
    expect(requests.every((q) => q.method === 'GET')).toBe(true);
    expect(r.out).not.toContain(KEY);
    expect(r.out).not.toContain('WORKERKEYTEST');
  });

  it('refuses the legacy JWT and the publishable key BEFORE any request', async () => {
    for (const bad of [LEGACY, PUBLISHABLE, 'whatever']) {
      const r = await run(CHECK, [], { ORBIJOB_WORKER_KEY: bad });
      expect(r.code).toBe(1);
      expect(r.out).toMatch(/sb_secret_/);
      expect(r.out).not.toContain(bad);
    }
    expect(requests).toEqual([]);
  });

  it('a key that can read user data is rejected: too much permission', async () => {
    overPrivileged = true;
    const r = await run(CHECK, []);
    expect(r.code).toBe(1);
    expect(r.out).toContain('REPROVADA');
    expect(r.out).toMatch(/applications/);
  });

  it('a wrong key fails every read', async () => {
    const r = await run(CHECK, [], { ORBIJOB_WORKER_KEY: 'sb_secret_' + 'NOTTHEKEY'.repeat(5) });
    expect(r.code).toBe(1);
    expect(r.out).toContain('REPROVADA');
  });

  it('a non-localhost rehearsal address is refused (the key cannot be sent anywhere else by this path)', async () => {
    const r = await run(CHECK, [], { ORBIJOB_REHEARSAL_BASE: 'https://example.com' });
    expect(r.code).toBe(1);
    expect(requests).toEqual([]);
  });
});

describe('worker-secrets.mjs', () => {
  it('rehearsal (default): validates and says what it would do; sends NOTHING', async () => {
    const r = await run(SECRETS, []);
    expect(r.code).toBe(0);
    expect(r.out).toContain('ENSAIO');
    expect(wranglerCalls()).toEqual([]);
  });

  it('--apply without --yes refuses', async () => {
    const r = await run(SECRETS, ['--apply']);
    expect(r.code).toBe(1);
    expect(r.out).toMatch(/--yes/);
    expect(wranglerCalls()).toEqual([]);
  });

  it('--apply --yes: two `secret put` calls to the Worker, the key ONLY on stdin, never in arguments or output', async () => {
    const r = await run(SECRETS, ['--apply', '--yes']);
    expect(r.code).toBe(0);
    const calls = wranglerCalls();
    expect(calls.map((c) => c.argv)).toEqual([
      ['secret', 'put', 'SUPABASE_URL', '--name', 'orbijob-jobicy-sync'],
      ['secret', 'put', 'SUPABASE_SERVICE_ROLE_KEY', '--name', 'orbijob-jobicy-sync'],
    ]);
    expect(calls[1]!.stdin.trim()).toBe(KEY);
    expect(JSON.stringify(calls.map((c) => c.argv))).not.toContain('WORKERKEYTEST');
    expect(r.out).not.toContain('WORKERKEYTEST');
  });

  it('a key that fails the checks is never sent', async () => {
    overPrivileged = true;
    const r = await run(SECRETS, ['--apply', '--yes']);
    expect(r.code).toBe(1);
    expect(wranglerCalls()).toEqual([]);
  });

  it('a localhost rehearsal address never reaches a REAL wrangler', async () => {
    const r = await run(SECRETS, ['--apply', '--yes'], { ORBIJOB_WRANGLER_JS: '' });
    expect(r.code).toBe(1);
    expect(wranglerCalls()).toEqual([]);
  });
});
