#!/usr/bin/env bash
# Checks the rules of the challenge for the GNU Make track. Uses a throwaway data dir and a throwaway
# working dir that holds nothing but the Makefile, the way a real run starts.
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
data=$(mktemp -d); work=$(mktemp -d); trap 'rm -rf "$data" "$work"' EXIT
export XDG_DATA_HOME=$data
db=$data/MakeChallenge/demo-timecards.db
cp "$here/Makefile" "$work/"
cd "$work"

# 1. The ridiculous constraint is real: no $(shell), no != assignment, no .ONESHELL, no load. Recipes may only
#    run mkdir, sqlite3, rm, sleep (between glow frames), wt.exe (`make pop`), and the no-op ':' that makes Make notice a file appeared (or ./check.sh for `make check`).
code=$(grep -Ev '^\s*(#|$)' Makefile)
if grep -Eq '\$\((shell|guile)|!=|^\.ONESHELL|^(-?)load |\$\(call (shell|guile)' <<<"$code"; then
    echo "FAIL: a shell/guile/load escape hatch is in the Makefile"; exit 1
fi
progs=$(grep -P '^\t' Makefile | grep -Ev '^\t(rm -f|\./check\.sh|wt\.exe )' | grep -oP '@(mkdir|sqlite3|rm|sleep)\b|@:' | sed 's/^-//' | sort -u | paste -sd' ')
[[ $progs == "@: @mkdir @rm @sleep @sqlite3" ]] || { echo "FAIL: recipes run unexpected programs: $progs"; exit 1; }

