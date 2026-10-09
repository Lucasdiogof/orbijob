#!/usr/bin/env bash
# Two concurrent sessions each try to add the 1000th favourite while the user has 999: exactly one may succeed.
# Without the per-user advisory lock both would count 999 and the user would end with 1001.
set -euo pipefail
URL="$1"
U=00000000-0000-0000-0000-0000000000d1
psql "$URL" -v ON_ERROR_STOP=1 -q <<SQL
insert into auth.users (id) values ('$U');
insert into public.saved_jobs (user_id, job_key, snapshot) select '$U', 'c' || g, '{"a":1}' from generate_series(1, 999) g;
SQL
A_OUT=$(mktemp)
(
  psql "$URL" -v ON_ERROR_STOP=1 -q >"$A_OUT" 2>&1 <<SQL
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '$U', true);
insert into public.saved_jobs (user_id, job_key, snapshot) values ('$U', 'race-a', '{"a":1}');
select pg_sleep(2);
commit;
SQL
) &
sleep 0.7   # session A now holds its (uncommitted) row and the per-user lock
B_OUT=$(psql "$URL" -v ON_ERROR_STOP=1 -q 2>&1 <<SQL || true
set role authenticated;
select set_config('request.jwt.claim.sub', '$U', false);
insert into public.saved_jobs (user_id, job_key, snapshot) values ('$U', 'race-b', '{"a":1}');
SQL
)
wait
if ! grep -q 'quota exceeded' <<<"$B_OUT"; then echo "FAIL: concurrent insert was not refused: $B_OUT"; exit 1; fi
if grep -qi 'error' "$A_OUT"; then echo "FAIL: first session failed: $(cat "$A_OUT")"; exit 1; fi
N=$(psql "$URL" -Atc "select count(*) from public.saved_jobs where user_id = '$U'")
[ "$N" = "1000" ] || { echo "FAIL: user ended with $N favourites"; exit 1; }
rm -f "$A_OUT"
echo "concurrency: ok"
