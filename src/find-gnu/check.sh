#!/usr/bin/env bash
# Checks the rules of the challenge for the GNU find entry. Uses throwaway data, scratch and shim dirs.
# Needs GNU find (the line uses -fprintf, %d, %T, -regex, -D and -O). It runs the entry at every
# optimizer level, -O0 to -O3, and insists the answer never changes.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); tmp=$(mktemp -d); shim=$(mktemp -d)
trap 'rm -rf "$data" "$tmp" "$shim"' EXIT
export XDG_DATA_HOME=$data TMPDIR=$tmp
db=$data/FindGnu/demo-timecards.db
fail() { echo "FAIL: $*"; exit 1; }
real_mktemp=$(command -v mktemp)

# GNU find, whatever else is installed
gfind=$(command -v find)
"$gfind" --version 2>&1 | head -1 | grep -q 'GNU findutils' || { [[ -x /usr/bin/find ]] && gfind=/usr/bin/find; }
"$gfind" --version 2>&1 | head -1 | grep -q 'GNU findutils' || fail "this entry needs GNU find; found: $("$gfind" --version 2>&1 | head -1)"
mkdir "$shim/bin"; ln -s "$gfind" "$shim/bin/find"; export PATH="$shim/bin:$PATH"

# 1. The ridiculous constraint is real: exactly one find, no loop or branch keyword, only the GNU
#    primaries listed here, -exec runs only mkdir and mktemp, and the line is what build-line.py prints.
code=$(grep -Ev '^\s*(#|$)' timecards.sh)
[[ $(grep -c '^find ' timecards.sh) -eq 1 ]] || fail "expected exactly one 'find ' line"
[[ $(grep -ow find <<<"$code" | wc -l) -eq 1 ]] || fail "the word find appears more than once in the code"
if grep -Eqw 'for|while|until|case|esac|if|then|elif|select' <<<"$code"; then fail "loop or branch keyword in timecards.sh"; fi
line=$(grep '^find ' timecards.sh | sed 's# 3>&1 >/dev/null$##')
prims=$(sed 's/mktemp -d/mktemp/g' <<<"$line" | grep -oE '(^| )-[a-zA-Z]+' | tr -d ' ' | sort -u | paste -sd' ')
[[ $prims == "-O -exec -fprintf -name -o -path -regex -regextype" ]] || fail "find primaries are '$prims'"
progs=$(grep -oE -- '-exec [a-z]+' <<<"$line" | cut -d' ' -f2 | sort -u | paste -sd' ')
[[ $progs == "mkdir mktemp" ]] || fail "-exec runs '$progs', expected 'mkdir mktemp'"
if grep -Eq -- '-(delete|print0?|printf|ok|execdir|ls) ' <<<"$line"; then fail "a forbidden action is in the line"; fi
if command -v python3 >/dev/null; then
    [[ $(python3 -I build-line.py) == "$line" ]] || fail "timecards.sh is out of step with build-line.py"
else
    echo "note: python3 not found; skipped the build-line.py comparison"
fi

# A fake mktemp for the forced-dice scenarios: -d TEMPLATE takes its next name from $FAKE_NAMES.
cat >"$shim/mktemp.fake" <<'EOF'
#!/bin/sh
if [ "$#" -ne 2 ] || [ "$1" != -d ]; then exec "$REAL_MKTEMP" "$@"; fi
n=$(cat "$FAKE_N"); n=$((n + 1)); echo "$n" >"$FAKE_N"
name=$(printf '%s\n' $FAKE_NAMES | sed -n "${n}p")
dir=${2%XXXXXX}$name
mkdir "$dir" && printf '%s\n' "$dir"
EOF
chmod +x "$shim/mktemp.fake"
cats=(Meetings Coding Debugging Learning Meetings)
dice_char=(a g m s y 4 A G M S)   # first character of each group of six: hours 10..19
rows() { grep -E $'^(Meetings|Coding|Debugging|Learning)\t' <<<"$1" || true; }

# validate LABEL OUTPUT: rows sane, stop exact, ISO week right, SQLite agrees.
validate() {
    local label=$1 out=$2 w1=$3 w2=$4 run commit total entries r
    run=$(sed -nE 's/^# DEMO ONLY run ([0-9]+)$/\1/p' <<<"$out")
    [[ -n $run ]] || fail "$label: no run id"
    commit=$(grep '^# committed' <<<"$out")
    total=$(sed -E 's/.*total=([0-9]+).*/\1/' <<<"$commit"); entries=$(sed -E 's/.*entries=([0-9]+).*/\1/' <<<"$commit")
    r=$(rows "$out")
    awk -F'\t' -v total="$total" -v entries="$entries" -v w1="$w1" -v w2="$w2" '
        BEGIN { split("Meetings Coding Debugging Learning Meetings", want, " ") }
        { n++; if ($1 != want[n]) { print "category " $1 " at row " n; exit 1 }
          if ($2 < 10 || $2 > 19) { print "hours out of range: " $0; exit 1 }
          if ($3 != prev + $2) { print "bad running total: " $0; exit 1 }
          if (prev > 40) { print "kept going after 40: " $0; exit 1 }
          if ($4 != w1 && $4 != w2) { print "ISO week " $4 " is not " w1 " or " w2; exit 1 }
          if ($5 != "DEMO ONLY") { print "missing DEMO ONLY: " $0; exit 1 }
          prev = $3 }
        END { if (n != entries || prev != total) { print "summary disagrees with rows"; exit 1 }
              if (prev <= 40) { print "stopped early at " prev; exit 1 } }' <<<"$r" || fail "$label (see above)"
    hours_seen+=$(awk -F'\t' '{ printf "%s ", $2 }' <<<"$r")
    local db_row
    db_row=$(sqlite3 "$db" "select count(*) || ' ' || coalesce(max(running_total),0) || ' ' || min(demo_only) || max(demo_only) from demo_timecards where run_id = $run")
    [[ $db_row == "$entries $total 11" ]] || fail "$label: db says '$db_row', output says '$entries $total 11'"
}

