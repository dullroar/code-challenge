#!/usr/bin/env bash
# Checks the rules of the regex challenge for the Perl track. Uses a throwaway data dir.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data
db=$data/RegexPerl/demo-timecards.db

# 1. The file is one statement (everything but comments, blank lines and `use` lines is a single line),
#    with exactly one top-level match and no loop keywords anywhere outside comments.
code=$(grep -Ev '^\s*(#|$)|^use ' timecards.pl)
[[ $(wc -l <<<"$code") -eq 1 ]] || { echo "FAIL: expected exactly one statement line, got $(wc -l <<<"$code")"; exit 1; }
[[ $(grep -o ' =~ m{' <<<"$code" | wc -l) -eq 1 ]] || { echo "FAIL: expected exactly one top-level match"; exit 1; }
if grep -Eqw 'for|foreach|while|until|goto' <<<"$code"; then
    echo "FAIL: loop keyword found in timecards.pl"; exit 1
fi

# 2. Run it a bunch of times; every run must print a sane record set, and the SQLite rows must agree with it.
for i in $(seq 1 25); do
    out=$(perl timecards.pl)
    run=$(sed -nE 's/^# DEMO ONLY run (.+)$/\1/p' <<<"$out")
    [[ -n $run ]] || { echo "FAIL run $i: no run id"; echo "$out"; exit 1; }
    grep -q '^# the match now returns false, on purpose$' <<<"$out" || { echo "FAIL run $i: no false-return line"; echo "$out"; exit 1; }
    commit=$(grep '^# committed' <<<"$out")
    total=$(sed -E 's/.*total=([0-9]+).*/\1/' <<<"$commit")
    entries=$(sed -E 's/.*entries=([0-9]+).*/\1/' <<<"$commit")
    rows=$(grep -cE '^(Meetings|Coding|Debugging|Learning)	' <<<"$out" || true)
    [[ $rows -eq $entries ]] || { echo "FAIL run $i: $rows rows but entries=$entries"; exit 1; }
    (( total > 40 )) || { echo "FAIL run $i: stopped early at $total"; exit 1; }
    (( entries >= 3 && entries <= 5 )) || { echo "FAIL run $i: $entries entries; a run has 3 to 5"; exit 1; }
    (( total <= 40 + 19 )) || { echo "FAIL run $i: overshot ($total)"; exit 1; }
    awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ && ($2 < 10 || $2 > 19) { bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: hours out of 10-19"; exit 1; }
    # The SQLite transaction really committed, and agrees with what was printed.
    db_row=$(sqlite3 "$db" "select count(*) || ' ' || coalesce(sum(hours),0) || ' ' || coalesce(min(demo_only),0) || coalesce(max(demo_only),0) from demo_timecards where run_id = '$run'")
    [[ $db_row == "$entries $total 11" ]] || { echo "FAIL run $i: db says '$db_row', output says '$entries $total 11'"; exit 1; }
done
[[ $(sqlite3 "$db" 'select count(distinct run_id) from demo_timecards') -eq 25 ]] || { echo "FAIL: expected 25 distinct runs in the db"; exit 1; }

# 3. The demo_only CHECK constraint is real: a non-demo row must be refused.
if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values('x','x',1,1,0)" 2>/dev/null; then
    echo "FAIL: db accepted a non-demo row"; exit 1
fi
# 4. Exactly 40 continues. Four 10-hour cards total exactly 40, so a fifth card must be drawn: Meetings again, total 50.
#    A copy of the program with every card worth 10 hours makes that the only possible run.
sed 's/10+int rand 10/10/' timecards.pl > "$data/fixed.pl"
! grep -q 'rand 10' "$data/fixed.pl" || { echo "FAIL: the exactly-40 test could not rewrite the draw in timecards.pl"; exit 1; }
out=$(perl "$data/fixed.pl")
mapfile -t rows < <(grep -E '^(Meetings|Coding|Debugging|Learning)	' <<<"$out")
(( ${#rows[@]} == 5 )) || { echo "FAIL: all-10 cards must give five rows (exactly 40 continues)"; echo "$out"; exit 1; }
[[ ${rows[3]} == Learning* && ${rows[4]} == Meetings*$'\t'10$'\t'50$'\t'* ]] || { echo "FAIL: the fourth card must be Learning and the fifth Meetings with total 50"; echo "$out"; exit 1; }

echo "OK: single statement; 25 runs, each stopped when it should, committed to SQLite, and returned false; exactly 40 continued to a fifth card"
