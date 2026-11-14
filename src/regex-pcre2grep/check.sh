#!/usr/bin/env bash
# Checks the rules of the regex challenge for the pcre2grep track. Uses a throwaway data dir.
# Needs a pcre2grep built with callout scripts (see README.md); set PCRE2GREP to point at it.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data
db=$data/RegexPcre2grep/demo-timecards.db
here=$PWD

# 1. The host has no loop keywords, runs exactly one pcre2grep, and the callouts may only run an
#    allow-list of programs (never a shell or an interpreter).
code=$(grep -Ev '^\s*(#|$)' timecards.sh)
if grep -Eqw 'for|foreach|while|until|goto|select' <<<"$code"; then
    echo "FAIL: loop keyword found in timecards.sh"; exit 1
fi
[[ $(grep -c '"\$PCRE2GREP" "\$(cat' <<<"$code") -eq 1 ]] || { echo "FAIL: expected exactly one pcre2grep run"; exit 1; }
progs=$(grep -o '(?C{/[^|}]*' timecards.sh | sed 's/(?C{//' | sort -u | paste -sd' ')
[[ $progs == "/bin/sleep /usr/bin/sqlite3 /usr/bin/test" ]] || { echo "FAIL: callouts run unexpected programs: $progs"; exit 1; }

# 2. A pcre2grep without callout support must be refused loudly (only testable if one is installed).
if [[ -x /usr/bin/pcre2grep ]] && ! /usr/bin/pcre2grep --help 2>&1 | grep -q 'All callout scripts'; then
    rc=0; PCRE2GREP=/usr/bin/pcre2grep ./timecards.sh >/dev/null 2>&1 || rc=$?
    [[ $rc -eq 2 ]] || { echo "FAIL: callout-less pcre2grep was not refused (exit $rc)"; exit 1; }
fi

# 3. Run it a bunch of times; every run must print a sane record set, and the SQLite rows must agree with it.
for i in $(seq 1 25); do
    out=$("$here/timecards.sh" 2>"$data/err")
    run=$(sed -nE 's/^# DEMO ONLY run ([0-9]+)$/\1/p' <<<"$out")
    [[ -n $run ]] || { echo "FAIL run $i: no run id"; echo "$out"; exit 1; }
    grep -q '^# the match now returns false, on purpose$' <<<"$out" || { echo "FAIL run $i: no false-return line"; echo "$out"; exit 1; }
    commit=$(grep '^# committed' <<<"$out")
    total=$(sed -E 's/.*total=([0-9]+).*/\1/' <<<"$commit")
    entries=$(sed -E 's/.*entries=([0-9]+).*/\1/' <<<"$commit")
    rows=$(grep -cE '^(Meetings|Coding|Debugging|Learning)	' <<<"$out" || true)
    [[ $rows -eq $entries ]] || { echo "FAIL run $i: $rows rows but entries=$entries"; exit 1; }
    awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ && ($2 < 10 || $2 > 19) { bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: hours out of 10-19"; exit 1; }
    # Stop rule: three entries only when the first three exceed 40; four only when they do not (exactly 40 continues).
    first3=$(awk -F'\t' '/^(Meetings|Coding|Debugging)\t/ { s += $2 } END { print s + 0 }' <<<"$out")
    (( entries == 3 && first3 > 40 || entries == 4 && first3 <= 40 )) || { echo "FAIL run $i: stop rule wrong (first three = $first3, entries = $entries)"; exit 1; }
    # The stop rule announces itself on stderr (a named CHECK constraint) exactly when the total ended over 40, and nothing else does.
    stops=$(grep -c 'CHECK constraint failed: stop rule fired: total exceeds 40' "$data/err" || true)
    others=$(grep -vc 'CHECK constraint failed: stop rule fired: total exceeds 40' "$data/err" || true)
    (( total > 40 ? stops == 1 : stops == 0 )) || { echo "FAIL run $i: expected stop-rule stderr line $(( total > 40 )) time(s), saw $stops"; exit 1; }
    [[ $others -eq 0 ]] || { echo "FAIL run $i: unexpected stderr:"; cat "$data/err"; exit 1; }
    # The rows are really in SQLite and agree with what was printed.
    db_row=$(sqlite3 "$db" "select count(*) || ' ' || coalesce(sum(hours),0) || ' ' || coalesce(max(running_total),0) || ' ' || coalesce(min(demo_only),0) || coalesce(max(demo_only),0) from demo_timecards where run_id = $run")
    [[ $db_row == "$entries $total $total 11" ]] || { echo "FAIL run $i: db says '$db_row', output says '$entries $total $total 11'"; exit 1; }
done
[[ $(sqlite3 "$db" 'select count(*) from runs') -eq 25 ]] || { echo "FAIL: expected 25 runs in the db"; exit 1; }
[[ $(sqlite3 "$db" 'select count(*) from stop_rule') -eq 0 ]] || { echo "FAIL: stop_rule probe rows were left behind"; exit 1; }

# 4. The demo_only CHECK constraint is real: a non-demo row must be refused.
if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values(1,'x',10,10,0)" 2>/dev/null; then
    echo "FAIL: db accepted a non-demo row"; exit 1
fi
echo "OK: one pcre2grep; 25 runs, each stopped when it should, wrote to SQLite, and returned false"
