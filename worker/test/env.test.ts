import { describe, expect, it } from 'vitest';
import { ConfigError, classifyKey, loadConfig } from '../src/env';
import { createLogger } from '../src/log';
import { fakeKey, fakePublishable } from './helpers/world';

const jwt = (role: string) => `eyJhbGciOiJIUzI1NiJ9.${btoa(JSON.stringify({ role })).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_')}.c2lnbmF0dXJl`;
const GOOD = { SUPABASE_URL: 'https://abcdefgh.supabase.co', SUPABASE_SERVICE_ROLE_KEY: fakeKey('GOODKEY') };

const problems = (env: object) => { try { loadConfig(env); return []; } catch (e) { return (e as ConfigError).problems; } };

describe('classifyKey (by shape; the server verifies signatures)', () => {
  it('recognises every key type the project can hold', () => {
    expect(classifyKey('sb_secret_abc')).toBe('secret');
    expect(classifyKey('sb_publishable_abc')).toBe('publishable');
    expect(classifyKey(jwt('service_role'))).toBe('service_role_jwt');
    expect(classifyKey(jwt('anon'))).toBe('anon_jwt');
    expect(classifyKey(jwt('authenticated'))).toBe('unknown');
    expect(classifyKey('')).toBe('unknown');
    expect(classifyKey('hello')).toBe('unknown');
    expect(classifyKey('eyJ.not-json.x')).toBe('unknown');
  });
});

describe('loadConfig', () => {
  it('accepts a secret key and a legacy service_role JWT', () => {
    expect(loadConfig(GOOD)).toMatchObject({ supabaseUrl: 'https://abcdefgh.supabase.co', keyKind: 'secret', maxPages: 40, jobicyOrigin: undefined });
    expect(loadConfig({ ...GOOD, SUPABASE_SERVICE_ROLE_KEY: jwt('service_role') }).keyKind).toBe('service_role_jwt');
  });

  it('names every missing variable at once, without any value', () => {
    expect(problems({})).toEqual(['SUPABASE_URL is not set', 'SUPABASE_SERVICE_ROLE_KEY is not set']);
    expect(problems({ SUPABASE_URL: '  ', SUPABASE_SERVICE_ROLE_KEY: '' })).toHaveLength(2);
  });

  it('refuses the publishable or anon key: it cannot write, and putting it here is a mistake worth catching', () => {
    for (const k of ['sb_publishable_abcdefghijklmnop', jwt('anon')]) {
      expect(problems({ ...GOOD, SUPABASE_SERVICE_ROLE_KEY: k })).toEqual(['SUPABASE_SERVICE_ROLE_KEY holds a publishable/anon key, which cannot write the catalogue']);
    }
  });

  it('refuses a key it cannot recognise (fail closed)', () => {
    expect(problems({ ...GOOD, SUPABASE_SERVICE_ROLE_KEY: 'something-else-entirely' })[0]).toMatch(/not a recognised secret key/);
  });

  it('refuses an insecure or malformed Supabase URL', () => {
    for (const u of ['http://abcdefgh.supabase.co', 'ftp://x', 'not a url', 'https://user:pw@abcdefgh.supabase.co']) {
      expect(problems({ ...GOOD, SUPABASE_URL: u }).length, u).toBe(1);
    }
    expect(problems({ ...GOOD, SUPABASE_URL: 'http://localhost:54321' })).toEqual([]);
  });

  it('the Jobicy origin override accepts only jobicy.com or localhost; the page cap is a bounded integer', () => {
    expect(loadConfig({ ...GOOD, JOBICY_API_URL: 'https://jobicy.com/' }).jobicyOrigin).toBe('https://jobicy.com');
    expect(loadConfig({ ...GOOD, JOBICY_API_URL: 'http://127.0.0.1:8788' }).jobicyOrigin).toBe('http://127.0.0.1:8788');
    for (const u of ['https://evil.example', 'http://jobicy.com', 'https://jobicy.com.evil.example', 'garbage']) {
      expect(problems({ ...GOOD, JOBICY_API_URL: u }).length, u).toBe(1);
    }
    expect(loadConfig({ ...GOOD, SYNC_MAX_PAGES: '7' }).maxPages).toBe(7);
    for (const n of ['0', '101', 'x', '2.5', '-1']) expect(problems({ ...GOOD, SYNC_MAX_PAGES: n }).length, n).toBe(1);
  });

  it('the error never contains the key, even when the key itself is the problem', () => {
    const key = fakePublishable('SECRETVALUE');
    try { loadConfig({ ...GOOD, SUPABASE_SERVICE_ROLE_KEY: key }); } catch (e) {
      expect(String(e) + JSON.stringify((e as ConfigError).problems)).not.toContain('SECRETVALUE');
    }
  });
});

describe('createLogger', () => {
  const sink = () => { const lines: string[] = []; return { lines, s: { log: (l: string) => lines.push(`log:${l}`), warn: (l: string) => lines.push(`warn:${l}`), error: (l: string) => lines.push(`error:${l}`) } }; };

  it('writes one JSON object per line with level, event and time, on the matching console method', () => {
    const { lines, s } = sink();
    const log = createLogger(s, [], () => new Date('2026-10-10T12:00:00Z'));
    log('info', 'a', { n: 1 }); log('warn', 'b'); log('error', 'c');
    expect(lines.map((l) => l.split(':')[0])).toEqual(['log', 'warn', 'error']);
    expect(JSON.parse(lines[0]!.slice(4))).toEqual({ level: 'info', event: 'a', at: '2026-10-10T12:00:00.000Z', n: 1 });
  });

  it('masks every registered secret wherever it appears, including inside nested data and with JSON escaping', () => {
    const { lines, s } = sink();
    const secret = 'sb_secret_' + 'abc"def\\ghi_'.repeat(2);
    const log = createLogger(s, [secret]);
    log('error', 'x', { nested: { value: `before ${secret} after` }, list: [secret] });
    expect(lines[0]).not.toContain('abc"def');
    expect(lines[0]).not.toContain('abc\\"def');
    expect(lines[0]).toContain('[redacted]');
  });

  it('ignores too-short "secrets" (they would blank out ordinary words)', () => {
    const { lines, s } = sink();
    createLogger(s, ['ok'])('info', 'ok', { ok: true });
    expect(lines[0]).toContain('"event":"ok"');
  });
});
