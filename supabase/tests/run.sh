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
for m in ../migrations/*.sql; do echo "migration: $(basename "$m")"; run "$m"; done
run 01_audit.sql
run 02_behaviour.sql
# the storage section must be re-runnable without error (idempotence of the bucket/policy statements)
awk '/-- ───────── private storage: resumes/{f=1} f' ../migrations/20261010000000_app_integration.sql > /tmp/storage_section_$$.sql
run /tmp/storage_section_$$.sql && rm -f /tmp/storage_section_$$.sql
run 01_audit.sql
echo "ALL SQL TESTS PASSED"
