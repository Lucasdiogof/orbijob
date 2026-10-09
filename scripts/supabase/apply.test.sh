#!/usr/bin/env bash
# Tests the gating logic of apply.sh with FAKE supabase/psql/pg_dump binaries: no network, no database.
# Proves `db push` is reachable only through the gates, runs once, and that stale/drifted/changed states stop it.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"; rm -f "$ROOT/supabase/.temp/project-ref"' EXIT
mkdir -p "$W/bin" "$W/state" "$ROOT/supabase/.temp"; echo rpmlfxwebnlxnwadyvle > "$ROOT/supabase/.temp/project-ref"
FX="$HERE/fixtures"
cat > "$W/bin/psql" <<FAKE
#!/usr/bin/env bash
case "\$*" in *inspect_readonly.sql*)
  n=\$(cat "$W/n" 2>/dev/null || echo 0); echo \$((n+1)) > "$W/n"
  if [ -f "$W/after" ] && [ "\$n" -ge "\$(cat "$W/after")" ]; then cat "\${FX_AFTER}"; else cat "\${FX_BEFORE}"; fi;; esac
FAKE
cat > "$W/bin/supabase" <<FAKE
#!/usr/bin/env bash
echo "supabase \$*" >> "$W/calls"
case "\$*" in
  "db push --dry-run") for v in \$PENDING; do echo "Would push: \${v}_x.sql"; done;;
  "migration list"*) if [ -n "\${AUTH_FAIL:-}" ]; then exit 1; fi;;
  "db push") echo pushed >> "$W/pushes"; if [ -n "\${PUSH_FAIL:-}" ]; then exit 1; fi;;
  "db dump"*) while [ "\$#" -gt 0 ]; do [ "\$1" = "-f" ] && printf -- '-- PostgreSQL database dump\\n-- PostgreSQL database dump complete\\n' > "\$2"; shift; done;;
esac
FAKE
# CI runners have a working Docker; the test must not depend on the host: pretend there is none, so the pg_dump path is used
printf '#!/usr/bin/env bash\nexit 1\n' > "$W/bin/docker"
cat > "$W/bin/pg_dump" <<FAKE
#!/usr/bin/env bash
while [ "\$#" -gt 0 ]; do
  if [ "\$1" = "-f" ]; then
    printf -- '-- PostgreSQL database dump\\n' > "\$2"
    [ -z "\${TRUNCATED:-}" ] && printf -- '-- PostgreSQL database dump complete\\n' >> "\$2"
  fi
  shift
