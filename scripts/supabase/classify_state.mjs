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
  { version: '20261013000000', name: 'service_role_grants' },
  { version: '20261014000000', name: 'service_role_least_privilege' },
];

const OWN_FUNCTIONS = ['set_updated_at', 'log_application_stage', 'enforce_row_quota'];
// Functions the Supabase platform itself installs in `public`. Known by name only: the inspection must still be backed by
// inspect_predeploy_details.sql (return type, event trigger binding, definition) before the apply is called ready.
const PLATFORM_FUNCTIONS = {
  rls_auto_enable: 'Supabase "automatically enable RLS" event-trigger function',
};

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
    // service_role can read the catalogue (a grant: invisible to the objects above). Until migration 6 it only has TRUNCATE/REFERENCES/TRIGGER.
    (i.public_grants ?? []).some((g) => g.role === 'service_role' && g.table === 'jobs' && (g.privileges ?? []).includes('SELECT')),
    // migration 7 takes DELETE on jobs away again (the role still reads and writes the catalogue, but can no longer erase it)
    (i.public_grants ?? []).some((g) => g.role === 'service_role' && g.table === 'jobs' && (g.privileges ?? []).includes('SELECT') && !(g.privileges ?? []).includes('DELETE')),
  ];
}

/**
 * Accepts what people actually have after copying the SQL Editor result: the bare JSON text, a UTF-8 BOM, a CSV-quoted
 * cell ("{""format"": 1 ...}"), the editor's JSON export ([{"inspection": "<json text>"}] or [{"inspection": {...}}]),
 * or the object itself. Anything else is rejected with a clear message instead of being guessed.
 */
export function unwrapExport(text) {
  let t = String(text).replace(/^\uFEFF/, '').trim();
  if (t.startsWith('"') && t.endsWith('"')) t = t.slice(1, -1).replace(/""/g, '"');
  let v = JSON.parse(t);
  if (Array.isArray(v) && v.length === 1 && v[0] && typeof v[0] === 'object') v = v[0];
  if (v && typeof v === 'object' && !Array.isArray(v) && Object.keys(v).length === 1 && typeof Object.values(v)[0] !== 'number') v = Object.values(v)[0];
  if (typeof v === 'string') v = JSON.parse(v);
  return v;
}

export function parseInspection(text) {
  const v = unwrapExport(text);
  if (!v || v.format !== 1 || !Array.isArray(v.public_tables)) throw new Error('not an OrbiJob inspection document (expected "format": 1 and "public_tables")');
  return v;
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

  const exceptions = [];
  const blockers = [];
  const evidence = [];
  for (const f of i.public_functions) {
    if (OWN_FUNCTIONS.includes(f.name)) continue;
    if (f.name in PLATFORM_FUNCTIONS) {
      const exposed = f.anon_can_execute || f.authenticated_can_execute;
      exceptions.push(`public.${f.name}: ${PLATFORM_FUNCTIONS[f.name]} (by name). security_definer=${f.security_definer}, anon_can_execute=${f.anon_can_execute}, authenticated_can_execute=${f.authenticated_can_execute}`);
      if (f.security_definer && exposed) blockers.push(`public.${f.name} is SECURITY DEFINER and executable by API roles: confirm with inspect_predeploy_details.sql that it returns event_trigger and is bound to an event trigger (then it cannot be called as a normal function) before applying`);
      continue;
    }
    problems.push(`public schema already has a function that is neither OrbiJob's nor a known platform function: public.${f.name}`);
  }
  const acl = i.default_privileges_public ?? [];
  const aclOwners = [...new Set(acl.map((a) => a.owner))].sort();
  if (aclOwners.length) evidence.push(`default privileges in public exist for role(s): ${aclOwners.join(', ')} (the migrations revoke only the ones of the role that runs them)`);
  const strange = aclOwners.filter((o) => !['postgres', 'supabase_admin'].includes(o));
  if (strange.length) warnings.push(`default privileges defined for unexpected role(s): ${strange.join(', ')}`);

  const nothingOurs = ownPresent.length === 0 && applied.length === 0 && !sig.some(Boolean);
  if (nothingOurs) {
    if ((i.extensions ?? []).some((e) => e.name === 'pg_trgm')) warnings.push('pg_trgm is already installed: confirm it is owned by the migration role (migration 3 moves it to schema "extensions")');
    if (history === null) {
      evidence.push('migration_versions is null: the history table supabase_migrations.schema_migrations does not exist. Alone that proves nothing; together with zero OrbiJob tables, policies, triggers, buckets and migration objects it means nothing was applied (the CLI creates the table on the first push)');
      if (!(i.schemas ?? []).includes('supabase_migrations')) evidence.push('schema supabase_migrations is absent as well, consistent with a project that never ran migrations');
    }
    evidence.push(`public tables: ${i.public_tables.length}, policies: ${i.public_policies.length}, triggers: ${i.public_triggers.length}, buckets: ${(i.storage_buckets ?? []).length}, storage policies: ${i.storage_policies.length}`);
  }
  if ((i.auth_users_triggers ?? []).length) warnings.push(`user triggers exist on auth.users: ${i.auth_users_triggers.join(', ')} (not created by OrbiJob; review)`);
  if (!/^1[5-9]/.test(String(i.server_version))) warnings.push(`PostgreSQL ${i.server_version}: migrations were tested on 16`);

  const pending = problems.length ? null : MIGRATIONS.slice(prefixLen).map((m) => `${m.version}_${m.name}`);
  const state = problems.length ? 'DRIFT' : nothingOurs ? 'EMPTY' : pending.length === 0 ? 'CONSISTENT_UP_TO_DATE' : 'CONSISTENT_PARTIAL';
  if (history === null && !nothingOurs && !problems.length) blockers.push('no history table but OrbiJob objects exist');
  return { state, safeToPlan: !problems.length, appliedCount: prefixLen, pending, problems, warnings, exceptions, blockers, evidence };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const file = process.argv[2];
  if (!file) { console.error('usage: classify_state.mjs inspection.json [--json]'); process.exit(1); }
  let doc;
  try { doc = parseInspection(readFileSync(file, 'utf8')); } catch (e) { console.error(`cannot read ${file}: ${e.message}`); process.exit(1); }
  const r = classify(doc);
  if (process.argv.includes('--json')) console.log(JSON.stringify(r, null, 2));
  else {
    console.log(`state: ${r.state}`);
    console.log(`pending: ${r.pending ? (r.pending.join(', ') || 'none') : 'UNKNOWN (resolve the problems first)'}`);
    for (const p of r.problems) console.log(`PROBLEM: ${p}`);
    for (const e of r.evidence) console.log(`evidence: ${e}`);
    for (const e of r.exceptions) console.log(`exception: ${e}`);
    for (const b of r.blockers) console.log(`BLOCKER-FOR-APPLY: ${b}`);
    for (const w of r.warnings) console.log(`warning: ${w}`);
  }
  process.exit(r.safeToPlan ? 0 : 2);
}
