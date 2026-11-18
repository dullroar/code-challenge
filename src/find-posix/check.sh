#!/usr/bin/env bash
# Checks the rules of the challenge for the portable find entry. Uses throwaway data, scratch and shim
# dirs. It runs the whole entry once per find implementation it can see (GNU find, bfs, busybox), by
# putting a directory with a `find` symlink first on PATH. FINDS="name=/path ..." overrides the search.
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
data=$(mktemp -d); tmp=$(mktemp -d); shim=$(mktemp -d)
trap 'rm -rf "$data" "$tmp" "$shim"' EXIT
export XDG_DATA_HOME=$data TMPDIR=$tmp
db=$data/FindPosix/demo-timecards.db
fail() { echo "FAIL: $*"; exit 1; }
real_mktemp=$(command -v mktemp)

# 1. The ridiculous constraint is real. timecards.sh runs exactly one find, with no loop or branch
#    keyword anywhere; find uses four primaries (-path -name -o -exec); -exec runs only four programs;
#    and the line is exactly what build-line.py generates.
code=$(grep -Ev '^\s*(#|$)' timecards.sh)
[[ $(grep -c '^find t ' timecards.sh) -eq 1 ]] || fail "expected exactly one 'find t ...' line"
[[ $(grep -ow find <<<"$code" | wc -l) -eq 1 ]] || fail "the word find appears more than once in the code"
if grep -Eqw 'for|while|until|case|esac|if|then|elif|select' <<<"$code"; then fail "loop or branch keyword in timecards.sh"; fi
line=$(grep '^find t ' timecards.sh)
prims=$(sed 's/mktemp -d/mktemp/g' <<<"$line" | grep -oE '(^| )-[a-zA-Z]+' | tr -d ' ' | sort -u | paste -sd' ')
[[ $prims == "-exec -name -o -path" ]] || fail "find primaries are '$prims', expected '-exec -name -o -path'"
progs=$(grep -oE -- '-exec [a-z]+' <<<"$line" | cut -d' ' -f2 | sort -u | paste -sd' ')
[[ $progs == "date mkdir mktemp printf" ]] || fail "-exec runs '$progs', expected 'date mkdir mktemp printf'"
if command -v python3 >/dev/null; then
    [[ $(python3 -I build-line.py) == "$line" ]] || fail "timecards.sh is out of step with build-line.py"
else
    echo "note: python3 not found; skipped the build-line.py comparison"
fi

# 2. find implementations to test.
impls=()
if [[ -n ${FINDS:-} ]]; then
    read -ra impls <<<"$FINDS"
else
    pathfind=$(command -v find)
    case $("$pathfind" --version 2>&1 | head -1) in
        *GNU*) impls+=("gnu=$pathfind") ;;
        *bfs*) impls+=("bfs=$pathfind") ;;
        *) impls+=("find=$pathfind") ;;
    esac
    [[ $pathfind != /usr/bin/find && -x /usr/bin/find ]] && /usr/bin/find --version 2>&1 | grep -q GNU && impls+=("gnu=/usr/bin/find")
    command -v bfs >/dev/null && bfs --version >/dev/null 2>&1 && impls+=("bfs=$(command -v bfs)")
    command -v busybox >/dev/null && busybox find --help >/dev/null 2>&1 && impls+=("busybox=$(command -v busybox)")
