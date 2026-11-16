#!/usr/bin/env bash
# Checks the rules of the challenge for the Common Lisp "weird" entry. Uses a throwaway data dir.
# Set SBCL=/path/to/sbcl if it is not on your PATH.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data
db=$data/LispWeird/demo-timecards.db
run() { "${SBCL:-sbcl}" --script "${1:-timecards.lisp}"; }

# 1. Static: the stunt is real. Below the RUN TIME marker (comments removed) there is no loop, no
#    conditional and no mapping function; the stop rule is the OR method combination and nothing else.
grep -q 'DEMO ONLY' timecards.lisp || { echo "FAIL: no DEMO ONLY marker in timecards.lisp"; exit 1; }
if grep -Eqi 'http|socket|curl|wget' timecards.lisp; then echo "FAIL: network-looking text in timecards.lisp"; exit 1; fi
code=$(awk '/^;;; -+ RUN TIME/{p=1} p' timecards.lisp | sed 's/;.*//')
[[ -n $code ]] || { echo "FAIL: no RUN TIME marker"; exit 1; }
if grep -Eq '\((loop|do|do\*|dolist|dotimes|mapc|mapcar|mapcan|maplist|map|maphash|reduce|if|when|unless|cond|case|ecase|typecase|tagbody|go|block|return|return-from|catch|throw|handler-case)[ )]' <<<"$code"; then
    echo "FAIL: loop, conditional or mapping construct below the RUN TIME marker"; grep -nE '\((loop|do|dolist|dotimes|mapc|mapcar|if|when|unless|cond|case) ' <<<"$code"; exit 1
fi
grep -q '(:method-combination or)' timecards.lisp || { echo "FAIL: PUNCH does not use the OR method combination"; exit 1; }
[[ $(grep -c '^(defcard [0-9]' timecards.lisp) -eq 5 ]] || { echo "FAIL: expected five DEFCARD forms"; exit 1; }
[[ $(sed 's/;.*//' timecards.lisp | grep -c '(> (total ledger) 40)') -eq 1 ]] || { echo "FAIL: the over-40 test should appear exactly once"; exit 1; }

# 2. The mechanism is what stops it: swap OR for PROGN (run every method) and every run must deal all
#    five cards, however large the total. With OR, the same file stops early on most runs.
sed -e 's/(:method-combination or)/(:method-combination progn)/' -e 's/defmethod punch or/defmethod punch progn/' \
    timecards.lisp > "$data/progn.lisp"
for i in 1 2 3 4 5; do
    n=$(run "$data/progn.lisp" | grep -cE '^(Meetings|Coding|Debugging|Learning)	' || true)
    [[ $n -eq 5 ]] || { echo "FAIL: with PROGN instead of OR run $i dealt $n cards, wanted 5"; exit 1; }
done
rm -rf "$data/LispWeird"
short=0
for i in $(seq 1 12); do
    n=$(run | grep -cE '^(Meetings|Coding|Debugging|Learning)	' || true)
    (( n < 5 )) && short=$((short + 1))
done
(( short >= 1 )) || { echo "FAIL: with OR no run stopped before card 5 in 12 tries"; exit 1; }
rm -rf "$data/LispWeird"

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
done
[[ $(sqlite3 "$db" 'select count(distinct run_id) from demo_timecards') -eq 25 ]] || { echo "FAIL: expected 25 distinct runs in the db"; exit 1; }
[[ $(sqlite3 "$db" 'select count(distinct hours) from demo_timecards') -ge 6 ]] || { echo "FAIL: hours do not look random"; exit 1; }

# 3. The demo_only CHECK constraint is real: a non-demo row must be refused.
if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values('x','x',1,1,0)" 2>/dev/null; then
    echo "FAIL: db accepted a non-demo row"; exit 1
fi
echo "OK: 25 runs; the OR method combination is the stop rule (PROGN deals all five); committed to SQLite, all marked DEMO ONLY"
