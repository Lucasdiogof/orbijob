#!/usr/bin/env node
// Evaluates the JSON produced by inspect_predeploy_details.sql against what the five migrations need from the hosted
// project, and returns PRECHECK_OK or BLOCKED with one line per check. It reads facts; it never contacts the project.
//   node scripts/supabase/predeploy_check.mjs predeploy.json [--json] [--ack=function-rls_auto_enable,...]
// --ack: after READING an UNKNOWN item (for example the definition of a platform function) the owner may accept it by id.
// Exit codes: 0 = PRECHECK_OK, 2 = BLOCKED (any FAIL or UNKNOWN), 1 = usage/input error.
// PRECHECK_OK is a necessary condition only: applying still needs the state classification, a backup, a dry run and the
// owner's explicit authorization (apply.sh). It does not prove the migrations succeed on the hosted platform.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { unwrapExport } from './classify_state.mjs';

// Event triggers the Supabase platform is known to install (names only). Anything else is surfaced for review.
const KNOWN_EVENT_TRIGGERS = new Set([
  'ensure_rls', 'pgrst_ddl_watch', 'pgrst_drop_watch', 'issue_graphql_placeholder', 'issue_pg_cron_access',
  'issue_pg_graphql_access', 'issue_pg_net_access',
]);
// What the platform's auto-RLS function may do. Heuristic on purpose: every dynamic statement must be an
// "alter table ... enable row level security" and nothing that changes data, roles or privileges may appear.
// A body that does anything else is reported UNKNOWN so a human reads it.
const SUSPICIOUS = /\b(drop|grant|revoke|insert|delete|truncate|copy|create|set\s+role|reset\s+role|session_user|dblink|pg_read|lo_import)\b|\bupdate\s+[\w."]+\s+set\b|\balter\s+(role|user|function|default|system|database|schema|extension)\b/i;
function onlyEnablesRls(def) {
  const body = (def ?? '').replace(/^[\s\S]*?\bAS\b\s*\$[\w]*\$/i, '');
  const executes = (body.match(/\bexecute\b/gi) ?? []).length;
  const good = (body.match(/execute\s+format\s*\(\s*'alter table[^']*enable row level security/gi) ?? []).length;
  return executes >= 1 && executes === good && !SUSPICIOUS.test(body.replace(/'[^']*'/g, "''"));
}

export function parseDetails(text) {
  const v = unwrapExport(text);
  if (!v || v.predeploy_format !== 1 || !('postgres_role' in v)) throw new Error('not an OrbiJob pre-deploy details document (expected "predeploy_format": 1)');
  return v;
}

export function check(d, ack = []) {
  const out = [];
  const add = (id, status, what, why) => out.push({ id, status, what, why });
  const schema = (n) => (d.schemas ?? []).find((s) => s.name === n);
  const pg = d.postgres_role ?? {};
  const major = Math.floor((d.server_version_num ?? 0) / 10000);

  add('pg-version', major >= 15 ? 'PASS' : 'FAIL', `PostgreSQL ${d.server_version}`,
    major >= 15 ? 'migrations were tested on 16 and 17' : 'migrations were not tested below 15');

  add('runs-as-postgres', d.connected_as === 'postgres' ? 'PASS' : 'UNKNOWN', `inspection ran as ${d.connected_as}`,
    d.connected_as === 'postgres' ? 'same role the CLI uses for db push' : 'privileges below describe the role named "postgres" explicitly, but confirm the CLI connects as it');

  add('history-schema', pg.can_create_in_database || schema('supabase_migrations') ? 'PASS' : 'FAIL',
    'the CLI can create/use supabase_migrations', schema('supabase_migrations') ? 'schema already exists' : (pg.can_create_in_database ? 'postgres has CREATE on the database' : 'postgres cannot create schemas'));

  const trgm = d.pg_trgm ?? {};
  const avail = (trgm.available_versions ?? []).length > 0;
  const trusted = (trgm.available_versions ?? []).some((v) => v.trusted);
  add('pg_trgm-available', avail && (trusted || pg.superuser) ? 'PASS' : 'FAIL', 'pg_trgm can be installed by postgres',
    !avail ? 'extension not available on this server' : trusted || pg.superuser ? `trusted=${trusted}, superuser=${pg.superuser}` : 'extension is not trusted and postgres is not a superuser');
  const ext = schema('extensions');
  add('extensions-schema', ext?.postgres_create ? 'PASS' : 'FAIL', 'postgres may create objects in schema "extensions" (migration 3 moves pg_trgm there)',
    !ext ? 'schema "extensions" missing (migration 3 creates it, needs database CREATE)' : ext.postgres_create ? `owner ${ext.owner}` : `owner ${ext.owner}; postgres has no CREATE: "alter extension pg_trgm set schema extensions" would fail at migration 3, after 1 and 2 are applied`);
  const installed = trgm.installed;
  add('pg_trgm-target', installed ? (installed.owner === 'postgres' || pg.superuser ? 'PASS' : 'FAIL') : 'PASS',
    'where init will install pg_trgm', installed ? `already installed in ${installed.schema} owned by ${installed.owner}` : `CREATE EXTENSION without schema would use "${trgm.create_without_schema_would_use}" (then migration 3 moves it)`);

  const auth = d.auth ?? {};
  add('auth-users', auth.users_table_exists && auth.postgres_can_reference_users ? 'PASS' : 'FAIL', 'tables may reference auth.users(id)',
    !auth.users_table_exists ? 'auth.users missing' : auth.postgres_can_reference_users ? 'postgres has REFERENCES' : 'postgres lacks REFERENCES on auth.users: every foreign key to it would fail');
  add('auth-uid', auth.uid_function_exists && auth.authenticated_can_execute_uid ? 'PASS' : 'FAIL', 'auth.uid() exists and authenticated may execute it (used by every policy)',
    auth.uid_function_exists ? (auth.authenticated_can_execute_uid ? 'ok' : 'authenticated cannot execute auth.uid()') : 'auth.uid() missing');
  add('auth-user-triggers', (auth.user_triggers ?? []).length === 0 ? 'PASS' : 'UNKNOWN', 'no user triggers on auth.users', (auth.user_triggers ?? []).length ? `found: ${auth.user_triggers.join(', ')} (not OrbiJob's; the audit script would reject them)` : 'none');

  const st = d.storage ?? {};
  const cols = st.buckets_columns ?? [];
  add('storage-tables', st.buckets_exists && st.objects_exists ? 'PASS' : 'FAIL', 'storage.buckets and storage.objects exist', `buckets=${st.buckets_exists}, objects=${st.objects_exists}`);
  add('storage-bucket-columns', cols.includes('file_size_limit') && cols.includes('allowed_mime_types') ? 'PASS' : 'FAIL', 'storage.buckets has file_size_limit and allowed_mime_types', `columns: ${cols.join(', ') || 'none'}`);
  add('storage-insert-bucket', st.postgres_can_insert_buckets ? 'PASS' : 'FAIL', 'postgres may insert into storage.buckets (migration 3 creates the private "resumes" bucket)', st.postgres_can_insert_buckets ? 'yes' : 'no: the bucket would have to be created from the dashboard/Storage API instead');
  add('storage-update-bucket', st.postgres_can_update_buckets ? 'PASS' : 'UNKNOWN', 'postgres may update storage.buckets (the statement uses ON CONFLICT DO UPDATE)', String(st.postgres_can_update_buckets));
  add('storage-policies', st.objects_rls_enabled && st.postgres_is_objects_owner_or_member ? 'PASS' : 'FAIL', 'postgres may create policies on storage.objects (owner/member) and RLS is enabled',
    `objects owner=${st.objects_owner}, postgres owner-or-member=${st.postgres_is_objects_owner_or_member}, rls=${st.objects_rls_enabled}`);
  add('storage-foldername', st.foldername_exists ? 'PASS' : 'FAIL', 'storage.foldername(text) exists (the 4 policies use it)', String(st.foldername_exists));
  const existingPol = (st.objects_policies ?? []).filter((p) => p.startsWith('resumes_objects_'));
  add('storage-no-clash', existingPol.length === 0 && (d.orbijob_objects_present?.resumes_bucket ?? 0) === 0 ? 'PASS' : 'FAIL', 'no OrbiJob bucket/policies exist yet', existingPol.length ? `existing: ${existingPol.join(', ')}` : `resumes bucket rows: ${d.orbijob_objects_present?.resumes_bucket}`);

  const ets = d.event_triggers ?? [];
  const unknownEts = ets.filter((e) => !KNOWN_EVENT_TRIGGERS.has(e.name));
  add('event-triggers', unknownEts.length === 0 ? 'PASS' : 'UNKNOWN', 'every event trigger is a known platform one',
    unknownEts.length ? `unrecognised: ${unknownEts.map((e) => `${e.name} (${e.event}, ${e.function})`).join('; ')}` : `${ets.length} known: ${ets.map((e) => e.name).join(', ') || 'none'}`);

  for (const f of (d.public_functions_detail ?? [])) {
    if (['set_updated_at', 'log_application_stage', 'enforce_row_quota'].includes(f.name)) continue;
    const exposed = f.anon_can_execute || f.authenticated_can_execute;
    const bound = (f.bound_event_triggers ?? []).length > 0;
    const pinned = (f.config ?? []).some((c) => /^search_path=/.test(c));
    const body = f.definition ?? '';
    const looksLikeAutoRls = onlyEnablesRls(body);
    if (f.returns === 'event_trigger' && bound && pinned && f.security_definer && looksLikeAutoRls) {
      add(`function-${f.name}`, 'PASS', `public.${f.name}() is an event-trigger function bound to ${f.bound_event_triggers.join(', ')}`,
        `owner ${f.owner}, ${f.language}, search_path pinned, body only enables RLS. PostgreSQL refuses to call event-trigger functions as ordinary functions, so the EXECUTE grants to anon/authenticated cannot be used to run it (verified on the local engine). READ the definition below before accepting.`);
    } else {
      add(`function-${f.name}`, 'UNKNOWN', `public.${f.name}() is not an OrbiJob function`,
        `returns ${f.returns}, security_definer=${f.security_definer}, exposed to API roles=${exposed}, bound to event trigger=${bound}, search_path pinned=${pinned}, body only enables RLS=${looksLikeAutoRls}. A human must read its definition.`);
    }
  }

  const dp = d.default_privileges_public ?? [];
  const byPg = dp.filter((x) => x.created_by === 'postgres');
  const apiGrants = (t) => byPg.filter((x) => x.object_type === t && ['anon', 'authenticated', 'PUBLIC'].includes(x.grantee));
  add('default-privileges', 'PASS', 'default privileges for objects the migration role creates in public',
    `tables granted to API roles by default: ${[...new Set(apiGrants('table').map((x) => x.grantee))].join(', ') || 'none'} (migration 2 revokes them and grants back only what is needed); functions: ${[...new Set(apiGrants('function').map((x) => x.grantee))].join(', ') || 'none'} (each OrbiJob function revokes EXECUTE from PUBLIC/anon/authenticated right after creation). Objects created by supabase_admin are not affected by the migrations and OrbiJob creates none.`);

  const mh = d.migration_history ?? {};
  add('history-state', 'PASS', 'effective migration history', mh.table_exists ? `versions: ${(mh.versions ?? []).join(', ') || 'none'}` : 'no supabase_migrations.schema_migrations table: the CLI creates it on the first push');

  const present = d.orbijob_objects_present?.public_tables ?? [];
  add('no-orbijob-tables', present.length === 0 ? 'PASS' : 'UNKNOWN', 'no OrbiJob tables yet', present.length ? `present: ${present.join(', ')}` : 'none');

  // A human who has READ an UNKNOWN item may acknowledge it by id; FAIL can never be acknowledged.
  for (const c of out) if (c.status === 'UNKNOWN' && ack.includes(c.id)) { c.status = 'ACK'; c.why += ' [acknowledged by the owner]'; }
  const blocked = out.some((c) => c.status !== 'PASS' && c.status !== 'ACK');
  return { verdict: blocked ? 'BLOCKED' : 'PRECHECK_OK', checks: out, reviewDefinitions: (d.public_functions_detail ?? []).filter((f) => !['set_updated_at', 'log_application_stage', 'enforce_row_quota'].includes(f.name)).map((f) => ({ name: f.name, definition: f.definition })) };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const file = process.argv[2];
  if (!file) { console.error('usage: predeploy_check.mjs predeploy.json [--json]'); process.exit(1); }
  let r;
  const ack = (process.argv.find((a) => a.startsWith('--ack=')) ?? '--ack=').slice(6).split(',').filter(Boolean);
  try { r = check(parseDetails(readFileSync(file, 'utf8')), ack); } catch (e) { console.error(`cannot read ${file}: ${e.message}`); process.exit(1); }
  if (process.argv.includes('--json')) console.log(JSON.stringify(r, null, 2));
  else {
    console.log(`verdict: ${r.verdict}`);
    for (const c of r.checks) console.log(`${c.status.padEnd(7)} ${c.id}: ${c.what} — ${c.why}`);
    for (const f of r.reviewDefinitions) console.log(`\n--- definition to review: public.${f.name} ---\n${f.definition}`);
  }
  process.exit(r.verdict === 'PRECHECK_OK' ? 0 : 2);
}
