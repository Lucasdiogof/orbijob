import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

// The security of the free scheduler is in the workflow files. These checks read them as text (no network, no secrets).
const read = (f: string) => readFileSync(new URL(`../../.github/workflows/${f}`, import.meta.url), 'utf8');
const rv = read('jobicy-revalidate.yml');
const wd = read('jobicy-watchdog.yml');
const code = (t: string) => t.split(/\r?\n/).filter((l) => !l.trim().startsWith('#')).join('\n'); // comments may mention forbidden words
const steps = (t: string) => code(t).split(/\n(?=      - (?:name|uses):)/).slice(1);

describe('jobicy-revalidate.yml', () => {
  const c = code(rv);

  it('runs on ONE schedule, every 6 hours, away from minute 0, plus a manual run that is read-only by default', () => {
    const crons = [...c.matchAll(/- cron: '([^']+)'/g)].map((m) => m[1]!);
    expect(crons).toHaveLength(1);
    const [min, hour, ...rest] = crons[0]!.split(' ');
    expect(rest).toEqual(['*', '*', '*']);
    expect(Number(min)).toBeGreaterThan(0);
    expect(Number(min)).toBeLessThan(60);
    expect(hour).toBe('*/6');
    expect(c).toMatch(/workflow_dispatch:/);
    expect(c).toMatch(/default: check/);
    expect(c).toMatch(/options: \[check, revalidate\]/);
  });

  it('has no other trigger: not on push, not on pull_request (so it never runs on code from a PR)', () => {
    const on = c.slice(c.indexOf('\non:'), c.indexOf('\npermissions:'));
    expect(on).not.toMatch(/push:|pull_request|pull_request_target|workflow_run|issue_comment|repository_dispatch/);
  });

  it('is OFF by default: the scheduled run needs the repository variable JOBICY_REVALIDATION_ENABLED == \'true\'', () => {
    expect(c).toMatch(/if: github\.event_name == 'workflow_dispatch' \|\| vars\.JOBICY_REVALIDATION_ENABLED == 'true'/);
  });

  it('has minimal permissions, no overlap, and a timeout', () => {
    expect(c).toMatch(/^permissions:\n  contents: read\n/m);
    expect(c).not.toMatch(/(write|admin)\b/);
    expect(c).toMatch(/concurrency:\n  group: jobicy-revalidate\n  cancel-in-progress: false/);
    const t = Number(/timeout-minutes: (\d+)/.exec(c)![1]);
    expect(t).toBeGreaterThanOrEqual(5);
    expect(t).toBeLessThanOrEqual(15);
  });

  it('pins every action to a commit SHA, uses Node 22 and installs from the lockfile WITHOUT install scripts', () => {
    for (const m of c.matchAll(/uses: ([^\s]+)/g)) expect(m[1]).toMatch(/^[\w.-]+\/[\w.-]+@[0-9a-f]{40}$/);
    expect(c).toMatch(/node-version: 22/);
    expect(c).toMatch(/npm ci --ignore-scripts/);
    expect(c).toMatch(/persist-credentials: false/);
  });

  it('uses ONE secret, from the dedicated environment, and hands it only to the steps that need it (never to npm ci or to checkout)', () => {
    const refs = [...c.matchAll(/secrets\.([A-Z0-9_]+)/g)].map((m) => m[1]);
    expect(new Set(refs)).toEqual(new Set(['ORBIJOB_SYNC_WORKER_KEY']));
    expect(c).toMatch(/environment: jobicy-revalidation/);
    for (const s of steps(rv)) {
      const uses = s.includes('secrets.');
      const name = /name: (.+)/.exec(s)?.[1] ?? '';
      if (/Install dependencies|checkout|setup-node/i.test(name + s.split('\n')[0])) expect(uses, name).toBe(false);
    }
    expect(c).not.toMatch(/GITHUB_TOKEN|github\.token/); // nothing here needs it
    expect(c).not.toMatch(/SERVICE_ROLE|service_role|orbijob_ingest_local|ORBIJOB_REHEARSAL/);
  });

  it('can only revalidate: it calls the revalidation script and the read-only key check, never an ingestion or the full mode', () => {
    const scripts = [...c.matchAll(/node (scripts\/[\w.-]+\.mjs)/g)].map((m) => m[1]);
    expect(new Set(scripts)).toEqual(new Set(['scripts/worker-key-check.mjs', 'scripts/revalidate-local.mjs']));
    expect(c).not.toMatch(/SYNC_MODE|SYNC_MAX_NEW_JOBS|first-ingestion|worker-secrets|publish_jobicy|wrangler|supabase db|--prompt-key/);
    expect(c).toMatch(/revalidate-local\.mjs run --yes/);
  });

  it('keeps the secret out of logs and out of artifacts', () => {
    expect(c).toMatch(/::add-mask::\$KEY/);
    expect(c).not.toMatch(/upload-artifact|actions\/cache|set -x|\bsh -x|echo "?\$\{?(KEY|ORBIJOB_SUPABASE_SECRET|ORBIJOB_WORKER_KEY)/);
    expect(c).not.toMatch(/--debug|ACTIONS_STEP_DEBUG/);
  });

  it('labels the failure kinds for the monitor (exit codes 4, 5, 6) with steps named ALERT', () => {
    for (const k of ['auth', 'unreachable', 'api']) expect(c).toMatch(new RegExp(`name: 'ALERT ${k}:`));
    expect(c).toMatch(/steps\.rv\.outputs\.code == '4'/);
    expect(c).toMatch(/steps\.rv\.outputs\.code == '5'/);
    expect(c).toMatch(/steps\.rv\.outputs\.code == '6'/);
  });

  it('the real revalidation runs only on schedule or when asked for explicitly', () => {
    expect(c).toMatch(/if: github\.event_name == 'schedule' \|\| inputs\.action == 'revalidate'/);
  });
});

describe('jobicy-watchdog.yml', () => {
  const c = code(wd);
  it('has no secret at all, minimal permissions (read runs, write ONE issue) and a free-tier-sized schedule', () => {
    expect(c).not.toMatch(/secrets\./);
    expect(c).toMatch(/^permissions:\n  contents: read\n  actions: read\n  issues: write\n/m);
    expect(c).not.toMatch(/contents: write|actions: write|pull-requests|id-token/);
    expect([...c.matchAll(/- cron: '([^']+)'/g)]).toHaveLength(1);
    expect(c).toMatch(/cron: '43 5,17 \* \* \*'/);
    expect(c).toMatch(/timeout-minutes: 5/);
  });
  it('runs only once the public publishable key variable is set, pins its actions and installs nothing', () => {
    expect(c).toMatch(/if: vars\.SUPABASE_PUBLISHABLE_KEY != ''/);
    for (const m of c.matchAll(/uses: ([^\s]+)/g)) expect(m[1]).toMatch(/@[0-9a-f]{40}$/);
    expect(c).not.toMatch(/npm (ci|install)/);
    expect(c).not.toMatch(/on:[\s\S]*pull_request/);
  });
});