done
FAKE
chmod +x "$W/bin"/*
export PATH="$W/bin:$PATH" DB_URL="postgres://postgres@db.rpmlfxwebnlxnwadyvle.supabase.co:5432/postgres" ORBIJOB_STATE_DIR="$W/state"
export FX_BEFORE="$FX/empty.json" FX_AFTER="$FX/after-1-to-5.json" PENDING="20261008000000 20261009000000 20261010000000 20261011000000 20261012000000"
pass=0; fail=0
ok() { if [ "$2" = 0 ]; then pass=$((pass+1)); echo "PASS $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }
pushes() { [ -f "$W/pushes" ] && wc -l < "$W/pushes" | tr -d ' ' || echo 0; }

"$HERE/apply.sh" apply >/dev/null 2>&1;                        ok "apply without any gate is refused" $([ $? -ne 0 ] && echo 0 || echo 1)
"$HERE/apply.sh" read >/dev/null 2>&1;                         ok "read succeeds on an empty project" $?
"$HERE/apply.sh" backup >/dev/null 2>&1;                       ok "backup + dry-run match the classification" $?
ORBIJOB_CONFIRM_APPLY=wrong "$HERE/apply.sh" apply >/dev/null 2>&1; ok "apply with a wrong confirmation is refused" $([ $? -ne 0 ] && echo 0 || echo 1)
ok "no push happened before authorization" $([ "$(pushes)" = 0 ] && echo 0 || echo 1)
echo 1 > "$W/after"; rm -f "$W/n"
ORBIJOB_CONFIRM_APPLY=rpmlfxwebnlxnwadyvle "$HERE/apply.sh" apply >/dev/null 2>&1; ok "authorized apply succeeds and verifies the result" $?
ok "db push ran exactly once" $([ "$(pushes)" = 1 ] && echo 0 || echo 1)
ORBIJOB_CONFIRM_APPLY=rpmlfxwebnlxnwadyvle "$HERE/apply.sh" apply >/dev/null 2>&1; ok "a second apply needs a new backup (gate consumed)" $([ $? -ne 0 ] && echo 0 || echo 1)

# database changed between backup and apply -> abort without pushing
rm -f "$W/pushes" "$W/n" "$W/after" "$W/state"/*
"$HERE/apply.sh" read >/dev/null 2>&1; "$HERE/apply.sh" backup >/dev/null 2>&1
FX_BEFORE="$FX/after-1-to-4.json" ORBIJOB_CONFIRM_APPLY=rpmlfxwebnlxnwadyvle "$HERE/apply.sh" apply >/dev/null 2>&1
ok "a change after the backup aborts the apply" $([ $? -ne 0 ] && [ "$(pushes)" = 0 ] && echo 0 || echo 1)

# drift -> backup refuses
python3 - "$FX/empty.json" "$W/drift.json" <<'PY'
import json,sys; d=json.load(open(sys.argv[1])); d['public_tables'].append({'name':'foreign','rls':False,'owner':'postgres'}); json.dump(d,open(sys.argv[2],'w'))
PY
rm -f "$W/state"/*; FX_BEFORE="$W/drift.json" "$HERE/apply.sh" read >/dev/null 2>&1
FX_BEFORE="$W/drift.json" "$HERE/apply.sh" backup >/dev/null 2>&1; ok "a drifted project is never backed up for an apply" $([ $? -ne 0 ] && echo 0 || echo 1)

# dry run lists a migration the classification says is applied -> backup refuses
rm -f "$W/state"/*; FX_BEFORE="$FX/after-1-to-4.json" "$HERE/apply.sh" read >/dev/null 2>&1
FX_BEFORE="$FX/after-1-to-4.json" PENDING="20261008000000 20261012000000" "$HERE/apply.sh" backup >/dev/null 2>&1
ok "a dry run that would repeat an applied migration stops the backup gate" $([ $? -ne 0 ] && echo 0 || echo 1)

# wrong project link / wrong DB_URL
echo someotherproject > "$ROOT/supabase/.temp/project-ref"; "$HERE/apply.sh" read >/dev/null 2>&1
ok "a checkout linked to another project is refused" $([ $? -ne 0 ] && echo 0 || echo 1)
echo rpmlfxwebnlxnwadyvle > "$ROOT/supabase/.temp/project-ref"; DB_URL=postgres://x@other.host/db "$HERE/apply.sh" read >/dev/null 2>&1
ok "a DB_URL of another project is refused" $([ $? -ne 0 ] && echo 0 || echo 1)

# authentication failure: nothing proceeds without a working CLI login
rm -f "$W/state"/* "$W/pushes" "$W/n" "$W/after"
"$HERE/apply.sh" read >/dev/null 2>&1
AUTH_FAIL=1 "$HERE/apply.sh" backup >/dev/null 2>&1; ok "backup is refused when the CLI is not authenticated" $([ $? -ne 0 ] && echo 0 || echo 1)

# truncated backup (no end marker) is rejected
TRUNCATED=1 "$HERE/apply.sh" backup >/dev/null 2>&1; ok "a truncated backup is rejected" $([ $? -ne 0 ] && echo 0 || echo 1)
"$HERE/apply.sh" backup >/dev/null 2>&1; ok "a complete backup is accepted" $?

# a failed push spends the gate: a retry needs a new read + backup, and no second push happens
AUTH_FAIL= PUSH_FAIL=1 ORBIJOB_CONFIRM_APPLY=rpmlfxwebnlxnwadyvle "$HERE/apply.sh" apply >/dev/null 2>&1; ok "a failing db push makes apply fail" $([ $? -ne 0 ] && echo 0 || echo 1)
PUSH_FAIL= ORBIJOB_CONFIRM_APPLY=rpmlfxwebnlxnwadyvle "$HERE/apply.sh" apply >/dev/null 2>&1
ok "after a failed push the retry is refused (gate spent) and did not push again" $([ $? -ne 0 ] && [ "$(pushes)" = 1 ] && echo 0 || echo 1)

# a project that already has OrbiJob objects needs an explicit DATA backup attestation
rm -f "$W/state"/* "$W/pushes"
export FX_BEFORE="$FX/after-1-to-4.json" PENDING="20261012000000"
"$HERE/apply.sh" read >/dev/null 2>&1
"$HERE/apply.sh" backup >/dev/null 2>&1; ok "non-empty project: schema-only backup alone is refused" $([ $? -ne 0 ] && echo 0 || echo 1)
ORBIJOB_DATA_BACKUP_DONE=yes "$HERE/apply.sh" backup >/dev/null 2>&1; ok "non-empty project: accepted with the data-backup attestation" $?
ORBIJOB_CONFIRM_APPLY=rpmlfxwebnlxnwadyvle "$HERE/apply.sh" apply >/dev/null 2>&1; ok "non-empty project: apply also needs the attestation" $([ $? -ne 0 ] && [ "$(pushes)" = 0 ] && echo 0 || echo 1)

# look-alike connection strings are refused
for bad in "postgres://x@db.rpmlfxwebnlxnwadyvle.evil.com:5432/db" "postgres://x@db.other.supabase.co:5432/rpmlfxwebnlxnwadyvle" "postgres://x@evil.example/rpmlfxwebnlxnwadyvle"; do
  DB_URL="$bad" "$HERE/apply.sh" read >/dev/null 2>&1; ok "look-alike DB_URL refused ($bad)" $([ $? -ne 0 ] && echo 0 || echo 1)
done
DB_URL="postgres://postgres.rpmlfxwebnlxnwadyvle@aws-0-sa-east-1.pooler.supabase.com:6543/postgres" FX_BEFORE="$FX/empty.json" "$HERE/apply.sh" read >/dev/null 2>&1; ok "pooler-style DB_URL of the right project is accepted" $?

# secrets never reach the output
SECRET="s3cr3t-pass"; out=$(DB_URL="postgres://postgres:$SECRET@db.rpmlfxwebnlxnwadyvle.supabase.co:5432/postgres" PGPASSWORD="$SECRET" "$HERE/apply.sh" read 2>&1)
ok "neither the password nor the connection string appears in the output" $(echo "$out" | grep -q "$SECRET\|postgres://" && echo 1 || echo 0)
echo "$pass passed, $fail failed"; [ "$fail" = 0 ]