# 2. Run it a bunch of times; every run must print a sane record set, and the SQLite rows must agree with it.
for i in $(seq 1 25); do
    out=$(make 2>"$data/err")
    [[ $(ls -A) == Makefile ]] || { echo "FAIL run $i: left files behind: $(ls -A | paste -sd' ')"; exit 1; }
    run=$(sed -nE 's/^# DEMO ONLY run ([0-9]+)$/\1/p' <<<"$out")
    [[ -n $run ]] || { echo "FAIL run $i: no run id"; echo "$out"; exit 1; }
    commit=$(grep '^# committed' <<<"$out")
    total=$(sed -E 's/.*total=([0-9]+).*/\1/' <<<"$commit")
    entries=$(sed -E 's/.*entries=([0-9]+).*/\1/' <<<"$commit")
    rows=$(grep -cE '^(Meetings|Coding|Debugging|Learning)	' <<<"$out" || true)
    [[ $rows -eq $entries ]] || { echo "FAIL run $i: $rows rows but entries=$entries"; exit 1; }
    # Make re-executed itself once per card: the loop counter is the card count.
    grep -q "^# make re-executed itself $entries times" <<<"$out" || { echo "FAIL run $i: restarts != entries ($entries)"; echo "$out"; exit 1; }
    awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ && ($2 < 10 || $2 > 19) { bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: hours out of 10-19"; exit 1; }
    # Categories in order, running totals really running, every row ends in DEMO ONLY.
    cats=$(awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ { printf "%s ", $1 }' <<<"$out")
    [[ "Meetings Coding Debugging Learning " == "$cats"* ]] || { echo "FAIL run $i: categories out of order: $cats"; exit 1; }
    awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ { s += $2; if ($3 != s || $5 != "DEMO ONLY") bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: running total or DEMO ONLY column wrong"; exit 1; }
    # Stop rule: keep adding while the total is <= 40 (exactly 40 continues); stop once it exceeds 40.
    awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ { n++; if (n < NR_ROWS && $3 > 40) bad = 1; if (n == NR_ROWS && $3 <= 40) bad = 1 } END { exit bad }' NR_ROWS="$rows" <<<"$out" \
        || { echo "FAIL run $i: stop rule wrong"; echo "$out"; exit 1; }
    # The stop rule also announces itself on stderr (a named CHECK constraint), exactly once, and nothing else does.
    stops=$(grep -c 'CHECK constraint failed: stop rule fired: total exceeds 40' "$data/err" || true)
    others=$(grep -vc 'CHECK constraint failed: stop rule fired: total exceeds 40' "$data/err" || true)
    [[ $stops -eq 1 && $others -eq 0 ]] || { echo "FAIL run $i: unexpected stderr:"; cat "$data/err"; exit 1; }
    # ISO week matches SQLite's date arithmetic (Make computes it from /proc in UTC; SQLite is asked in UTC).
    want=$(sqlite3 :memory: "select printf('%s-W%02d',strftime('%Y',date('now','-3 days','weekday 4')),(strftime('%j',date('now','-3 days','weekday 4'))-1)/7+1)")
    awk -F'\t' -v want="$want" '/^(Meetings|Coding|Debugging|Learning)\t/ && $4 != want { bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: ISO week differs from SQLite's $want"; echo "$out"; exit 1; }
    # The rows are really in SQLite and agree with what was printed.
    db_row=$(sqlite3 "$db" "select count(*) || ' ' || coalesce(sum(hours),0) || ' ' || coalesce(max(running_total),0) || ' ' || coalesce(min(demo_only),0) || coalesce(max(demo_only),0) from demo_timecards where run_id = $run")
    [[ $db_row == "$entries $total $total 11" ]] || { echo "FAIL run $i: db says '$db_row', output says '$entries $total $total 11'"; exit 1; }
done
[[ $(sqlite3 "$db" 'select count(*) from runs') -eq 25 ]] || { echo "FAIL: expected 25 runs in the db"; exit 1; }
[[ $(sqlite3 "$db" 'select count(*) from stop_rule') -eq 0 ]] || { echo "FAIL: stop_rule probe rows were left behind"; exit 1; }

# 3. Pure-Make calendar vs the real thing: boundary instants, NOW overrides the /proc clock.
for t in 0 951782400 1078012800 1230768000 1609459199 1609459200 1704067199 1704067200 1735603199 1735689599 1735689600 \
         1767225599 1767225600 1798675199 1798675200 1798761600 1893455999 1893456000 2000000000 4000000000; do
    want="$(date -u -d "@$t" +%G-W%V)"
    out=$(make NOW=$t 2>/dev/null)
    got=$(awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ { print $4; exit }' <<<"$out")
    [[ $got == "$want" ]] || { echo "FAIL: NOW=$t: make says '$got', date says '$want'"; exit 1; }
done

# 4a. The glow: silent on a pipe (every run above was piped), and on a real terminal (a pty from script(1)) a ramp of
#     256-colour banner frames, then the banner is erased, all in 1-3 seconds.
if ! printf '%s' "$out" | LC_ALL=C grep -q $'\033'; then :; else echo "FAIL: escape codes leaked into piped output"; exit 1; fi
if command -v script >/dev/null; then
    start=$(date +%s.%N)
    tty_out=$(script -qec make /dev/null)
    secs=$(awk -v a="$start" -v b="$(date +%s.%N)" 'BEGIN { printf "%.1f", b - a }')
    frames=$(grep -c $'\033\\[48;5;' <<<"$tty_out" || true)
    [[ $frames -eq 24 ]] || { echo "FAIL: expected 24 glow frames on a tty, saw $frames"; exit 1; }
    awk -v s="$secs" 'BEGIN { exit !(s >= 1 && s <= 3) }' || { echo "FAIL: glow took ${secs}s, expected 1-3s"; exit 1; }
    [[ $(ls -A) == Makefile ]] || { echo "FAIL: tty run left files behind"; exit 1; }
fi
# `make pop` only prints its wt.exe command under -n, and (like clean and check) never writes a card.
make -n pop | grep -q '^wt.exe -w new new-tab' || { echo "FAIL: make pop has no wt.exe command"; exit 1; }
[[ $(ls -A) == Makefile ]] || { echo "FAIL: make -n pop left files behind"; exit 1; }

# 4. A leftover state file from an interrupted run is refused, not silently reused.
: > .tc-0.mk
if make >/dev/null 2>&1; then echo "FAIL: stale .tc-0.mk was accepted"; exit 1; fi
make clean >/dev/null; [[ $(ls -A) == Makefile ]] || { echo "FAIL: make clean left files"; exit 1; }

# 5. The demo_only CHECK constraint is real: a non-demo row must be refused.
if sqlite3 "$db" "insert into demo_timecards(run_id,category,hours,running_total,demo_only) values(1,'x',10,10,0)" 2>/dev/null; then
    echo "FAIL: db accepted a non-demo row"; exit 1
fi
echo "OK: no \$(shell); 25 runs, each looped by Make re-executing itself, stopped when it should, matched SQLite; calendar matches date(1); glow only on a tty"
