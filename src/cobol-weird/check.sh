#!/usr/bin/env bash
# Checks the rules of the challenge for the weird COBOL entry. Uses a throwaway data dir.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data
db=$data/CobolWeird/demo-timecards.db
bin=$data/timecards

# 1. Static: the demo disclaimer, nothing network-looking, honest fixed format, and the constraint is real. With
#    comment lines and string literals removed, no structured control flow appears: only GO TO and ALTER, plus the
#    one ON SIZE ERROR tripwire.
grep -q 'DEMO ONLY' timecards.cob || { echo "FAIL: no DEMO ONLY marker in timecards.cob"; exit 1; }
if grep -Eqi 'http|socket|curl|wget' timecards.cob; then echo "FAIL: network-looking text in timecards.cob"; exit 1; fi
long=$(awk 'length > 72 { print FNR }' timecards.cob)
[[ -z $long ]] || { echo "FAIL: lines past column 72 (fixed format): $long"; exit 1; }
code=$(grep -Ev '^.{6}\*' timecards.cob | sed -E 's/"[^"]*"//g')    # drop * comments (column 7) and "literals"
if grep -Eiqw 'IF|PERFORM|EVALUATE|UNTIL|VARYING|DEPENDING|SEARCH|WHEN' <<<"$code"; then
    echo "FAIL: structured control flow found in timecards.cob"; grep -Eiwn 'IF|PERFORM|EVALUATE|UNTIL|VARYING|DEPENDING|SEARCH|WHEN' <<<"$code"; exit 1
fi
[[ $(grep -cw 'ALTER' <<<"$code") -eq 5 ]] || { echo "FAIL: expected 5 ALTERs (4 categories + the stop)"; exit 1; }
[[ $(grep -c 'ON SIZE ERROR' <<<"$code") -eq 1 ]] || { echo "FAIL: expected exactly one ON SIZE ERROR (the stop rule)"; exit 1; }
grep -q 'ALTER NEXT-CARD TO PROCEED TO FINISH-RUN' <<<"$code" || { echo "FAIL: the stop is not an ALTER of NEXT-CARD"; exit 1; }

# 2. Build once (binaries are never committed), then run it a bunch of times. Every run must print a sane record
#    set, and the SQLite rows must agree with it.
"${COBC:-cobc}" -x -o "$bin" timecards.cob
cats=(Meetings Coding Debugging Learning)
for i in $(seq 1 25); do
    week_before=$(date +%G-W%V)
    out=$("$bin")
    week_after=$(date +%G-W%V)
    run_id=$(sed -nE 's/^# DEMO ONLY run (.+)$/\1/p' <<<"$out")
    [[ -n $run_id ]] || { echo "FAIL run $i: no run id"; echo "$out"; exit 1; }
    commit=$(grep '^# committed' <<<"$out" || true)
    [[ -n $commit ]] || { echo "FAIL run $i: no committed line"; echo "$out"; exit 1; }
    total=$(sed -E 's/.*total=([0-9]+).*/\1/' <<<"$commit")
    entries=$(sed -E 's/.*entries=([0-9]+).*/\1/' <<<"$commit")
    mapfile -t rows < <(grep -E '^(Meetings|Coding|Debugging|Learning)	' <<<"$out" || true)
    [[ ${#rows[@]} -eq $entries ]] || { echo "FAIL run $i: ${#rows[@]} rows but entries=$entries"; exit 1; }
    sum=0; n=0
    for row in "${rows[@]}"; do
        IFS=$'\t' read -r cat hours running week mark <<<"$row"
        [[ $cat == "${cats[n % 4]}" ]] || { echo "FAIL run $i: row $n is $cat, wanted ${cats[n % 4]}"; exit 1; }
        (( 10#$hours >= 10 && 10#$hours <= 19 )) || { echo "FAIL run $i: hours $hours out of 10-19"; exit 1; }
        (( sum <= 40 )) || { echo "FAIL run $i: kept going after the total passed 40"; exit 1; }
        sum=$(( sum + 10#$hours )); n=$(( n + 1 ))
        (( 10#$running == sum )) || { echo "FAIL run $i: running total $running, wanted $sum"; exit 1; }
        # The ISO week is computed by date arithmetic in COBOL; it must agree with date(1).
        [[ $week == "$week_before" || $week == "$week_after" ]] || { echo "FAIL run $i: ISO week '$week', date(1) says '$week_before'"; exit 1; }
        [[ $mark == "DEMO ONLY" ]] || { echo "FAIL run $i: row not marked DEMO ONLY"; exit 1; }
    done
    (( sum == 10#$total && sum > 40 )) || { echo "FAIL run $i: stopped at $sum (summary says $total); must stop once over 40"; exit 1; }
    db_row=$(sqlite3 "$db" "select count(*) || ' ' || coalesce(sum(hours),0) || ' ' || coalesce(min(demo_only),0) || coalesce(max(demo_only),0) from demo_timecards where run_id = '$run_id'")
    [[ $db_row == "$entries $sum 11" ]] || { echo "FAIL run $i: db says '$db_row', output says '$entries $sum 11'"; exit 1; }
done
[[ $(sqlite3 "$db" 'select count(distinct run_id) from demo_timecards') -eq 25 ]] || { echo "FAIL: expected 25 distinct runs in the db"; exit 1; }
[[ $(sqlite3 "$db" 'select count(distinct hours) from demo_timecards') -ge 6 ]] || { echo "FAIL: hours do not look random"; exit 1; }
leftover=$(find "$data/CobolWeird" -name 'run-*.sql')
[[ -z $leftover ]] || { echo "FAIL: SQL scripts left behind after successful runs: $leftover"; exit 1; }

# 3. The demo_only CHECK constraint is real: a non-demo row must be refused.
if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values('x','x',1,1,0)" 2>/dev/null; then
    echo "FAIL: db accepted a non-demo row"; exit 1
fi
echo "OK: 25 runs, each stopped when it should, committed to SQLite, all marked DEMO ONLY"
