import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { check, parseDetails } from './predeploy_check.mjs';

// Baseline = details collected from the LOCAL PostgreSQL 17 stub (platform-like, not the hosted project).
const base = () => JSON.parse(readFileSync(new URL('./fixtures/predeploy-local-stub-pg17.json', import.meta.url), 'utf8'));
const status = (d, id) => check(d).checks.find((c) => c.id === id)?.status;
const fn = (d) => d.public_functions_detail.find((f) => f.name === 'rls_auto_enable');

test('baseline (platform-like local stub) passes every precheck', () => {
  const r = check(base());
  assert.equal(r.verdict, 'PRECHECK_OK', JSON.stringify(r.checks.filter((c) => c.status !== 'PASS')));
  assert.equal(r.reviewDefinitions.length, 1);
});

test('the SQL Editor export shapes of the details document are accepted', () => {
  const d = base();
  assert.equal(parseDetails(JSON.stringify([{ details: JSON.stringify(d, null, 4) }])).predeploy_format, 1);
  assert.equal(parseDetails(JSON.stringify([{ details: d }])).predeploy_format, 1);
  assert.equal(parseDetails('"' + JSON.stringify(d).replace(/"/g, '""') + '"').predeploy_format, 1);
  assert.throws(() => parseDetails('{"format":1,"public_tables":[]}'), /pre-deploy details/);
});

const breakIt = {
  'old PostgreSQL': [(d) => { d.server_version_num = 140000; d.server_version = '14.0'; }, 'pg-version', 'FAIL'],
  'postgres cannot create in schema extensions': [(d) => { d.schemas.find((s) => s.name === 'extensions').postgres_create = false; }, 'extensions-schema', 'FAIL'],
  'pg_trgm not available': [(d) => { d.pg_trgm.available_versions = []; }, 'pg_trgm-available', 'FAIL'],
  'pg_trgm untrusted and postgres not superuser': [(d) => { d.pg_trgm.available_versions.forEach((v) => (v.trusted = false)); d.postgres_role.superuser = false; }, 'pg_trgm-available', 'FAIL'],
  'pg_trgm already installed by another owner': [(d) => { d.pg_trgm.installed = { schema: 'extensions', owner: 'supabase_admin', version: '1.6' }; d.postgres_role.superuser = false; }, 'pg_trgm-target', 'FAIL'],
  'no REFERENCES on auth.users': [(d) => { d.auth.postgres_can_reference_users = false; }, 'auth-users', 'FAIL'],
  'authenticated cannot execute auth.uid()': [(d) => { d.auth.authenticated_can_execute_uid = false; }, 'auth-uid', 'FAIL'],
  'foreign trigger on auth.users': [(d) => { d.auth.user_triggers = ['on_signup_x']; }, 'auth-user-triggers', 'UNKNOWN'],
  'bucket columns missing': [(d) => { d.storage.buckets_columns = ['id', 'name']; }, 'storage-bucket-columns', 'FAIL'],
  'postgres cannot insert buckets': [(d) => { d.storage.postgres_can_insert_buckets = false; }, 'storage-insert-bucket', 'FAIL'],
  'postgres cannot create policies on storage.objects': [(d) => { d.storage.postgres_is_objects_owner_or_member = false; d.storage.objects_owner = 'supabase_storage_admin'; }, 'storage-policies', 'FAIL'],
  'storage.foldername missing': [(d) => { d.storage.foldername_exists = false; }, 'storage-foldername', 'FAIL'],
  'resumes policies already exist': [(d) => { d.storage.objects_policies = ['resumes_objects_select']; }, 'storage-no-clash', 'FAIL'],
  'resumes bucket already exists': [(d) => { d.orbijob_objects_present.resumes_bucket = 1; }, 'storage-no-clash', 'FAIL'],
  'unknown event trigger': [(d) => { d.event_triggers.push({ name: 'block_ddl', event: 'ddl_command_start', tags: null, enabled: 'O', owner: 'x', function: 'public.block' }); }, 'event-triggers', 'UNKNOWN'],
  'OrbiJob tables already present': [(d) => { d.orbijob_objects_present.public_tables = ['jobs']; }, 'no-orbijob-tables', 'UNKNOWN'],
};
for (const [name, [mutate, id, expected]] of Object.entries(breakIt)) {
  test(`blocked when: ${name}`, () => {
    const d = base(); mutate(d);
    assert.equal(status(d, id), expected);
    assert.equal(check(d).verdict, 'BLOCKED');
  });
}

test('pg_trgm target follows the FIRST schema of the resolved search_path, like PostgreSQL does', () => {
  let d = base(); d.pg_trgm.create_without_schema_would_use = 'extensions'; d.pg_trgm.create_without_schema_can_create = true;
  d.search_path_schemas = [{ position: 1, name: 'extensions' }, { position: 2, name: 'public' }];
  assert.equal(status(d, 'pg_trgm-target'), 'PASS');
  assert.match(check(d).checks.find((c) => c.id === 'pg_trgm-target').why, /"extensions".*extensions, public/);
  d = base(); d.pg_trgm.create_without_schema_would_use = 'extensions'; d.pg_trgm.create_without_schema_can_create = false; d.pg_trgm.first_creatable_schema_in_path = 'public';
  assert.equal(status(d, 'pg_trgm-target'), 'FAIL');   // no fallback to the next schema, even though public would work
  d = base(); d.pg_trgm.create_without_schema_would_use = null; d.pg_trgm.create_without_schema_can_create = null; d.search_path_schemas = [];
  assert.equal(status(d, 'pg_trgm-target'), 'FAIL');
  d = base(); delete d.pg_trgm.create_without_schema_would_use; delete d.pg_trgm.create_without_schema_can_create;
  assert.equal(status(d, 'pg_trgm-target'), 'UNKNOWN'); // an old-format document is never silently accepted
});

const suspiciousBodies = {
  'drops a table': "execute 'drop table public.x';",
  'grants privileges': "execute format('grant all on %s to anon', cmd.object_identity);",
  'inserts data': "insert into public.audit values (1); execute format('alter table %s enable row level security', cmd.object_identity);",
  'extra dynamic statement': "execute format('alter table %s enable row level security', cmd.object_identity); execute 'select 1';",
  'creates a role': "execute format('alter table %s enable row level security', cmd.object_identity); create role evil;",
};
for (const [name, extra] of Object.entries(suspiciousBodies)) {
  test(`the platform function is not accepted when its body ${name}`, () => {
    const d = base();
    const f = fn(d);
    f.definition = f.definition.replace(/execute format[\s\S]*?\);/, extra);
    assert.equal(status(d, 'function-rls_auto_enable'), 'UNKNOWN');
  });
}

test('the platform function is not accepted when it is not bound, not pinned or not an event-trigger function', () => {
  let d = base(); fn(d).bound_event_triggers = [];
  assert.equal(status(d, 'function-rls_auto_enable'), 'UNKNOWN');
  d = base(); fn(d).config = null;
  assert.equal(status(d, 'function-rls_auto_enable'), 'UNKNOWN');
  d = base(); fn(d).returns = 'void';
  assert.equal(status(d, 'function-rls_auto_enable'), 'UNKNOWN');
});

test('any other function in public is surfaced for a human, never waved through', () => {
  const d = base();
  d.public_functions_detail.push({ ...fn(d), name: 'mystery', returns: 'integer', bound_event_triggers: [], definition: 'select 1' });
  assert.equal(status(d, 'function-mystery'), 'UNKNOWN');
  assert.equal(check(d).verdict, 'BLOCKED');
});

test('the details document contains no credentials, keys or row data', () => {
  const text = readFileSync(new URL('./fixtures/predeploy-local-stub-pg17.json', import.meta.url), 'utf8');
  for (const needle of ['password', 'postgres://', 'eyJ', 'sb_secret', 'sb_publishable', 'service_role_key']) assert.equal(text.includes(needle), false, needle);
});

test('an UNKNOWN item can be acknowledged by id after a human read it; a FAIL never can', () => {
  const d = base(); d.public_functions_detail.find((f) => f.name === 'rls_auto_enable').bound_event_triggers = [];
  assert.equal(check(d).verdict, 'BLOCKED');
  const acked = check(d, ['function-rls_auto_enable']);
  assert.equal(acked.verdict, 'PRECHECK_OK');
  assert.equal(acked.checks.find((c) => c.id === 'function-rls_auto_enable').status, 'ACK');
  d.auth.postgres_can_reference_users = false;
  assert.equal(check(d, ['auth-users']).verdict, 'BLOCKED');
});

const real = () => JSON.parse(readFileSync(new URL('./fixtures/predeploy-real-2026-10-09.json', import.meta.url), 'utf8'));
const evidence = () => JSON.parse(readFileSync(new URL('./fixtures/storage-policy-evidence-real-2026-10-09.json', import.meta.url), 'utf8'));

test('first real hosted inspection (PG 17.11, 2026-10-09): only storage-policies is unresolved without evidence', () => {
  // Real result pasted by the owner; default_privileges_public is abridged in the fixture.
  const r = check(real());
  assert.equal(r.verdict, 'BLOCKED');
  assert.deepEqual(r.checks.filter((c) => c.status !== 'PASS').map((c) => `${c.id}:${c.status}`), ['storage-policies:FAIL']);
});

test('real supautils.policy_grants evidence for storage.objects resolves storage-policies', () => {
  const d = real(); d.storage_policy_evidence = evidence();
  assert.equal(check(d).verdict, 'PRECHECK_OK');
});

test('policy_grants evidence does not help without privileged-role membership or the table', () => {
  let d = real(); d.storage_policy_evidence = evidence(); d.storage_policy_evidence.postgres_member_of_privileged = false;
  assert.equal(status(d, 'storage-policies'), 'FAIL');
  d = real(); d.storage_policy_evidence = evidence(); d.storage_policy_evidence.supautils_settings['supautils.policy_grants'] = '{"postgres":["storage.buckets"]}';
  assert.equal(status(d, 'storage-policies'), 'FAIL');
});