hours_seen=""
for O in 0 1 2 3; do
    export FIND_O=$O
    # 2. Random runs at this optimizer level.
    for i in $(seq 1 15); do
        w1=$(date +%G-W%V)
        out=$(sh ./timecards.sh 2>"$data/err") || fail "[-O$O] run $i: timecards.sh exited $?"
        w2=$(date +%G-W%V)
        [[ -z $(ls -A "$tmp") ]] || fail "[-O$O] run $i: scratch folder left behind"
        validate "[-O$O] run $i" "$out" "$w1" "$w2"
        stops=$(grep -c 'CHECK constraint failed: stop rule fired: total exceeds 40' "$data/err" || true)
        others=$(grep -vc 'CHECK constraint failed: stop rule fired: total exceeds 40' "$data/err" || true)
        [[ $stops -eq 1 && $others -eq 0 ]] || { cat "$data/err"; fail "[-O$O] run $i: unexpected stderr"; }
    done

    # 3. Forced dice (same scenarios as the portable entry): the answer must not depend on the -O level.
    name_for() { local h=$1 mode=${2:-}; case $mode in y) printf 'xxxx%sY' "${dice_char[h-10]}" ;; yy) printf 'xxxxYZ' ;; *) printf 'xxxxx%s' "${dice_char[h-10]}" ;; esac; }
    forced() {
        local names="" expect="" t=0 k=0 spec h mode got got_rows
        for spec in $1; do
            h=${spec%%:*}; mode=""; [[ $spec == *:* ]] && mode=${spec#*:}
            names+="$(name_for "$h" "$mode") "; [[ $mode == yy ]] && h=10
            t=$((t + h)); expect+="${cats[k]}"$'\t'"$h"$'\t'"$t"$'\n'; k=$((k + 1))
        done
        echo 0 >"$data/n"; cp "$shim/mktemp.fake" "$shim/bin/mktemp"
        got=$(REAL_MKTEMP=$real_mktemp FAKE_N=$data/n FAKE_NAMES=$names sh ./timecards.sh 2>/dev/null) || fail "[-O$O] forced '$1': exited $?"
        rm -f "$shim/bin/mktemp"
        got_rows=$(rows "$got" | cut -f1-3)
        [[ $got_rows == "${expect%$'\n'}" ]] || { echo "--- expected"; printf '%s' "$expect"; echo "--- got"; echo "$got_rows"; fail "[-O$O] forced '$1' differs"; }
    }
    forced "10 10 10 10 10"; forced "19 19 19"; forced "11 12 13 14"; forced "15 16 17"; forced "18 19 10"
    forced "11:y 10:yy 19:y 10"; forced "10 10 10 10 11"
    echo "ok [-O$O]: 15 random runs + 7 forced-dice scenarios"
done
unset FIND_O
distinct=$(tr ' ' '\n' <<<"$hours_seen" | grep . | sort -u | wc -l)
[[ $distinct -ge 8 ]] || fail "only $distinct distinct hour values in 60 runs; is it random?"

# 4. find profiles itself: FIND_D=rates prints each test's real success rate, and the answer is unchanged.
w1=$(date +%G-W%V)
out=$(FIND_D=rates sh ./timecards.sh 2>"$data/err") || fail "FIND_D=rates run failed"
w2=$(date +%G-W%V)
validate "FIND_D=rates" "$out" "$w1" "$w2"
grep -q 'real success rate' "$data/err" || fail "FIND_D=rates printed no success rates"
evals=$(grep -o 'real success rate [0-9]*/[0-9]*' "$data/err" | awk -F'[ /]' '{ t += $5 } END { print t }')
echo "ok: find -D rates profiled one run: $evals test evaluations"

# 5. The demo_only CHECK constraint is real: a non-demo row must be refused.
if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values(1,'x',10,10,0)" 2>/dev/null; then
    fail "db accepted a non-demo row"
fi
ver=$("$gfind" --version | head -1)
echo "OK: one GNU find; -O0..-O3 give the same answers; 60 random runs, 28 forced-dice runs, profile, constraint ($ver)"
