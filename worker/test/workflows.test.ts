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

describe('jobicy-discover.yml', () => {
  const d = read('jobicy-discover.yml');
  const c = code(d);

  it('is OFF by default: the schedule needs JOBICY_DISCOVERY_ENABLED == \'true\', and a manual import needs the typed confirmation', () => {
    expect(c).toMatch(/if: github\.event_name == 'workflow_dispatch' \|\| vars\.JOBICY_DISCOVERY_ENABLED == 'true'/);
    expect(c).toMatch(/default: check/);
    expect(c).toMatch(/options: \[check, preview, discover\]/);
    expect(c).toMatch(/inputs\.action == 'discover' && inputs\.confirm == 'IMPORTAR-NOVAS-VAGAS'/);
    // the import step is never reachable by a plain run: only the schedule (already gated above) or the confirmed manual run
    const discoverStep = steps(d).find((s) => s.includes('discover-local.mjs run --yes'))!;
    expect(discoverStep).toMatch(/if: github\.event_name == 'schedule' \|\| \(inputs\.action == 'discover'/);
  });

  it('runs 4 times a day at minute 47, three hours away from the revalidation, and has no other trigger', () => {
    const crons = [...c.matchAll(/- cron: '([^']+)'/g)].map((m) => m[1]!);
    expect(crons).toEqual(['47 3,9,15,21 * * *']);
    const rvHours = /- cron: '17 \*\/6/.test(rv) ? [0, 6, 12, 18] : [];
    for (const h of [3, 9, 15, 21]) for (const r of rvHours) expect(Math.abs(h - r)).toBeGreaterThanOrEqual(3);
    const on = c.slice(c.indexOf('\non:'), c.indexOf('\npermissions:'));
    expect(on).not.toMatch(/push:|pull_request|pull_request_target|workflow_run|issue_comment|repository_dispatch/);
  });

  it('has minimal permissions, no overlap, a timeout, pinned actions, Node 22 and a lockfile install without scripts', () => {
    expect(c).toMatch(/^permissions:\n  contents: read\n/m);
    expect(c).not.toMatch(/(write|admin)\b/);
    expect(c).toMatch(/concurrency:\n  group: jobicy-discover\n  cancel-in-progress: false/);
    expect(Number(/timeout-minutes: (\d+)/.exec(c)![1])).toBeLessThanOrEqual(15);
    for (const m of c.matchAll(/uses: ([^\s]+)/g)) expect(m[1]).toMatch(/^[\w.-]+\/[\w.-]+@[0-9a-f]{40}$/);
    expect(c).toMatch(/node-version: 22/);
    expect(c).toMatch(/npm ci --ignore-scripts/);
    expect(c).toMatch(/persist-credentials: false/);
  });

  it('uses ONE secret, from the dedicated environment, never in install/checkout steps; no legacy or local-ingestion key', () => {
    expect(new Set([...c.matchAll(/secrets\.([A-Z0-9_]+)/g)].map((m) => m[1]))).toEqual(new Set(['ORBIJOB_SYNC_WORKER_KEY']));
    expect(c).toMatch(/environment: jobicy-revalidation/);
    for (const s of steps(d)) {
      const name = /name: (.+)/.exec(s)?.[1] ?? '';
      if (/Install dependencies|checkout|setup-node/i.test(name + s.split('\n')[0])) expect(s.includes('secrets.'), name).toBe(false);
    }
    expect(c).not.toMatch(/GITHUB_TOKEN|github\.token|SERVICE_ROLE|service_role|orbijob_ingest_local|ORBIJOB_REHEARSAL/);
    expect(c).toMatch(/::add-mask::\$KEY/);
    expect(c).not.toMatch(/upload-artifact|actions\/cache|set -x|\bsh -x|--debug|ACTIONS_STEP_DEBUG/);
  });

  it('can only discover: it calls the discovery script and the read-only key check; no full mode, no first ingestion, no deploy, no database command', () => {
    const scripts = [...c.matchAll(/node (scripts\/[\w.-]+\.mjs)/g)].map((m) => m[1]);
    expect(new Set(scripts)).toEqual(new Set(['scripts/worker-key-check.mjs', 'scripts/discover-local.mjs']));
    expect(c).not.toMatch(/SYNC_MODE|SYNC_MAX_NEW_JOBS|first-ingestion|worker-secrets|publish_jobicy|wrangler|supabase db|--prompt-key|revalidate-local/);
  });

  it('labels the failure kinds with steps named ALERT (exit codes 4, 5, 6)', () => {
    for (const k of ['auth', 'unreachable', 'api']) expect(c).toMatch(new RegExp(`name: 'ALERT ${k}:`));
    expect(c).toMatch(/steps\.rv\.outputs\.code == '4'/);
    expect(c).toMatch(/steps\.rv\.outputs\.code == '5'/);
    expect(c).toMatch(/steps\.rv\.outputs\.code == '6'/);
    expect(c).toMatch(/name: 'ALERT storage:/);
    expect(c).toMatch(/steps\.rv\.outputs\.code == '7'/);
  });
});

describe('every workflow file is valid YAML in the places a plain scalar breaks it', () => {
  // GitHub rejects the whole file ("workflow file issue": no trigger, no run) when a plain scalar contains ": " or " #".
  // This caught nothing before because the other tests read the files as text. No YAML parser is installed, so the known failure class is checked directly.
  for (const f of ['ci.yml', 'jobicy-revalidate.yml', 'jobicy-watchdog.yml', 'jobicy-discover.yml', 'sources-discover.yml', 'sources-revalidate.yml', 'windows-bootstrap.yml']) {
    it(`${f}: unquoted name/description/if values contain no ': ' and no ' #'`, () => {
      const bad = read(f).split(/\r?\n/).filter((l) => /^\s*(- )?(name|description|if):\s+/.test(l))
        .map((l) => /^\s*(?:- )?(?:name|description|if):\s+(.*)$/.exec(l)![1]!)
        .filter((v) => !/^['"|>]/.test(v) && (/: /.test(v) || / #/.test(v)));
      expect(bad).toEqual([]);
    });
  }
});

describe('sources-discover.yml', () => {
  const d = read('sources-discover.yml');
  const c = code(d);

  it('is OFF by default: the schedule needs SOURCES_DISCOVERY_ENABLED == \'true\', and a manual import needs the typed confirmation', () => {
    expect(c).toMatch(/if: github\.event_name == 'workflow_dispatch' \|\| vars\.SOURCES_DISCOVERY_ENABLED == 'true'/);
    expect(c).toMatch(/default: check/);
    expect(c).toMatch(/options: \[check, preview, discover\]/);
    expect(c).toMatch(/options: \[arbeitnow, remoteok, remotive, jobtech, twjobs, jobsconz, getonboard, teachingvacancies, nycjobs, karrierenrw\]/);
    const step = steps(d).find((s) => s.includes('discover-local.mjs run --yes'))!;
    expect(step).toMatch(/if: github\.event_name == 'schedule' \|\| \(inputs\.action == 'discover' && inputs\.confirm == 'IMPORTAR-NOVAS-VAGAS'\)/);
  });

  it('every schedule maps to exactly one source, with the cadence each source\'s own rules allow (Remotive: at most once a day)', () => {
    const crons = [...c.matchAll(/- cron: '([^']+)'/g)].map((m) => m[1]!);
    expect(crons).toEqual(['23 2,8,14,20 * * *', '41 5,17 * * *', '53 6 * * *', '31 3,9,15,21 * * *', '37 5,11,17,23 * * *', '13 0,6,12,18 * * *', '27 8,20 * * *', '51 10,22 * * *', '43 1,19 * * *', '16 7 * * *', '5 3,9,15,21 * * *', '33 4,16 * * *', '9 10,22 * * *', '38 1,7,13,19 * * *', '12 4,10,16,22 * * *', '48 6,18 * * *', '14 12 * * *', '36 5,17 * * *', '8 11,23 * * *']);
    expect(c).toMatch(/'23 2,8,14,20 \* \* \*'\) s=arbeitnow/);
    expect(c).toMatch(/'41 5,17 \* \* \*'\)\s+s=remoteok/);
    expect(c).toMatch(/'53 6 \* \* \*'\)\s+s=remotive/);
    expect(c).toMatch(/'31 3,9,15,21 \* \* \*'\)\s+s=jobtech/);
    const on = c.slice(c.indexOf('\non:'), c.indexOf('\npermissions:'));
    expect(on).not.toMatch(/push:|pull_request|pull_request_target|workflow_run|issue_comment|repository_dispatch/);
    for (const cron of crons) expect(Number(cron.split(' ')[0])).toBeGreaterThan(0); // never minute 0
  });

  it('keeps away from the Jobicy minutes (03:47 ... 21:47) and from the revalidation (xx:17 + collect)', () => {
    for (const m of c.matchAll(/- cron: '(\d+) ([\d,]+) /g)) {
      const minute = Number(m[1]);
      expect([17, 19, 21, 24, 29, 44, 47]).not.toContain(minute);
    }
  });

  it('has minimal permissions, no overlap, a timeout, pinned actions, Node 22 and a lockfile install without scripts', () => {
    expect(c).toMatch(/^permissions:\n  contents: read\n/m);
    expect(c).not.toMatch(/(write|admin)\b/);
    expect(c).toMatch(/concurrency:\n  group: sources-discover\n  cancel-in-progress: false/);
    expect(Number(/timeout-minutes: (\d+)/.exec(c)![1])).toBeLessThanOrEqual(15);
    for (const m of c.matchAll(/uses: ([^\s]+)/g)) expect(m[1]).toMatch(/^[\w.-]+\/[\w.-]+@[0-9a-f]{40}$/);
    expect(c).toMatch(/node-version: 22/);
    expect(c).toMatch(/npm ci --ignore-scripts/);
    expect(c).toMatch(/persist-credentials: false/);
  });

  it('uses ONE secret, from the dedicated environment, never in install/checkout/source-choice steps; no legacy or local-ingestion key', () => {
    expect(new Set([...c.matchAll(/secrets\.([A-Z0-9_]+)/g)].map((m) => m[1]))).toEqual(new Set(['ORBIJOB_SYNC_WORKER_KEY']));
    expect(c).toMatch(/environment: jobicy-revalidation/);
    for (const s of steps(d)) {
      const name = /name: (.+)/.exec(s)?.[1] ?? '';
      if (/Install dependencies|checkout|setup-node|Choose the source/i.test(name + s.split('\n')[0])) expect(s.includes('secrets.'), name).toBe(false);
    }
    expect(c).not.toMatch(/GITHUB_TOKEN|github\.token|SERVICE_ROLE|service_role|orbijob_ingest_local|ORBIJOB_REHEARSAL/);
    expect(c).toMatch(/::add-mask::\$KEY/);
    expect(c).not.toMatch(/upload-artifact|actions\/cache|set -x|\bsh -x|--debug|ACTIONS_STEP_DEBUG/);
  });

  it('can only discover: the discovery script and the read-only key check; the source name is validated against a closed list', () => {
    const scripts = [...c.matchAll(/node (scripts\/[\w.-]+\.mjs)/g)].map((m) => m[1]);
    expect(new Set(scripts)).toEqual(new Set(['scripts/worker-key-check.mjs', 'scripts/discover-local.mjs']));
    expect(c).not.toMatch(/SYNC_MODE|SYNC_MAX_NEW_JOBS|first-ingestion|worker-secrets|publish_|wrangler|supabase db|--prompt-key|revalidate-local/);
    expect(c).toMatch(/case "\$s" in arbeitnow\|remoteok\|remotive\|jobtech\|twjobs\|jobsconz\|getonboard\|teachingvacancies\|nycjobs\|karrierenrw\) ;; \*\) .*exit 1/);
  });

  it('labels the failure kinds with steps named ALERT (exit codes 4, 5, 6, 7)', () => {
    for (const k of ['auth', 'unreachable', 'storage', 'api']) expect(c).toMatch(new RegExp(`name: 'ALERT ${k}:`));
    for (const n of ['4', '5', '6', '7']) expect(c).toMatch(new RegExp(`steps\.rv\.outputs\.code == '${n}'`));
  });
});

