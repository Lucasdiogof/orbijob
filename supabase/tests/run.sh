#!/usr/bin/env bash
# Applies the platform stub + every migration, in order, to a throw-away database, then runs the audit and
# behavioural SQL tests. Never touches a remote project. Usage:
#   PGURL=postgres://postgres@localhost:5432/postgres supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")"
: "${PGURL:?set PGURL to a superuser connection string of a disposable Postgres (>=15)}"
DB="orbijob_sql_test_$$"
psql "$PGURL" -v ON_ERROR_STOP=1 -qc "create database $DB"
trap 'psql "$PGURL" -qc "drop database if exists $DB" >/dev/null' EXIT
URL="${PGURL%/*}/$DB"
run() { psql "$URL" -v ON_ERROR_STOP=1 -q -f "$1"; }
run 00_platform_stub.sql
# regression for the hosted failure of the pre-deploy details query (search_path / "$user" resolution)
./07_predeploy_search_path.sh "$PGURL" >/tmp/pd07_$$.txt 2>&1 || { cat /tmp/pd07_$$.txt; exit 1; }
grep "predeploy search_path" /tmp/pd07_$$.txt; rm -f /tmp/pd07_$$.txt
# the pre-deploy details query must run on this server, and on a platform-like database that has NOT been migrated yet
# the verdict must be PRECHECK_OK (it is a "before" check: after the migrations the OrbiJob objects would, correctly, clash)
psql "$URL" -X -q -At -v ON_ERROR_STOP=1 -f ../../scripts/supabase/inspect_predeploy_details.sql > /tmp/predeploy_$$.json
node ../../scripts/supabase/predeploy_check.mjs /tmp/predeploy_$$.json >/tmp/predeploy_$$.txt || { cat /tmp/predeploy_$$.txt; echo "pre-deploy details disagree with the stub"; exit 1; }
rm -f /tmp/predeploy_$$.json /tmp/predeploy_$$.txt
for m in ../migrations/*.sql; do echo "migration: $(basename "$m")"; run "$m"; done
run 01_audit.sql
run 02_behaviour.sql
run 03_quotas.sql
run 08_service_role.sql
./05_concurrency.sh "$URL"
# the storage section must be re-runnable without error (idempotence of the bucket/policy statements)
awk '/-- ───────── private storage: resumes/{f=1} f' ../migrations/20261010000000_app_integration.sql > /tmp/storage_section_$$.sql
run /tmp/storage_section_$$.sql && rm -f /tmp/storage_section_$$.sql
run 01_audit.sql

# the read-only inspection used before a real deployment must run on this chain and classify it as fully migrated
psql "$URL" -v ON_ERROR_STOP=1 -q -c "create schema if not exists supabase_migrations; create table supabase_migrations.schema_migrations (version text primary key, name text); insert into supabase_migrations.schema_migrations (version) select regexp_replace(v, '_.*', '') from unnest(string_to_array('$(ls ../migrations | sed 's/\.sql$//' | tr '\n' ',' | sed 's/,$//')', ',')) v;" >/dev/null
psql "$URL" -X -q -At -v ON_ERROR_STOP=1 -f ../../scripts/supabase/inspect_readonly.sql > /tmp/inspection_$$.json
node ../../scripts/supabase/classify_state.mjs /tmp/inspection_$$.json | grep -q "CONSISTENT_UP_TO_DATE" || { echo "inspection/classification disagree with the applied chain"; node ../../scripts/supabase/classify_state.mjs /tmp/inspection_$$.json; exit 1; }
rm -f /tmp/inspection_$$.json
psql "$URL" -q -c "drop schema supabase_migrations cascade" >/dev/null

# teardown: refuses without confirmation, empties cleanly, and the chain applies again afterwards
if psql "$URL" -v ON_ERROR_STOP=1 -q -f ../rollback/rollback_all.sql >/dev/null 2>&1; then echo "rollback ran WITHOUT confirmation"; exit 1; fi
# rollback must refuse while the bucket exists (the real platform forbids SQL deletes on storage tables)
if PGOPTIONS="-c orbijob.confirm_rollback=yes" psql "$URL" -v ON_ERROR_STOP=1 -q -f ../rollback/rollback_all.sql >/dev/null 2>&1; then echo "rollback ran with the bucket still present"; exit 1; fi
# simulate the Storage API emptying and deleting the bucket
psql "$URL" -qc "set storage.allow_delete_query = 'true'; delete from storage.objects; delete from storage.buckets where id = 'resumes'" >/dev/null
PGOPTIONS="-c orbijob.confirm_rollback=yes" psql "$URL" -v ON_ERROR_STOP=1 -q -f ../rollback/rollback_all.sql >/dev/null
run 04_rollback_clean.sql
for m in ../migrations/*.sql; do run "$m" >/dev/null 2>&1 || { echo "re-apply failed: $m"; exit 1; }; done
run 01_audit.sql

# upgrade path: a database that already holds migrations 1-4 and a full favourites list receives migration 5
DB2="${DB}_up"
psql "$PGURL" -v ON_ERROR_STOP=1 -qc "create database $DB2"
trap 'psql "$PGURL" -qc "drop database if exists $DB" >/dev/null; psql "$PGURL" -qc "drop database if exists $DB2" >/dev/null' EXIT
URL2="${PGURL%/*}/$DB2"
run2() { psql "$URL2" -v ON_ERROR_STOP=1 -q -f "$1"; }
run2 00_platform_stub.sql
for m in $(ls ../migrations/*.sql | grep -v -e quota_upsert_fix -e service_role_grants); do run2 "$m" >/dev/null 2>&1 || { echo "upgrade setup failed: $m"; exit 1; }; done
psql "$URL2" -v ON_ERROR_STOP=1 -q -c "insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000e1'); insert into public.saved_jobs (user_id, job_key, snapshot) select '00000000-0000-0000-0000-0000000000e1', 'k' || g, '{\"a\":1}' from generate_series(1, 1000) g;"
# the original trigger is the one that is wrongly strict at the cap
if psql "$URL2" -v ON_ERROR_STOP=1 -q -c "insert into public.saved_jobs (user_id, job_key, snapshot) values ('00000000-0000-0000-0000-0000000000e1', 'k5', '{}') on conflict (user_id, job_key) do update set snapshot = excluded.snapshot" >/dev/null 2>&1; then echo "expected the pre-fix trigger to refuse the upsert"; exit 1; fi
run2 ../migrations/20261012000000_quota_upsert_fix.sql
run2 06_upgrade_path.sql
echo "ALL SQL TESTS PASSED"
