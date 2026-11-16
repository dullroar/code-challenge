#!/usr/bin/env bash
# Checks the rules of the challenge for the m4 entry. Uses a throwaway data dir.
# Set M4=/path/to/m4 if it is not on your PATH. Needs GNU m4.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data
db=$data/M4/demo-timecards.db
run() { "${M4:-m4}" "$@" timecards.m4; }

# 1. Static: the disclaimer is there, nothing touches a network, and the only things that leave m4 are
#    one syscmd (the final sqlite3 call) and a few esyscmd lookups (seed, clock, week).
grep -q 'DEMO ONLY' timecards.m4 || { echo "FAIL: no DEMO ONLY marker in timecards.m4"; exit 1; }
if grep -Eqi 'http|socket|curl|wget' timecards.m4; then echo "FAIL: network-looking text in timecards.m4"; exit 1; fi
code=$(grep -v '^dnl' timecards.m4)
[[ $(grep -oE '(^|[^e])syscmd\(' <<<"$code" | wc -l) -eq 1 ]] || { echo "FAIL: expected exactly one syscmd"; exit 1; }
[[ $(grep -oE 'esyscmd\(' <<<"$code" | wc -l) -eq 3 ]] || { echo "FAIL: expected exactly three esyscmd calls (seed, run id, week)"; exit 1; }
grep -qE 'tc_card\(\)\]\)\]\)' timecards.m4 || { echo "FAIL: tc_card no longer ends by expanding itself"; exit 1; }
if grep -Eq '(for|while) ' <<<"$(grep -oE "syscmd\(.*" timecards.m4)"; then echo "FAIL: shell loop in the syscmd line"; exit 1; fi

# 2. The arithmetic is m4's own: with a pinned seed the output must equal an independent Park-Miller
#    computed here in bash (64-bit), card for card, including the stop rule and the category cycle.
cats=(Meetings Coding Debugging Learning)
expected() {   # seed week -> the rows, as the program should print them
    local seed=$1 week=$2 total=0 n=0 hours
    while (( total <= 40 )); do
        seed=$(( 16807 * seed % 2147483647 ))
        hours=$(( 10 + seed / 1024 % 10 ))
        total=$(( total + hours ))
        printf '%s\t%d\t%d\t%s\tDEMO ONLY\n' "${cats[n % 4]}" "$hours" "$total" "$week"
        n=$(( n + 1 ))
    done
}
for seed in 1 2 12345 99999 1000003 2147483646 $(seq 7000 7040); do
    want=$(expected "$seed" 2026-W01)
    got=$(run -Dtc_seed="$seed" -Dtc_week=2026-W01 | grep -E '^(Meetings|Coding|Debugging|Learning)	')
    [[ $got == "$want" ]] || { echo "FAIL: seed $seed: output differs from the bash reference"; diff <(echo "$want") <(echo "$got") || true; exit 1; }
done

# 3. The mechanism: if tc_card stops expanding itself, exactly one card is dealt.
sed 's/\[tc_card()\])\])/[])])/' timecards.m4 > "$data/once.m4"
n=$("${M4:-m4}" -Dtc_seed=12345 "$data/once.m4" | grep -cE '^(Meetings|Coding|Debugging|Learning)	' || true)
[[ $n -eq 1 ]] || { echo "FAIL: without the self-expansion $n cards were dealt, wanted 1"; exit 1; }
rm -rf "$data/M4"

# 4. Run it a bunch of times for real (OS seed, real date); every run must print a sane record set,
#    and the SQLite rows must agree with it.


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
    [[ $db_rows == "$(cut -f1-4 <<<"$(printf '%s\n' "${rows[@]}")")" ]] || { echo "FAIL run $i: db rows differ from the printed rows"; exit 1; }
done
[[ $(sqlite3 "$db" 'select count(distinct run_id) from demo_timecards') -eq 25 ]] || { echo "FAIL: expected 25 distinct runs in the db"; exit 1; }
[[ $(sqlite3 "$db" 'select count(distinct hours) from demo_timecards') -ge 6 ]] || { echo "FAIL: hours do not look random"; exit 1; }

# 3. The demo_only CHECK constraint is real: a non-demo row must be refused.
if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values('x','x',1,1,0)" 2>/dev/null; then
    echo "FAIL: db accepted a non-demo row"; exit 1
fi
echo "OK: pinned seeds match the bash reference; self-expansion is the loop; 25 real runs stopped when they should, committed to SQLite, all marked DEMO ONLY"
