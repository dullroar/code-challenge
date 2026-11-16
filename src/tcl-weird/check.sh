#!/usr/bin/env bash
# Checks the rules of the challenge for the Tcl "weird" entry. Uses a throwaway data dir.
# Set TCLSH=/path/to/tclsh if it is not on your PATH. Needs Tcl 8.6 and its sqlite3 package.
# The Tk window is tested only when Xvfb (or a display) is available; otherwise that step is skipped, and says so.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data
db=$data/TclWeird/demo-timecards.db
tclsh=${TCLSH:-tclsh}
run() { "$tclsh" "${1:-timecards.tcl}"; }
cards() { grep -cE '^(Meetings|Coding|Debugging|Learning)	' || true; }

# 1. Static: the stunt is real. With comments removed the Tcl has no loop command, only the two
#    hook procs (call, unknown) are defined in Tcl, and the recursive trigger is switched on.
grep -q 'DEMO ONLY' timecards.tcl || { echo "FAIL: no DEMO ONLY marker in timecards.tcl"; exit 1; }
if grep -Eqi 'http|socket|curl|wget|exec ' timecards.tcl; then echo "FAIL: network or process text in timecards.tcl"; exit 1; fi
code=$(sed -e 's/^ *#.*//' -e 's/ -- .*//' -e 's/^ *-- .*//' timecards.tcl)
if grep -Eq '(^|[^a-z_])(while|for|foreach|lmap|dict for|repeat)[ {]' <<<"$code"; then echo "FAIL: a loop command appears in the file"; exit 1; fi
[[ $(grep -c '^proc ' <<<"$code") -eq 2 ]] || { echo "FAIL: expected exactly two Tcl procs (call, unknown)"; exit 1; }
grep -q '^db function tcl call' <<<"$code" || { echo "FAIL: no tcl() SQL function"; exit 1; }
grep -q 'PRAGMA recursive_triggers = ON' <<<"$code" || { echo "FAIL: recursive triggers are not switched on"; exit 1; }
grep -q 'CREATE TEMP TRIGGER next_card AFTER INSERT' <<<"$code" || { echo "FAIL: no trigger"; exit 1; }

# 2. The mechanisms are what do the work.
#    a) Without recursive triggers the trigger fires only for the first INSERT, so only card 1 is
#       ever announced by it (born): exactly one card is printed.
sed 's/PRAGMA recursive_triggers = ON/PRAGMA recursive_triggers = OFF/' timecards.tcl > "$data/norecurse.tcl"
for i in 1 2 3 4 5; do
    n=$(run "$data/norecurse.tcl" | cards)
    [[ $n -eq 1 ]] || { echo "FAIL: without recursion run $i printed $n cards, wanted 1 (the trigger never fires for the card it inserts)"; exit 1; }
done
rm -rf "$data/TclWeird"
#    b) The hours really come from the row in the table: change the row's text and the data changes.
sed "s/'expr {10 + int(rand() \* 10)}'/'expr {19}'/" timecards.tcl > "$data/nineteen.tcl"
out=$(run "$data/nineteen.tcl")
[[ $(grep -cE '^(Meetings|Coding|Debugging|Learning)	19	' <<<"$out") -eq 3 ]] || { echo "FAIL: editing the hours row did not change the program"; echo "$out"; exit 1; }
grep -q 'fetched from SQLite by unknown: born category hours init runid week' <<<"$out" || { echo "FAIL: procs were not loaded from SQLite"; echo "$out"; exit 1; }
rm -rf "$data/TclWeird"
#    c) The temp tables and trigger are gone afterwards: the file on disk holds only the timecards.
run >/dev/null
[[ $(sqlite3 "$db" "select group_concat(name) from sqlite_master") == "demo_timecards" ]] || { echo "FAIL: the file holds more than the timecard table"; exit 1; }
rm -rf "$data/TclWeird"

# 3. The Tk window, whose widgets are rows too, headless: needs Xvfb (preferred) or a DISPLAY.
if command -v xvfb-run >/dev/null && command -v Xvfb >/dev/null; then
    runner=(xvfb-run -a)
elif [[ -n ${DISPLAY:-} ]]; then
    runner=()
else
    runner=(skip)
fi
if [[ ${runner[0]:-} == skip ]]; then
    echo "gui: SKIPPED (no Xvfb and no DISPLAY)"
else
    out=$(timeout 60 "${runner[@]}" "$tclsh" timecards.tcl --gui --seconds 1) || { echo "FAIL: --gui run failed or hung"; exit 1; }
    grep -q '^# the window was built from 8 rows of the ui table' <<<"$out" || { echo "FAIL: --gui did not build the window from the ui table"; echo "$out"; exit 1; }
    echo "gui: ok"
fi
rm -rf "$data/TclWeird"

# 4. Run it a bunch of times for real; every run must print a sane record set, and the SQLite rows must agree with it.
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
echo "OK: no loop command in the file; trigger recursion is the loop; the hours row drives the data; 25 runs stopped when they should, committed to SQLite, all marked DEMO ONLY"
