#!/usr/bin/env node
// Classifies the JSON produced by inspect_readonly.sql against the OrbiJob migrations.
//   node scripts/supabase/classify_state.mjs inspection.json [--json]
// Exit codes: 0 = EMPTY or CONSISTENT (safe to plan the pending migrations), 2 = DRIFT (stop and review), 1 = usage error.
// It decides nothing on its own authority: it only refuses to call a database "safe" unless history and catalog agree.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const MIGRATIONS = [
  { version: '20261008000000', name: 'init' },
  { version: '20261009000000', name: 'rls_hardening' },
  { version: '20261010000000', name: 'app_integration' },
  { version: '20261011000000', name: 'quotas' },
  { version: '20261012000000', name: 'quota_upsert_fix' },
];

const OWN_TABLES = [
  'job_sources', 'jobs', 'job_clusters', 'sync_runs', 'professional_profiles', 'experiences', 'education',
  'credentials', 'resumes', 'saved_jobs', 'saved_searches', 'viewed_jobs', 'applications', 'application_events',
  'reminders', 'user_preferences',
];

/** Which migrations leave their fingerprint in the catalog (independent of the history table). */
function signatures(i) {
  const tables = new Set(i.public_tables.map((t) => t.name));
  const policies = new Set(i.public_policies.map((p) => `${p.table}.${p.name}`));
  const triggers = new Set(i.public_triggers.map((t) => `${t.table}.${t.name}`));
  const fn = i.public_functions.find((f) => f.name === 'enforce_row_quota');
  const buckets = i.storage_buckets ?? [];
  return [
    tables.has('jobs') && tables.has('applications'),
    policies.has('education.education_parent'),
    tables.has('user_preferences') && buckets.some((b) => b.id === 'resumes'),
    triggers.has('resumes.resumes_quota'),
    Boolean(fn?.quota_has_key_arg),
  ];
}

export function classify(i) {
  const problems = [];
  const warnings = [];
  const history = i.migration_versions; // null = no history table
  const known = MIGRATIONS.map((m) => m.version);
  const applied = history ?? [];

  const unknownVersions = applied.filter((v) => !known.includes(v));
  if (unknownVersions.length) problems.push(`history contains versions that are not OrbiJob's: ${unknownVersions.join(', ')}`);

  const ownPresent = i.public_tables.filter((t) => OWN_TABLES.includes(t.name)).map((t) => t.name);
  const foreign = i.public_tables.filter((t) => !OWN_TABLES.includes(t.name)).map((t) => t.name);
  if (foreign.length) problems.push(`public schema already has tables that are not OrbiJob's: ${foreign.join(', ')}`);

  const sig = signatures(i);
  const prefixLen = known.filter((v, k) => applied[k] === v).length;
  const historyIsPrefix = applied.length === prefixLen;
  if (!historyIsPrefix) problems.push(`history is not a prefix of the expected order (found: ${applied.join(', ') || 'none'})`);

  for (let k = 0; k < MIGRATIONS.length; k++) {
    const inHistory = k < prefixLen;
    if (inHistory && !sig[k]) problems.push(`migration ${MIGRATIONS[k].name} is in the history but its objects are missing`);
    if (!inHistory && sig[k]) problems.push(`objects of migration ${MIGRATIONS[k].name} exist but the history does not list it (applied by hand?)`);
  }

  const nothingOurs = ownPresent.length === 0 && applied.length === 0 && !sig.some(Boolean);
  if (nothingOurs) {
    if ((i.extensions ?? []).some((e) => e.name === 'pg_trgm')) warnings.push('pg_trgm is already installed: confirm it is owned by the migration role (migration 3 moves it to schema "extensions")');
    if (history === null) warnings.push('supabase_migrations.schema_migrations does not exist yet (normal for a project that never ran migrations)');
  }
  if ((i.auth_users_triggers ?? []).length) warnings.push(`user triggers exist on auth.users: ${i.auth_users_triggers.join(', ')} (not created by OrbiJob; review)`);
  if (!/^1[5-9]/.test(String(i.server_version))) warnings.push(`PostgreSQL ${i.server_version}: migrations were tested on 16`);

  const pending = problems.length ? null : MIGRATIONS.slice(prefixLen).map((m) => `${m.version}_${m.name}`);
  const state = problems.length ? 'DRIFT' : nothingOurs ? 'EMPTY' : pending.length === 0 ? 'CONSISTENT_UP_TO_DATE' : 'CONSISTENT_PARTIAL';
  return { state, safeToPlan: !problems.length, appliedCount: prefixLen, pending, problems, warnings };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const file = process.argv[2];
  if (!file) { console.error('usage: classify_state.mjs inspection.json [--json]'); process.exit(1); }
  const r = classify(JSON.parse(readFileSync(file, 'utf8')));
  if (process.argv.includes('--json')) console.log(JSON.stringify(r, null, 2));
  else {
    console.log(`state: ${r.state}`);
    console.log(`pending: ${r.pending ? (r.pending.join(', ') || 'none') : 'UNKNOWN (resolve the problems first)'}`);
    for (const p of r.problems) console.log(`PROBLEM: ${p}`);
    for (const w of r.warnings) console.log(`warning: ${w}`);
  }
  process.exit(r.safeToPlan ? 0 : 2);
}
