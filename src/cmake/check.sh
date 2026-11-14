#!/usr/bin/env bash
# Checks the rules of the challenge for the CMake track. Uses a throwaway data dir and a throwaway working dir.
# Needs cmake (3.19+) on PATH, e.g. `uv tool install cmake`.
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
command -v cmake >/dev/null || { echo "FAIL: cmake not found (try: uv tool install cmake)"; exit 2; }
data=$(mktemp -d); work=$(mktemp -d); trap 'rm -rf "$data" "$work"' EXIT
export XDG_DATA_HOME=$data
db=$data/CmakeChallenge/demo-timecards.db
cd "$work"
run() { cmake -P "$here/timecards.cmake"; }

# 1. The stunt is real. The whole program is ONE bodiless while(): its condition is the machine. No functions,
#    macros, includes or cmake_language() to hide a RunEverything() in; nothing between while() and endwhile();
#    and nothing before the loop computes (no math, no list/string surgery besides drawing the seed tape).
script=$here/timecards.cmake
code=$(grep -Ev '^\s*#' "$script")
[[ $(grep -c '^while(' <<<"$code") -eq 1 && $(grep -c '^endwhile()' <<<"$code") -eq 1 ]] || { echo "FAIL: expected exactly one while()"; exit 1; }
[[ $(grep -B1 '^endwhile()' <<<"$code" | head -1) == *'(x*)\\|")' ]] || { echo "FAIL: something is between the while() condition and endwhile()"; exit 1; }
if grep -Eqi '^\s*(function|macro|include|cmake_language|add_custom|variable_watch)\(' <<<"$code"; then echo "FAIL: function/macro/include/cmake_language found"; exit 1; fi
pre=$(awk '/^while\(/ { exit } { print }' <<<"$code")
if grep -Eq '^\s*(math|list|foreach|string\((REPLACE|REGEX|APPEND|LENGTH|SUBSTRING))\(' <<<"$pre"; then echo "FAIL: computation before the loop"; exit 1; fi
# Only sqlite3 (and wt.exe for POP, and cmake itself for its own sleep) may be started; no shell, no coreutils.
progs=$(grep -oP 'COMMAND\s+\K\S+' <<<"$code" | sort -u | paste -sd' ')
[[ $progs == '${CMAKE_COMMAND} sqlite3 wt.exe' ]] || { echo "FAIL: unexpected programs started: $progs"; exit 1; }

