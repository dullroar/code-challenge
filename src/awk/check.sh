#!/usr/bin/env bash
# Checks the rules of the challenge for the AWK entry. Uses a throwaway data dir.
# The program is portable awk, so with no AWK set this runs the whole check once under every awk it
# can find (gawk, mawk, original-awk = the one-true-awk, busybox awk). Choose your own with
#   AWKS='gawk|mawk' ./check.sh        (names separated by |)    or    AWK=gawk ./check.sh
set -euo pipefail
self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
cd "$(dirname "$0")"

if [[ -z ${AWK:-} ]]; then
    IFS='|' read -ra candidates <<<"${AWKS:-gawk|mawk|original-awk|busybox awk}"
    found=()
    for c in "${candidates[@]}"; do
        read -ra words <<<"$c"
        command -v "${words[0]}" >/dev/null || continue
        if [[ ${words[0]} == busybox ]]; then busybox --list 2>/dev/null | grep -qx awk || continue; fi
        found+=("$c")
    done
    (( ${#found[@]} )) || { echo "FAIL: no awk found"; exit 1; }
    for c in "${found[@]}"; do echo "--- awk: $c"; AWK="$c" "$self" || exit 1; done
    echo "ALL OK under: ${found[*]}"
    exit 0
fi

data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data
db=$data/Awk/demo-timecards.db
run() { $AWK -f timecards.awk; }

# 1. Static: the disclaimer is there, nothing touches a network, and the challenge is one while loop on the limit.
grep -q 'DEMO ONLY' timecards.awk || { echo "FAIL: no DEMO ONLY marker in timecards.awk"; exit 1; }
if grep -Eqi 'http|socket|curl|wget|/inet/' timecards.awk; then echo "FAIL: network-looking text in timecards.awk"; exit 1; fi
grep -q 'while (total <= LIMIT) {' timecards.awk || { echo "FAIL: no while loop on the limit"; exit 1; }
# gawk's own linter, in POSIX mode: no gawk extensions, no shadowed or uninitialized variables.
if command -v gawk >/dev/null; then
    lint=$(gawk --lint --posix -f timecards.awk 2>&1 >/dev/null || true)
    [[ -z $lint ]] || { echo "FAIL: gawk --lint --posix has complaints:"; echo "$lint"; exit 1; }
    rm -rf "$data/Awk"
fi

# 2. Run it a bunch of times; every run must print a sane record set, and the SQLite rows must agree with it.
cats=(Meetings Coding Debugging Learning)
for i in $(seq 1 25); do
    out=$(run)
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
        (( hours >= 10 && hours <= 19 )) || { echo "FAIL run $i: hours $hours out of 10-19"; exit 1; }
        (( sum <= 40 )) || { echo "FAIL run $i: kept going after the total passed 40"; exit 1; }
        sum=$(( sum + hours )); n=$(( n + 1 ))
        (( running == sum )) || { echo "FAIL run $i: running total $running, wanted $sum"; exit 1; }
        [[ $week =~ ^[0-9]{4}-W[0-9]{2}$ ]] || { echo "FAIL run $i: bad ISO week '$week'"; exit 1; }
        [[ $mark == "DEMO ONLY" ]] || { echo "FAIL run $i: row not marked DEMO ONLY"; exit 1; }
    done
    (( sum == total && sum > 40 )) || { echo "FAIL run $i: stopped at $sum (summary says $total); must stop once over 40"; exit 1; }
    db_row=$(sqlite3 "$db" "select count(*) || ' ' || coalesce(sum(hours),0) || ' ' || coalesce(min(demo_only),0) || coalesce(max(demo_only),0) from demo_timecards where run_id = '$run_id'")
    [[ $db_row == "$entries $total 11" ]] || { echo "FAIL run $i: db says '$db_row', output says '$entries $total 11'"; exit 1; }
    db_rows=$(sqlite3 -separator $'\t' "$db" "select category, hours, running_total, iso_week from demo_timecards where run_id = '$run_id' order by id")
    [[ $db_rows == "$(printf '%s\n' "${rows[@]}" | cut -f1-4)" ]] || { echo "FAIL run $i: db rows differ from the printed rows"; exit 1; }
done
[[ $(sqlite3 "$db" 'select count(distinct run_id) from demo_timecards') -eq 25 ]] || { echo "FAIL: expected 25 distinct runs in the db"; exit 1; }
[[ $(sqlite3 "$db" 'select count(distinct hours) from demo_timecards') -ge 6 ]] || { echo "FAIL: hours do not look random"; exit 1; }

# 3. The demo_only CHECK constraint is real: a non-demo row must be refused.
if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values('x','x',1,1,0)" 2>/dev/null; then
    echo "FAIL: db accepted a non-demo row"; exit 1
fi
echo "OK: 25 runs, each stopped when it should, committed to SQLite, all marked DEMO ONLY"