describe('sources-revalidate.yml (Platsbanken freshness)', () => {
  const c = code(read('sources-revalidate.yml'));

  it('is OFF by default: the schedule needs SOURCES_REVALIDATION_ENABLED is true; a manual run is read-only unless asked', () => {
    expect(c).toMatch(/if: github\.event_name == 'workflow_dispatch' \|\| vars\.SOURCES_REVALIDATION_ENABLED == 'true'/);
    expect(c).toMatch(/default: check/);
    expect(c).toMatch(/if: github\.event_name == 'schedule' \|\| inputs\.action == 'revalidate'/);
  });

  it('runs 4 times a day at minute 47 (hours 4/10/16/22), hours that never meet the Platsbanken discovery (03/09/15/21:31) nor the Jobicy cron (minute 17)', () => {
    const crons = [...c.matchAll(/- cron: '([^']+)'/g)].map((m) => m[1]!);
    expect(crons).toEqual(['47 4,10,16,22 * * *']);
    const d = code(read('sources-discover.yml'));
    expect(d).toMatch(/'31 3,9,15,21 \* \* \*'\)\s+s=jobtech/);
  });

  it('can only revalidate the Platsbanken: a fixed source, the revalidation script and the read-only key check, in its own concurrency group', () => {
    expect(c).toMatch(/ORBIJOB_SOURCE: jobtech/);
    const scripts = [...c.matchAll(/node (scripts\/[\w.-]+\.mjs)/g)].map((m) => m[1]);
    expect(new Set(scripts)).toEqual(new Set(['scripts/worker-key-check.mjs', 'scripts/revalidate-local.mjs']));
    expect(c).not.toMatch(/SYNC_MODE|SYNC_MAX_NEW_JOBS|first-ingestion|discover-local|worker-secrets|publish_|wrangler|supabase db|--prompt-key/);
    expect(c).toMatch(/concurrency:\n  group: sources-revalidate\n  cancel-in-progress: false/);
    expect(c).toMatch(/environment: jobicy-revalidation/);
    expect(c).toMatch(/permissions:\n  contents: read/);
  });

  it('the secret reaches only the steps that use it, and every action is pinned to a commit', () => {
    for (const st of steps(read('sources-revalidate.yml'))) {
      const gets = /secrets\.ORBIJOB_SYNC_WORKER_KEY/.test(st);
      const uses = /node scripts\/(worker-key-check|revalidate-local)\.mjs/.test(st) || /KEY: \$\{\{/.test(st);
      if (gets) expect(uses).toBe(true);
    }
    for (const m of c.matchAll(/uses: ([^\s]+)/g)) expect(m[1]).toMatch(/@[0-9a-f]{40}$/);
  });

  it('labels the failure kinds with ALERT steps (exit codes 4, 5, 6)', () => {
    for (const k of ['auth', 'unreachable', 'api']) expect(c).toMatch(new RegExp(`name: 'ALERT ${k}:`));
  });
});
