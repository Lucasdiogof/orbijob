import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
// @ts-expect-error plain ES module without types
import { evaluateHealth, worst } from '../scripts/ops-health-lib.mjs';

const NOW = new Date('2026-10-14T12:00:00Z');
const ago = (h: number) => new Date(NOW.getTime() - h * 3600_000).toISOString();
const base = () => ({
  now: NOW,
  sources: [{ id: 'jobtech', can_redistribute: true }, { id: 'getonboard', can_redistribute: true }, { id: 'draft', can_redistribute: false }],
  newestChecked: { jobtech: ago(2), getonboard: ago(5), draft: null } as Record<string, string | null>,
  runs24h: [] as { source_id: string; scope: string; status: string; error_class: string | null; started_at: string }[],
  visibleJobs: 13500,
});
const status = (rows: { check: string; status: string }[], check: string) => rows.find((r) => r.check === check)?.status;

describe('remote ops health', () => {
  it('is OK when every published source was verified recently and the app has its listings', () => {
    const rows = evaluateHealth(base());
    expect(worst(rows)).toBe('OK');
    expect(rows.some((r: { check: string }) => r.check.includes('draft'))).toBe(false); // unpublished sources are not judged
  });

  it('warns at 14 h and alerts at 30 h without a verification', () => {
    const i = base();
    i.newestChecked.jobtech = ago(15);
    i.newestChecked.getonboard = ago(31);
    const rows = evaluateHealth(i);
    expect(status(rows, 'source_fresh:jobtech')).toBe('WARN');
    expect(status(rows, 'source_fresh:getonboard')).toBe('ALERT');
    expect(worst(rows)).toBe('ALERT');
    expect(rows[0].status).toBe('ALERT'); // worst first
  });

  it('a source that was never verified is an alert', () => {
    const i = base();
    i.newestChecked.jobtech = null;
    expect(status(evaluateHealth(i), 'source_fresh:jobtech')).toBe('ALERT');
  });

  it('failed passes warn, but a pass that stopped at the catalogue ceiling is only the ceiling note', () => {
    const i = base();
    i.runs24h = [
      { source_id: 'jobtech', scope: 'discover', status: 'failed', error_class: 'http_5xx', started_at: ago(3) },
      { source_id: 'getonboard', scope: 'discover', status: 'partial', error_class: 'catalogue_full', started_at: ago(3) },
      { source_id: 'jobtech', scope: 'discover', status: 'ok', error_class: null, started_at: ago(1) },
    ];
    const rows = evaluateHealth(i);
    expect(status(rows, 'source_runs:jobtech')).toBe('WARN');
    expect(status(rows, 'source_runs:getonboard')).toBeUndefined();
    expect(status(rows, 'source_ceiling:getonboard')).toBe('WARN');
    expect(worst(rows)).toBe('WARN');
  });

  it('a sharp drop in visible listings alerts', () => {
    const i = base();
    i.visibleJobs = 8000;
    expect(status(evaluateHealth(i), 'visible_jobs')).toBe('WARN');
    i.visibleJobs = 4000;
    expect(status(evaluateHealth(i), 'visible_jobs')).toBe('ALERT');
  });

  it('the workflow is read-only: a daily schedule, one secret from the existing environment, no write tool, no other trigger', () => {
    const y = readFileSync(new URL('../../.github/workflows/ops-health.yml', import.meta.url), 'utf8').split(/\r?\n/).filter((l) => !l.trim().startsWith('#')).join('\n');
    expect([...y.matchAll(/- cron: '([^']+)'/g)].map((m) => m[1])).toEqual(['33 6 * * *']);
    expect(y).not.toMatch(/push:|pull_request|workflow_run|repository_dispatch/);
    expect(y).toMatch(/permissions:\n  contents: read/);
    expect(y).toMatch(/environment: jobicy-revalidation/);
    expect(y).toMatch(/ORBIJOB_WORKER_KEY: \$\{\{ secrets\.ORBIJOB_SYNC_WORKER_KEY \}\}/);
    expect(y).not.toMatch(/supabase db|wrangler|psql|ORBIJOB_SUPABASE_SECRET|SERVICE_ROLE/i);
    const script = readFileSync(new URL('../scripts/ops-health-remote.mjs', import.meta.url), 'utf8');
    expect(script).toMatch(/method: 'GET'/);
    expect(script).not.toMatch(/method: '(POST|PATCH|PUT|DELETE)'/);
  });
});