# 2. Run it a bunch of times; every run must print a sane record set, and the SQLite rows must agree with it.
for i in $(seq 1 25); do
    out=$(run 2>"$data/err")
    [[ -z $(ls -A) ]] || { echo "FAIL run $i: wrote into the working dir"; exit 1; }
    run_id=$(sed -nE 's/^# DEMO ONLY run ([0-9]+)$/\1/p' <<<"$out")
    [[ -n $run_id ]] || { echo "FAIL run $i: no run id"; echo "$out"; exit 1; }
    commit=$(grep '^# committed' <<<"$out")
    total=$(sed -E 's/.*total=([0-9]+).*/\1/' <<<"$commit")
    entries=$(sed -E 's/.*entries=([0-9]+).*/\1/' <<<"$commit")
    rows=$(grep -cE '^(Meetings|Coding|Debugging|Learning)	' <<<"$out" || true)
    [[ $rows -eq $entries ]] || { echo "FAIL run $i: $rows rows but entries=$entries"; exit 1; }
    grep -q "^# an empty while() went round $entries times" <<<"$out" || { echo "FAIL run $i: loop count != entries ($entries)"; echo "$out"; exit 1; }
    awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ && ($2 < 10 || $2 > 19) { bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: hours out of 10-19"; exit 1; }
    cats=$(awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ { printf "%s ", $1 }' <<<"$out")
    [[ "Meetings Coding Debugging Learning " == "$cats"* ]] || { echo "FAIL run $i: categories out of order: $cats"; exit 1; }
    awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ { s += $2; if ($3 != s || $5 != "DEMO ONLY") bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: running total or DEMO ONLY column wrong"; exit 1; }
    awk -F'\t' -v n="$rows" '/^(Meetings|Coding|Debugging|Learning)\t/ { k++; if (k < n && $3 > 40) bad = 1; if (k == n && $3 <= 40) bad = 1 } END { exit bad }' <<<"$out" \
        || { echo "FAIL run $i: stop rule wrong"; echo "$out"; exit 1; }
    stops=$(grep -c 'CHECK constraint failed: stop rule fired: total exceeds 40' "$data/err" || true)
    others=$(grep -vc 'CHECK constraint failed: stop rule fired: total exceeds 40' "$data/err" || true)
    [[ $stops -eq 1 && $others -eq 0 ]] || { echo "FAIL run $i: unexpected stderr:"; cat "$data/err"; exit 1; }
    # ISO week matches SQLite's date arithmetic, in local time like the other entries.
    want=$(sqlite3 :memory: "select printf('%s-W%02d',strftime('%Y',date('now','localtime','-3 days','weekday 4')),(strftime('%j',date('now','localtime','-3 days','weekday 4'))-1)/7+1)")
    awk -F'\t' -v want="$want" '/^(Meetings|Coding|Debugging|Learning)\t/ && $4 != want { bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: ISO week differs from SQLite's $want"; exit 1; }
    db_row=$(sqlite3 "$db" "select count(*) || ' ' || coalesce(sum(hours),0) || ' ' || coalesce(max(running_total),0) || ' ' || coalesce(min(demo_only),0) || coalesce(max(demo_only),0) from demo_timecards where run_id = $run_id")
    [[ $db_row == "$entries $total $total 11" ]] || { echo "FAIL run $i: db says '$db_row', output says '$entries $total $total 11'"; exit 1; }
done
[[ $(sqlite3 "$db" 'select count(*) from runs') -eq 25 ]] || { echo "FAIL: expected 25 runs in the db"; exit 1; }
[[ $(sqlite3 "$db" 'select count(*) from stop_rule') -eq 0 ]] || { echo "FAIL: stop_rule probe rows were left behind"; exit 1; }
[[ -z $(ls -A "$data/CmakeChallenge" | grep -v '^demo-timecards.db$') ]] || { echo "FAIL: scratch .sql files left behind"; exit 1; }

# 3. CMake's strftime has %V but no %G: the ISO year is patched by hand. Sweep the year boundaries against date(1).
for t in 0 951782400 1078012800 1230768000 1609459199 1609459200 1704067199 1704067200 1735603199 1735689599 1735689600 \
         1767225599 1767225600 1798675199 1798675200 1798761600 1893455999 1893456000 2000000000 4000000000; do
    want="$(date -u -d "@$t" +%G-W%V)"
    got=$(SOURCE_DATE_EPOCH=$t TZ=UTC run 2>/dev/null | awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ { print $4; exit }' || true)
    [[ $got == "$want" ]] || { echo "FAIL: SOURCE_DATE_EPOCH=$t: cmake says '$got', date says '$want'"; exit 1; }
done

# 4. The glow: silent on a pipe, 24 frames in 1-3 s on a pty, and the banner is erased.
if run 2>/dev/null | LC_ALL=C grep -q $'\033'; then echo "FAIL: escape codes leaked into piped output"; exit 1; fi
if command -v script >/dev/null; then
    start=$(date +%s.%N)
    tty_out=$(script -qec "cmake -P $here/timecards.cmake" /dev/null 2>/dev/null)
    secs=$(awk -v a="$start" -v b="$(date +%s.%N)" 'BEGIN { printf "%.1f", b - a }')
    frames=$(grep -c $'\033\\[48;5;' <<<"$tty_out" || true)
    [[ $frames -eq 24 ]] || { echo "FAIL: expected 24 glow frames on a tty, saw $frames"; exit 1; }
    awk -v s="$secs" 'BEGIN { exit !(s >= 1 && s <= 3) }' || { echo "FAIL: glow took ${secs}s, expected 1-3s"; exit 1; }
fi

# 4b. Mutation: the stop rule really is the 41-character literal in the condition. Make it 51 and runs stop later,
#     so some total must exceed the legal maximum of 59.
sed 's/"^xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"/"^xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"/' "$script" > "$work/mutant.cmake"
over=0
for i in $(seq 1 30); do
    t=$(cmake -P "$work/mutant.cmake" 2>/dev/null | sed -nE 's/^# committed total=([0-9]+).*/\1/p')
    (( t > 59 )) && over=1
done
[[ $over -eq 1 ]] || { echo "FAIL: mutating the stop literal did not change behaviour"; exit 1; }

# 5. The demo_only CHECK constraint is real.
if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values(1,'x',10,10,0)" 2>/dev/null; then
    echo "FAIL: db accepted a non-demo row"; exit 1
fi
echo "OK: one bodiless while(); 25 runs stopped when they should and matched SQLite; mutating the stop literal changes behaviour; ISO year patched correctly; glow only on a tty"
