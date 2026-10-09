#!/usr/bin/env bash
# OrbiJob: gated, phase-by-phase application of the migrations to the REAL Supabase project.
# Runs on the OWNER'S computer (or anywhere with network + a logged-in Supabase CLI). It is never run by CI and
# was NOT executed by the assistant. Only `apply` writes to the project, and only after every gate below passes.
#
#   scripts/supabase/apply.sh read     # Phase A  read-only: inspect + classify
#   scripts/supabase/apply.sh backup   # Phase B  schema/data backup + dry-run comparison
#   scripts/supabase/apply.sh apply    # Phase C  db push of ONLY the pending migrations  (needs ORBIJOB_CONFIRM_APPLY=<ref>)
#   scripts/supabase/apply.sh audit    # Phase D  catalog audit against the real project
#   (Phase E: node scripts/supabase/e2e_remote.mjs, see docs/SUPABASE_OWNER_RUNBOOK.md)
#
# Needs: supabase CLI (logged in, `supabase link --project-ref rpmlfxwebnlxnwadyvle` done), node >= 20, psql, and
# DB_URL = the connection string from Dashboard -> Connect WITHOUT the password; put the password in PGPASSWORD
# (otherwise it shows in the process list). Never commit it, never paste it into a chat. Output is kept under
# .orbijob-state/ (git-ignored) and contains object names only, no credentials and no row data.
# Nothing here proves a migration batch is atomic: that is unverified on the hosted platform.
set -euo pipefail
REF=rpmlfxwebnlxnwadyvle
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
STATE="${ORBIJOB_STATE_DIR:-$ROOT/.orbijob-state}"
mkdir -p "$STATE"
phase="${1:-}"

die() { echo "STOP: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed"; }
need supabase; need node; need psql
[ -n "${DB_URL:-}" ] || die "set DB_URL (Dashboard -> Connect -> connection string). It is read from the environment only."
# The URL itself is never printed. Accepted shapes: ...@db.<ref>.supabase.co... (direct) or postgres.<ref>:...@...pooler... (pooler).
printf '%s' "$DB_URL" | grep -Eq "(@db\.$REF\.supabase\.co|postgres\.$REF[:@])" || die "DB_URL does not point at project $REF (expected host db.$REF.supabase.co or pooler user postgres.$REF)"
linked="$(cat "$ROOT/supabase/.temp/project-ref" 2>/dev/null || true)"
[ "$linked" = "$REF" ] || die "this checkout is not linked to $REF (run: supabase link --project-ref $REF)"

