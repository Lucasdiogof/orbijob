#!/usr/bin/env bash
# Regression for the hosted failure of inspect_predeploy_details.sql:  ERROR: 3F000: schema "$user" does not exist
# Root cause: a TEXT value derived from search_path was passed to has_schema_privilege(); PostgreSQL does not guarantee the
# order in which WHERE conditions run, so the call could receive "$user" (or any entry that is not a schema).
# Usage: 07_predeploy_search_path.sh <superuser connection URL of the maintenance database>
set -euo pipefail
cd "$(dirname "$0")"
BASE="${1:?superuser PGURL}"
DB="orbijob_pd_$$"
SQL=${PREDEPLOY_SQL:-../../scripts/supabase/inspect_predeploy_details.sql}
OLD=../../scripts/supabase/fixtures/old_search_path_snippet.sql
psql "$BASE" -qc "drop role if exists t_blind" >/dev/null 2>&1 || true   # roles are cluster-wide: leftovers of an aborted run
psql "$BASE" -v ON_ERROR_STOP=1 -qc "create database $DB"
trap 'psql "$BASE" -qc "drop database if exists $DB" >/dev/null 2>&1; psql "$BASE" -qc "drop role if exists t_blind" >/dev/null 2>&1' EXIT
URL="${BASE%/*}/$DB"
q() { psql "$URL" -v ON_ERROR_STOP=1 -X -q "$@"; }
q -f 00_platform_stub.sql >/dev/null
fail=0
ok() { if [ "$2" = "$3" ]; then echo "  PASS $1"; else echo "  FAIL $1: got [$2] expected [$3]"; fail=1; fi; }
field() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);const v=eval("j."+process.argv[1]);console.log(v===null?"null":(typeof v==="object"?JSON.stringify(v):String(v)))})' "$1"; }
details() { # $1 = search_path value, $2 = optional role to SET ROLE to
  { [ -n "${2:-}" ] && echo "set role $2;"; echo "set search_path = $1;"; cat "$SQL"; } | psql "$URL" -X -q -At 2>&1
}

echo "[root cause] the privilege function rejects names that are not schemas"
out=$(psql "$URL" -X -q -At -c "select has_schema_privilege(current_user, '\$user', 'CREATE')" 2>&1 || true)
ok "'\$user' as text raises 3F000" "$(echo "$out" | grep -c 'schema "\$user" does not exist')" "1"

echo "[old query] the original defective snippet fails when the search_path names a schema that does not exist"
out=$( { echo "set search_path = nonexistent, public;"; cat "$OLD"; } | psql "$URL" -X -q -At 2>&1 || true)
ok "old snippet errors with a missing schema in the path" "$(echo "$out" | grep -c 'schema "nonexistent" does not exist')" "1"

out=$( { echo "set search_path = nonexistent, public;"; cat ../../scripts/supabase/fixtures/old_inspect_predeploy_details.sql; } | psql "$URL" -X -q -At 2>&1 || true)
ok "the complete ORIGINAL file errors the same way" "$(echo "$out" | grep -c 'schema "nonexistent" does not exist')" "1"

echo "[fixed query] schemas used below"
q -c 'create schema "Weird Schema"; create schema "we,ird""name"; create schema ro_schema; grant usage on schema ro_schema to anon;' >/dev/null
q -c 'grant usage, create on schema public to anon;' >/dev/null

echo "[fixed query] default path and \$user"
j=$(details '"$user", public')
ok "first schema" "$(echo "$j" | field 'pg_trgm.create_without_schema_would_use')" "public"
ok "path (\$user dropped, order kept)" "$(echo "$j" | field 'search_path_schemas.map(x=>x.name)')" '["public"]'
ok "no error text in output" "$(echo "$j" | grep -c '^ERROR')" "0"