fi
[[ ${#impls[@]} -gt 0 ]] || fail "no find implementation found"

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

# rows <output>: the table rows only
rows() { grep -E $'^(Meetings|Coding|Debugging|Learning)\t' <<<"$1" || true; }

for entry in "${impls[@]}"; do
    name=${entry%%=*}; path=${entry#*=}
    rm -rf "$shim/bin"; mkdir "$shim/bin"
    ln -s "$path" "$shim/bin/find"
    export PATH="$shim/bin:$PATH"
    runs=25

    # 3. Run it a bunch of times; every run must be a sane record set and SQLite must agree.
    hours_seen=""
    for i in $(seq 1 "$runs"); do
        w1=$(date +%G-W%V)
        out=$(sh ./timecards.sh 2>"$data/err") || fail "[$name] run $i: timecards.sh exited $?"
        w2=$(date +%G-W%V)
        [[ -z $(ls -A "$tmp") ]] || fail "[$name] run $i: scratch folder left behind: $(ls -A "$tmp")"
        run=$(sed -nE 's/^# DEMO ONLY run ([0-9]+)$/\1/p' <<<"$out")
        [[ -n $run ]] || fail "[$name] run $i: no run id"
        commit=$(grep '^# committed' <<<"$out")
        total=$(sed -E 's/.*total=([0-9]+).*/\1/' <<<"$commit")
        entries=$(sed -E 's/.*entries=([0-9]+).*/\1/' <<<"$commit")
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
                  if (prev <= 40) { print "stopped early at " prev; exit 1 } }' <<<"$r" \
            || fail "[$name] run $i (see above)"
        hours_seen+=$(awk -F'\t' '{ printf "%s ", $2 }' <<<"$r")
        # The stop rule announces itself on stderr (a named CHECK constraint), exactly once; nothing else does.
        stops=$(grep -c 'CHECK constraint failed: stop rule fired: total exceeds 40' "$data/err" || true)
        others=$(grep -vc 'CHECK constraint failed: stop rule fired: total exceeds 40' "$data/err" || true)
        [[ $stops -eq 1 && $others -eq 0 ]] || { cat "$data/err"; fail "[$name] run $i: unexpected stderr"; }
        db_row=$(sqlite3 "$db" "select count(*) || ' ' || coalesce(max(running_total),0) || ' ' || min(demo_only) || max(demo_only) from demo_timecards where run_id = $run")
        [[ $db_row == "$entries $total 11" ]] || fail "[$name] run $i: db says '$db_row', output says '$entries $total 11'"
    done
    distinct=$(tr ' ' '\n' <<<"$hours_seen" | grep . | sort -u | wc -l)
    [[ $distinct -ge 8 ]] || fail "[$name] only $distinct distinct hour values in $runs runs; is it random?"

    # 4. Forced dice: a fake mktemp hands out chosen names, so the tables are exercised on purpose.
    #    Each scenario is a list of hours; the expected rows are computed here with plain bash arithmetic.
    #    Names: the last character picks the group (hours 10+group); Y/Z re-rolls on the character before.
    name_for() {  # hours [mode]: mode "y" = last char Y (re-roll), "yy" = both Y and Z (double re-roll)
        local h=$1 mode=${2:-}
        case $mode in
            y) printf 'xxxx%sY' "${dice_char[h-10]}" ;;
            yy) printf 'xxxxYZ' ;;
            *) printf 'xxxxx%s' "${dice_char[h-10]}" ;;
        esac
    }
    forced() {  # "hours[:mode] ..."
        local names="" expect="" t=0 k=0 spec h mode
        for spec in $1; do
            h=${spec%%:*}; mode=""; [[ $spec == *:* ]] && mode=${spec#*:}
            names+="$(name_for "$h" "$mode") "
            [[ $mode == yy ]] && h=10
            t=$((t + h))
            expect+="${cats[k]}"$'\t'"$h"$'\t'"$t"$'\n'
            k=$((k + 1))
        done
        printf '%s' "$names" >"$data/names"; : >"$data/n"; echo 0 >"$data/n"
        cp "$shim/mktemp.fake" "$shim/bin/mktemp"
        got=$(REAL_MKTEMP=$real_mktemp FAKE_N=$data/n FAKE_NAMES=$(cat "$data/names") sh ./timecards.sh 2>/dev/null) || fail "[$name] forced '$1': timecards.sh exited $?"
        rm -f "$shim/bin/mktemp"
        got_rows=$(rows "$got" | cut -f1-3)
        [[ $got_rows == "${expect%$'\n'}" ]] || { echo "--- expected"; printf '%s' "$expect"; echo "--- got"; echo "$got_rows"; fail "[$name] forced '$1' differs"; }
        [[ $(grep -c '^# committed' <<<"$got") -eq 1 ]] || fail "[$name] forced '$1': no footer"
    }
    scenarios_note=" + 7 forced-dice scenarios"
    if [[ $name == busybox ]]; then
        scenarios_note=""
        echo "note [$name]: forced-dice scenarios skipped (busybox runs mktemp in-process, so a PATH shim cannot stand in for it)"
    else
        forced "10 10 10 10 10"          # exactly 40 continues; the fifth card is Meetings again
        forced "19 19 19"                # 19, 38, 57: tens digits 1, 3, 5
        forced "11 12 13 14"             # 11 23 36 50
        forced "15 16 17"                # 15 31 48
        forced "18 19 10"                # 18 37 47
        forced "11:y 10:yy 19:y 10"      # re-rolls: last character Y, then both; lands on 40, so one more card
        forced "10 10 10 10 11"          # 40 then 51

    fi

    # 5. The demo_only CHECK constraint is real: a non-demo row must be refused.
    if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values(1,'x',10,10,0)" 2>/dev/null; then
        fail "[$name] db accepted a non-demo row"
    fi
    echo "ok [$name]: $runs random runs${scenarios_note:-} ($path)"
done
echo "OK: one find, four primaries, four programs; ${#impls[@]} implementation(s): $(printf '%s ' "${impls[@]%%=*}")"