age_min() { echo $(( ( $(date +%s) - $(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1") ) / 60 )); }

auth_check() { # the CLI must be logged in and able to see the linked project, before any backup or write
  (cd "$ROOT" && supabase migration list --linked >/dev/null 2>&1) || die "the Supabase CLI cannot reach project $REF (not logged in? run: supabase login)"
}

predeploy() { # -> $1 file ; read-only details about privileges, platform functions, event triggers, storage
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 -f "$HERE/inspect_predeploy_details.sql" > "$1"
}
predeploy_gate() { # $1 file ; ORBIJOB_PREDEPLOY_ACK may list UNKNOWN check ids the owner has read and accepts
  node "$HERE/predeploy_check.mjs" "$1" "--ack=${ORBIJOB_PREDEPLOY_ACK:-}" >"$STATE/predeploy-verdict.txt" 2>&1 || {
    cat "$STATE/predeploy-verdict.txt" >&2; die "the pre-deploy check is BLOCKED (FAIL/UNKNOWN items above). Resolve them, or acknowledge a UNKNOWN item you have READ with ORBIJOB_PREDEPLOY_ACK=<id>"; }
}

inspect() { # -> $1 file
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 -f "$HERE/inspect_readonly.sql" > "$1"
}

case "$phase" in
  read)
    out="$STATE/inspection-before.json"
    inspect "$out"
    echo "inspection saved to $out (object names and flags only)"
    node "$HERE/classify_state.mjs" "$out" | tee "$STATE/classification-before.txt"
    predeploy "$STATE/predeploy-before.json"
    echo "--- pre-deploy checks (privileges, platform function, storage) ---"
    node "$HERE/predeploy_check.mjs" "$STATE/predeploy-before.json" "--ack=${ORBIJOB_PREDEPLOY_ACK:-}" | tee "$STATE/predeploy-verdict.txt" || true
    echo "--- supabase migration list (read-only) ---"
    (cd "$ROOT" && supabase migration list --linked) || true
    ;;
  backup)
    auth_check
    [ -f "$STATE/inspection-before.json" ] || die "run '$0 read' first"
    [ "$(age_min "$STATE/inspection-before.json")" -le 60 ] || die "inspection is older than 60 minutes: run '$0 read' again"
    node "$HERE/classify_state.mjs" "$STATE/inspection-before.json" >/dev/null || die "state is DRIFT: resolve before backing up for an apply"
    [ -f "$STATE/predeploy-before.json" ] || die "no pre-deploy details: run '$0 read' first"
    predeploy_gate "$STATE/predeploy-before.json"
    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    # supabase db dump needs Docker Desktop; pg_dump with DB_URL is the alternative (same result).
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
      via=cli; (cd "$ROOT" && supabase db dump --linked -f "$STATE/backup-schema-$ts.sql")
    else
      via=pg_dump; need pg_dump
      pg_dump "$DB_URL" --schema-only --no-owner --schema=public -f "$STATE/backup-schema-$ts.sql"
    fi
    bk="$STATE/backup-schema-$ts.sql"
    [ -s "$bk" ] || die "backup file is empty"
    grep -q "PostgreSQL database dump" "$bk" || die "backup does not look like a pg_dump file"
    if [ "$via" = "pg_dump" ]; then grep -q "PostgreSQL database dump complete" "$bk" || die "backup is truncated (no end marker)"; fi
    state="$(node "$HERE/classify_state.mjs" "$STATE/inspection-before.json" --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).state))')"
    if [ "$state" != "EMPTY" ] && [ "${ORBIJOB_DATA_BACKUP_DONE:-}" != "yes" ]; then
      die "the project already has OrbiJob objects ($state): this schema-only dump does not protect user DATA. Take a data backup (dashboard backups or pg_dump --data-only), then export ORBIJOB_DATA_BACKUP_DONE=yes"
    fi
    sha256sum "$STATE/backup-schema-$ts.sql" 2>/dev/null | tee "$STATE/backup-$ts.sha256" || shasum -a 256 "$STATE/backup-schema-$ts.sql" | tee "$STATE/backup-$ts.sha256"
    echo "backup written. Open it and check that it is a plausible dump before continuing."
    echo "--- dry run: what 'db push' would apply ---"
    (cd "$ROOT" && supabase db push --dry-run) | tee "$STATE/dry-run.txt"
    expected="$(node "$HERE/classify_state.mjs" "$STATE/inspection-before.json" --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).pending.map(x=>x.split("_")[0]).join(" ")))')"
    for v in $expected; do grep -q "$v" "$STATE/dry-run.txt" || die "dry run does not list expected pending migration $v"; done
    for v in 20261008000000 20261009000000 20261010000000 20261011000000 20261012000000; do
      case " $expected " in *" $v "*) ;; *) if grep -q "$v" "$STATE/dry-run.txt"; then die "dry run would re-apply $v, which the classification says is already applied"; fi;; esac
    done
    echo "dry run matches the classification. Recovery for a partial failure: docs/SUPABASE_MIGRATION_PLAN.md sections 5 and 6."
    { echo "state=$state"; echo "backup=$bk"; } > "$STATE/backup-ok"
    ;;
  apply)
    [ "${ORBIJOB_CONFIRM_APPLY:-}" = "$REF" ] || die "writes need explicit authorization: export ORBIJOB_CONFIRM_APPLY=$REF"
    auth_check
    [ -f "$STATE/backup-ok" ] && [ "$(age_min "$STATE/backup-ok")" -le 60 ] || die "no fresh backup gate: run '$0 read' then '$0 backup'"
    [ "$(age_min "$STATE/inspection-before.json")" -le 60 ] || die "inspection is stale"
    node "$HERE/classify_state.mjs" "$STATE/inspection-before.json" >/dev/null || die "state is DRIFT"
    # Re-inspect right before writing: abort if anything changed since the backup.
    predeploy "$STATE/predeploy-pre-apply.json"; predeploy_gate "$STATE/predeploy-pre-apply.json"
    inspect "$STATE/inspection-pre-apply.json"
    diff -q <(node -e 'const j=require(process.argv[1]);delete j.collected_at;console.log(JSON.stringify(j))' "$STATE/inspection-before.json") \
            <(node -e 'const j=require(process.argv[1]);delete j.collected_at;console.log(JSON.stringify(j))' "$STATE/inspection-pre-apply.json") >/dev/null \
      || die "the database changed after the backup: start over from '$0 read'"
    if ! grep -q '^state=EMPTY' "$STATE/backup-ok" && [ "${ORBIJOB_DATA_BACKUP_DONE:-}" != "yes" ]; then die "non-empty project: export ORBIJOB_DATA_BACKUP_DONE=yes after taking a DATA backup"; fi
    rm -f "$STATE/backup-ok"   # the gate is spent BEFORE writing: after any outcome a new read + backup is required
    echo "applying pending migrations with the CLI (it records each version and does not re-apply a recorded one)..."
    (cd "$ROOT" && supabase db push) || { echo "db push FAILED. Do NOT retry blindly: run '$0 read' to see what was applied, then decide (plan sections 5 and 6)." >&2; exit 1; }
    inspect "$STATE/inspection-after.json"
    node "$HERE/classify_state.mjs" "$STATE/inspection-after.json" | tee "$STATE/classification-after.txt"
    grep -q "CONSISTENT_UP_TO_DATE" "$STATE/classification-after.txt" || die "after the push the state is not CONSISTENT_UP_TO_DATE: stop and review"
    echo "migrations applied and verified. Next: '$0 audit', then the Auth/Storage settings and Phase E."
    ;;
  audit)
    tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    sed '/^\\set/d' "$ROOT/supabase/tests/01_audit.sql" > "$tmp"
    psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -f "$tmp"
    echo "catalog audit passed on the real project. Now check Dashboard -> Advisors (Security and Performance)."
    ;;
  *) die "usage: $0 read|backup|apply|audit" ;;
esac
