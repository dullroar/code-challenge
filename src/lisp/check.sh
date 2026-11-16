#!/usr/bin/env bash
# Checks the rules of the challenge for the Common Lisp entry. Uses a throwaway data dir.
# Set SBCL=/path/to/sbcl if it is not on your PATH.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data
db=$data/Lisp/demo-timecards.db
run() { "${SBCL:-sbcl}" --script timecards.lisp "$@"; }

# 1. Static: the demo disclaimer is there, nothing touches a network, the challenge is the one LOOP in draw-cards,
#    and the file compiles with no warnings or style warnings.
grep -q 'DEMO ONLY' timecards.lisp || { echo "FAIL: no DEMO ONLY marker in timecards.lisp"; exit 1; }
if grep -Eqi 'http|socket|curl|wget' timecards.lisp; then echo "FAIL: network-looking text in timecards.lisp"; exit 1; fi
sed -n '/^(defun draw-cards/,/^$/p' timecards.lisp | grep -q '(loop for number from 1' || { echo "FAIL: draw-cards is not a LOOP"; exit 1; }
sed -n '/^(defun draw-cards/,/^$/p' timecards.lisp | grep -q 'until (> total +limit+)' || { echo "FAIL: draw-cards has no UNTIL stop rule"; exit 1; }
compile_out=$("${SBCL:-sbcl}" --noinform --non-interactive \
    --eval "(multiple-value-bind (fasl warnings-p failure-p) (compile-file \"timecards.lisp\" :output-file \"$data/tc.fasl\") (declare (ignore fasl)) (sb-ext:exit :code (if (or warnings-p failure-p) 1 0)))" 2>&1) \
    || { echo "FAIL: compile-file reported warnings"; echo "$compile_out"; exit 1; }

# 1b. The calendar arithmetic is hand-written, so compare it with date(1) on awkward dates
#     (year boundaries, 53-week years, leap days, the 1900 and 2100 century rules).
for d in 1999-12-31 2000-01-01 2000-02-29 2015-12-31 2016-01-01 2018-12-31 2019-12-30 2020-12-31 \
         2021-01-01 2021-01-03 2021-01-04 2024-12-30 2024-12-31 2026-01-01 2026-12-31 2027-01-01 \
         2027-01-03 2027-01-04 2032-12-31 2033-01-01 2100-03-01 2026-11-16; do
    want=$(date -d "$d" +%G-W%V)
    got=$(XDG_DATA_HOME=$data/iso run "$d" | sed -nE '2s/^[A-Za-z]+\t[0-9]+\t[0-9]+\t([^\t]+)\t.*/\1/p')
    [[ $got == "$want" ]] || { echo "FAIL: ISO week of $d is $got, date(1) says $want"; exit 1; }
done

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
    [[ $db_rows == "$(cut -f1-4 <<<"$(printf '%s\n' "${rows[@]}")")" ]] || { echo "FAIL run $i: db rows differ from the printed rows"; exit 1; }
done
[[ $(sqlite3 "$db" 'select count(distinct run_id) from demo_timecards') -eq 25 ]] || { echo "FAIL: expected 25 distinct runs in the db"; exit 1; }
[[ $(sqlite3 "$db" 'select count(distinct hours) from demo_timecards') -ge 6 ]] || { echo "FAIL: hours do not look random"; exit 1; }

# 3. The demo_only CHECK constraint is real: a non-demo row must be refused.
if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values('x','x',1,1,0)" 2>/dev/null; then
    echo "FAIL: db accepted a non-demo row"; exit 1
fi
echo "OK: 25 runs, each stopped when it should, committed to SQLite, all marked DEMO ONLY; ISO weeks agree with date(1)"