echo "[fixed query] search-path order is preserved (the old query returned 'public' here)"
j=$(details 'extensions, public')
ok "first schema is the first entry" "$(echo "$j" | field 'pg_trgm.create_without_schema_would_use')" "extensions"
ok "positions" "$(echo "$j" | field 'search_path_schemas.map(x=>x.position+":"+x.name)')" '["1:extensions","2:public"]'
j=$(details 'public, extensions, "$user"')
ok "reverse order preserved" "$(echo "$j" | field 'search_path_schemas.map(x=>x.name)')" '["public","extensions"]'

echo "[fixed query] schemas that do not exist are ignored, not errors"
j=$(details 'nonexistent, public')
ok "missing entry skipped" "$(echo "$j" | field 'search_path_schemas.map(x=>x.name)')" '["public"]'
ok "first is the first EXISTING schema" "$(echo "$j" | field 'pg_trgm.create_without_schema_would_use')" "public"
j=$(details 'nonexistent_a, nonexistent_b')
ok "path with no existing schema gives null, not an error" "$(echo "$j" | field 'pg_trgm.create_without_schema_would_use')" "null"
ok "and an empty list" "$(echo "$j" | field 'search_path_schemas.length')" "0"

echo "[fixed query] quoted entries and special names"
j=$(details '"Weird Schema", public')
ok "mixed case + space" "$(echo "$j" | field 'pg_trgm.create_without_schema_would_use')" "Weird Schema"
j=$(details '"we,ird""name", public')
ok "comma and quote inside the name" "$(echo "$j" | field 'pg_trgm.create_without_schema_would_use')" 'we,ird"name'

echo "[fixed query] a schema without CREATE is reported as such and is not silently skipped"
j=$(details 'ro_schema, public' anon)
ok "first schema is ro_schema" "$(echo "$j" | field 'pg_trgm.create_without_schema_would_use')" "ro_schema"
ok "current user cannot create there" "$(echo "$j" | field 'pg_trgm.create_without_schema_can_create')" "false"
ok "the first creatable one is still reported" "$(echo "$j" | field 'pg_trgm.first_creatable_schema_in_path')" "public"
ok "per-schema flags" "$(echo "$j" | field 'search_path_schemas.map(x=>x.name+":"+x.current_user_can_create)')" '["ro_schema:false","public:true"]'
echo "$j" > /tmp/pd_ro_$$.json
verdict=$(node ../../scripts/supabase/predeploy_check.mjs /tmp/pd_ro_$$.json | grep 'pg_trgm-target' || true); rm -f /tmp/pd_ro_$$.json
ok "the checker FAILS pg_trgm-target (PostgreSQL does not fall back to the next schema)" "$(echo "$verdict" | cut -c1-4)" "FAIL"

echo "[fixed query] real permission errors are not masked"
q -c 'create role t_blind nologin; grant usage on schema storage, auth, public, extensions to t_blind;' >/dev/null
out=$(details 'public' t_blind || true)
ok "reading storage.buckets without SELECT raises permission denied" "$(echo "$out" | grep -c 'permission denied')" "1"

echo "[fixed query] output stays compatible with predeploy_check.mjs"
details '"$user", public' > /tmp/pd_ok_$$.json
node ../../scripts/supabase/predeploy_check.mjs /tmp/pd_ok_$$.json >/tmp/pd_ok_$$.txt && ok "verdict" "PRECHECK_OK" "PRECHECK_OK" || { cat /tmp/pd_ok_$$.txt; ok "verdict" "BLOCKED" "PRECHECK_OK"; }
rm -f /tmp/pd_ok_$$.json /tmp/pd_ok_$$.txt

echo "[first inspection] inspect_readonly.sql also runs with a hostile search_path"
out=$( { echo "set search_path = nonexistent, \"\$user\";"; cat ../../scripts/supabase/inspect_readonly.sql; } | psql "$URL" -X -q -At 2>&1 | head -c 20)
ok "inspect_readonly.sql returns JSON" "$(echo "$out" | head -c 1)" "{"
[ "$fail" = 0 ] || { echo "predeploy search_path regression FAILED"; exit 1; }
echo "predeploy search_path: ok"
