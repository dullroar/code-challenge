#!/usr/bin/env bash
# Checks the rules of the regex challenge for the sed track. Uses a throwaway data dir.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data
db=$data/RegexSed/demo-timecards.db
fail() { echo "FAIL: $*"; exit 1; }

# 1. The host runs exactly one sed command and has no loops or ifs.
host=$(grep -Ev '^\s*(#|$)' timecards.sh)
[[ $(grep -cE '(^|[|])\s*sed ' <<<"$host") -eq 1 ]] || fail "expected exactly one sed command in timecards.sh"
if grep -Eqw 'for|while|until|select|if|case' <<<"$host"; then fail "loop or if keyword in timecards.sh"; fi

# 2. The sed script never shells out or reads files: no e/r/R/W commands, no s///e flag,
#    and the only files it writes are fd 3 (the SQL) and stderr (the trace).
script=$(grep -Ev '^\s*(#|$)' timecards.sed)
if grep -Eq '^(/([^/\\]|\\.)*/|[0-9$]+)?!?\s*[erRW]( |$)' <<<"$script"; then fail "e/r/R/W command in timecards.sed"; fi
flags=$(sed -nE 's#^s/(\\.|[^/\\])*/(\\.|[^/\\])*/([a-zA-Z0-9]*).*#\3#p' <<<"$script")
if grep -q e <<<"$flags"; then fail "s///e flag in timecards.sed"; fi
targets=$(grep -oE '/w /[^ ]+$' <<<"$script" | sort -u | tr '\n' ' ')
[[ $targets == '/w /dev/fd/3 /w /dev/stderr ' ]] || fail "unexpected w targets: $targets"

# 3. sed itself exits 1 (the "returns false" move), and 2 on a malformed tape.
rc=0; echo 'run:t wk:2026-W01 rng:1011001110100101 tty:1 trace:0' | sed -nE -f timecards.sed 3>/dev/null >/dev/null || rc=$?
[[ $rc -eq 1 ]] || fail "sed exited $rc, expected 1"
rc=0; echo 'not a tape' | sed -nE -f timecards.sed 3>/dev/null 2>/dev/null || rc=$?
[[ $rc -eq 2 ]] || fail "malformed tape: sed exited $rc, expected 2"

# 4. The shift register is deterministic: the same seed gives the same timecards.
a=$(echo 'run:t wk:w rng:0110100110010110 tty:1 trace:0' | sed -nE -f timecards.sed 3>/dev/null || true)
b=$(echo 'run:t wk:w rng:0110100110010110 tty:1 trace:0' | sed -nE -f timecards.sed 3>/dev/null || true)
[[ -n $a && $a == "$b" ]] || fail "same seed, different output"

# 5. Run the real thing a bunch of times. Every run must stop exactly when it should, every running total
#    must equal the previous one plus the hours (sed's tally arithmetic), and SQLite must agree with stdout.
hours_seen=""
for i in $(seq 1 25); do
    out=$(./timecards.sh) || fail "run $i: timecards.sh exited $?"
    run=$(sed -nE 's/^# DEMO ONLY run (.+)$/\1/p' <<<"$out")
    [[ -n $run ]] || fail "run $i: no run id"
    grep -q '^# sed now exits with status 1 (failure), on purpose$' <<<"$out" || fail "run $i: no false-return line"
    commit=$(grep '^# committed' <<<"$out")
    total=$(sed -E 's/.*total=([0-9]+).*/\1/' <<<"$commit")
    entries=$(sed -E 's/.*entries=([0-9]+).*/\1/' <<<"$commit")
    awk -F'\t' -v total="$total" -v entries="$entries" '
        /^(Meetings|Coding|Debugging|Learning)\t/ {
            n++; if ($2 < 10 || $2 > 19) { print "hours out of range: " $0; exit 1 }
            if ($3 != prev + $2) { print "bad running total: " $0; exit 1 }
            if (prev > 40) { print "kept going after 40: " $0; exit 1 }
            prev = $3
        }
        END { if (n != entries || prev != total) { print "summary disagrees with rows"; exit 1 }
              if (n < 4 && prev <= 40) { print "stopped early at " prev; exit 1 } }' <<<"$out" || fail "run $i"
    hours_seen+=$(awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ { printf "%s ", $2 }' <<<"$out")
    db_row=$(sqlite3 "$db" "select count(*) || ' ' || coalesce(max(running_total),0) || ' ' || min(demo_only) || max(demo_only) from demo_timecards where run_id = '$run'")
    [[ $db_row == "$entries $total 11" ]] || fail "run $i: db says '$db_row', output says '$entries $total 11'"
done
[[ $(sqlite3 "$db" 'select count(distinct run_id) from demo_timecards') -eq 25 ]] || fail "expected 25 distinct runs in the db"
distinct=$(tr ' ' '\n' <<<"$hours_seen" | grep . | sort -u | wc -l)
(( distinct >= 6 )) || fail "only $distinct distinct hour values across 25 runs; the shift register looks stuck"

# 6. The demo_only CHECK constraint is real.
if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values('x','x',10,10,0)" 2>/dev/null; then
    fail "db accepted a non-demo row"
fi
echo "OK: one sed command, no shell-outs; 25 runs stopped when they should, added up in tally marks, committed to SQLite, and exited 1"
