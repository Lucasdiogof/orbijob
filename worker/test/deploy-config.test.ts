import { existsSync, readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

// The deployed shape of the Worker is whatever wrangler.toml says. These checks keep it small, private and in revalidate mode.
const toml = readFileSync(new URL('../wrangler.toml', import.meta.url), 'utf8');
const lines = toml.split(/\r?\n/).map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));
const has = (l: string) => lines.includes(l);

describe('wrangler.toml (what would be deployed)', () => {
  it('names the Worker and its entry; the entry file exists', () => {
    expect(has('name = "orbijob-jobicy-sync"')).toBe(true);
    expect(has('main = "src/index.ts"')).toBe(true);
    expect(existsSync(new URL('../src/index.ts', import.meta.url))).toBe(true);
  });

  it('has no public address: no workers.dev, no preview URLs, no routes, no custom domains', () => {
    expect(has('workers_dev = false')).toBe(true);
    expect(has('preview_urls = false')).toBe(true);
    expect(toml).not.toMatch(/^\s*(routes?|route)\s*=/m);
    expect(toml).not.toMatch(/custom_domain/);
  });

  it('runs on exactly ONE cron, every 6 hours (UTC), well above the source\'s one-pass-per-hour rule', () => {
    const crons = lines.filter((l) => l.startsWith('crons'));
    expect(crons).toEqual(['crons = ["0 */6 * * *"]']);
    const [min, hour] = '0 */6 * * *'.split(' ');
    expect(min).toBe('0');
    expect(Number(hour!.replace('*/', ''))).toBeGreaterThanOrEqual(1); // hours between runs
  });

  it('pins revalidate and sets nothing else that could widen the catalogue', () => {
    const vars = lines.slice(lines.indexOf('[vars]') + 1).filter((l) => !l.startsWith('['));
    const kv = vars.filter((l) => /^[A-Z_]+ = /.test(l));
    expect(kv).toEqual(['SYNC_MODE = "revalidate"']);
  });

  it('keeps Workers Logs on and binds nothing (no KV, D1, R2, queues, durable objects, services)', () => {
    expect(lines).toContain('[observability]');
    expect(lines).toContain('enabled = true');
    expect(toml).not.toMatch(/^\s*\[\[/m);
    expect(toml).not.toMatch(/kv_namespaces|d1_databases|r2_buckets|queues|durable_objects|services|ai\b/);
  });

  it('contains no secret or key material, and no secret is declared as a plain variable', () => {
    expect(lines.join('\n')).not.toMatch(/sb_secret_|sb_publishable_|eyJ[\w-]{10,}|service_role\s*=|SUPABASE_SERVICE_ROLE_KEY\s*=|SUPABASE_URL\s*=/);
  });
});
