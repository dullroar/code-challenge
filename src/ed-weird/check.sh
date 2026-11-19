#!/usr/bin/env bash
# Checks the rules of the challenge for the ed entry: ed owns the whole computation, the launcher owns none of it,
# and changing the ed program changes the program's behavior in the way the README says. Uses throwaway dirs.
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
export TMPDIR=$work XDG_DATA_HOME=$work/xdg; mkdir -p "$XDG_DATA_HOME"
fail() { echo "FAIL: $*"; exit 1; }
ed --version 2>&1 | head -1 | grep -q 'GNU ed' || fail "this entry needs GNU ed; found: $(ed --version 2>&1 | head -1)"
command -v sqlite3 >/dev/null || fail "sqlite3 is needed"
rows() { grep -E $'^(Meetings|Coding|Debugging|Learning)\t' <<<"$1" || true; }

# ---- 1. The constraint is real: the launcher only seeds, loads and shows; ed does the rest.
code=$(grep -Ev '^\s*(#|$)' timecards.sh)
if grep -Eq '\$\(\(|\bawk\b|\bexpr\b|(^|[|;&(] *)(bc|dc)( |$)|\bperl\b|\bpython|\bsed\b|\bwhile\b|\bfor\b|\buntil\b' <<<"$code"; then fail "timecards.sh does arithmetic, text processing or looping"; fi
[[ $(grep -c '^ed ' timecards.sh) -eq 1 ]] || fail "timecards.sh must start ed exactly once"
prog=$(grep -Ev '^#' timecards.ed)
# no shell escape, no file command, no editing of other files: ed only transforms its own buffer
if grep -nE '^[^/]*!|^(g|v)/.*/!|(^|[0-9,.$]+)[rwWeEf] ' <<<"$prog" | grep -Ev '\[\|!\]|Dead 0!|\\1!|^[0-9]+:s/' ; then fail "timecards.ed uses a shell escape or a file command"; fi
[[ $(grep -c '^g/\^\[A-Za-z\]\* \[0-9\]\[0-9\] x\*\$/' timecards.ed) -eq 1 ]] || fail "expected exactly one iterating global command (the run)"
echo "ok: timecards.sh has no arithmetic, no awk/sed, no loop; ed runs once; timecards.ed has no shell escape and no file command; one global command is the run"

# ---- helpers
sim() {  # "d d d d d" limit -> rows an independent simulation says must be printed
    awk -v limit="${2:-40}" -v digits="$1" 'BEGIN { split("Meetings Coding Debugging Learning Meetings", cat, " "); n = split(digits, d, " ")
        for (i = 1; i <= n; i++) { h = 10 + d[i]; t += h; printf "%s\t%d\t%d\n", cat[i], h, t; if (t > limit) break } }'
}
run() { DICE="$1" ED_DB=$work/run.db ED_PROGRAM=${2:-$here/timecards.ed} sh ./timecards.sh 2>"$work/err"; }
validate() {
    local label=$1 out=$2 r total entries
    r=$(rows "$out"); total=$(sed -nE 's/.*total=([0-9]+).*/\1/p' <<<"$out"); entries=$(sed -nE 's/.*entries=([0-9]+).*/\1/p' <<<"$out")
    awk -F'\t' -v total="$total" -v entries="$entries" '
        BEGIN { split("Meetings Coding Debugging Learning Meetings", want, " ") }
        { n++; if ($1 != want[n]) { print "category " $1 " at row " n; exit 1 }
          if ($2 < 10 || $2 > 19) { print "hours out of range: " $0; exit 1 }
          if ($3 != prev + $2) { print "bad running total: " $0; exit 1 }
          if (prev > 40) { print "kept going after 40: " $0; exit 1 }
          if ($5 != "DEMO ONLY") { print "missing DEMO ONLY: " $0; exit 1 }
          prev = $3 }
        END { if (n != entries || prev != total) { print "summary disagrees with rows"; exit 1 }
              if (prev <= 40) { print "stopped early at " prev; exit 1 } }' <<<"$r" || fail "$label (see above)"
}

# ---- 2. Random runs through the launcher.
for i in $(seq 1 25); do
    rm -f "$work/run.db"
    out=$(ED_DB=$work/run.db sh ./timecards.sh 2>"$work/err") || { cat "$work/err"; fail "run $i exited $?"; }
    validate "run $i" "$out"
    [[ -s $work/err ]] && { cat "$work/err"; fail "run $i: ed printed something on stderr"; }
    seen+=$(rows "$out" | cut -f2 | tr '\n' ' ')
done
[[ $(tr ' ' '\n' <<<"$seen" | grep . | sort -u | wc -l) -ge 8 ]] || fail "fewer than 8 distinct hour values in 25 runs"
[[ -z $(ls -A "$work" | grep -v -e '^xdg$' -e '^run.db$' -e '^err$') ]] || fail "scratch left behind"
echo "ok: 25 random runs: categories in order, hours 10-19, totals right, stop right after the first total over 40, DEMO ONLY, a quiet ed"

# ---- 3. Every dice sequence over {0,4,5,9} (1024 of them) and 400 random ones, against the independent simulation.
n=0
mapfile -t seqs < <( { for a in 0 4 5 9; do for b in 0 4 5 9; do for c in 0 4 5 9; do for d in 0 4 5 9; do for e in 0 4 5 9; do echo "$a $b $c $d $e"; done; done; done; done; done
                      for i in $(seq 1 400); do { tr -dc 0-9 < /dev/urandom | head -c 5 | fold -w1 | tr '\n' ' '; } || true; echo; done; } )
for s in "${seqs[@]}"; do
    s=${s% }; rm -f "$work/run.db"
    got=$(rows "$(run "$s")" | cut -f1-3); want=$(sim "$s")
    [[ $got == "$want" ]] || { echo "--- dice $s: want"; echo "$want"; echo "--- got"; echo "$got"; fail "ed disagrees with the simulation"; }
    n=$((n + 1))
done
echo "ok: $n dice sequences, including totals of exactly 40 and 41 and all-10s and all-19s, agree with the simulation"

# ---- 4. Perturbations: change the ed program, and the behavior changes as predicted. The logic is in the ed program.
perturb() {   # label, sed expression, dice, limit
    sed "$2" timecards.ed > "$work/p.ed"; cmp -s timecards.ed "$work/p.ed" && fail "$1: the mutation changed nothing"
    rm -f "$work/run.db"; out=$(run "$3" "$work/p.ed") || fail "$1: the mutated program failed"
}
perturb "stop at 30" 's/x\\{41,\\}/x\\{31,\\}/' "3 3 3 3 3"
[[ $(rows "$out" | cut -f1-3) == "$(sim "3 3 3 3 3" 30)" ]] || fail "changing x{41,} to x{31,} should move the stop rule to 'over 30'"
perturb "stop at 50" 's/x\\{41,\\}/x\\{51,\\}/' "0 0 0 0 0 "
[[ $(rows "$out" | cut -f1-3) == "$(sim "0 0 0 0 0" 50 | head -5)" ]] || fail "changing x{41,} to x{51,} should move the stop rule to 'over 50'"
perturb "swap two categories" 's/^1s\/\^\/Meetings \//1s\/^\/Coding \//; s/^2s\/\^\/Coding \//2s\/^\/Meetings \//' "5 5 5 5 5"
[[ $(rows "$out" | cut -f1 | tr '\n' ' ') == "Coding Meetings Debugging " ]] || fail "swapping lines 1 and 2 should swap their categories (got: $(rows "$out" | cut -f1 | tr '\n' ' '))"
perturb "no dead rule" '/^s\/\^\.\*\[A-Za-z\]/d' "5 5 5 5 5"
[[ $(rows "$out" | wc -l) -gt 3 ]] || fail "without the Dead rule, cards after the crossing one should survive"
sed '/^g\/\^Dead \/d$/d' timecards.ed > "$work/p.ed"; cmp -s timecards.ed "$work/p.ed" && fail "no cleanup: the mutation changed nothing"
printf '5\n5\n5\n5\n5\n' > "$work/d.txt"
ed -s "$work/d.txt" < "$work/p.ed" | grep -q '^Dead' || fail "without the cleanup, Dead cards should appear in ed's output"
echo "ok: perturbations: x{41,} to x{31,} moves the stop rule, x{51,} moves it the other way, swapping two address lines swaps their categories, deleting the Dead rule or its cleanup changes the output"

# ---- 5. Walls: what POSIX forbids stays forbidden. (A negative test is kept for each.)
ed_err() { printf 'H\n%s\nQ\n' "$1" | ed -s "$work/wall.txt" 2>&1 | head -2 | tr "\n" " "; }
printf 'a\nb\n' > "$work/wall.txt"
[[ -n $(ed_err 'g/a/g/b/s/b/c/') ]] || fail "a global command inside a global command should be an error"
echo "ok: wall: g inside g is refused by ed ($(ed_err 'g/a/g/b/s/b/c/'))"
[[ $(ed_err '
1s/a/b/') == *"Invalid address"* ]] || fail "a blank line is the command 'print next line' and so errors at the end of a buffer"
echo "ok: wall: a blank line in an ed script is a command, not a separator (so the script uses # comments)"
printf 'a\nb\n' > "$work/wall.txt"
[[ $(printf 'g/a/s/x/y/\n,p\nQ\n' | ed -s "$work/wall.txt" 2>&1; echo rc=$?) == $'a\nb\nrc=0' ]] || fail "a failed s inside g must be silent"
echo "ok: a failed s inside a global command is not an error (the guard the program is built on)"
printf 'a\nb\n' > "$work/wall.txt"
[[ $(printf '/nomatch/\nQ\n' | ed -s "$work/wall.txt" 2>&1; echo rc=$?) == *"rc=1" ]] || fail "a failed address should make ed exit 1"
echo "ok: a failed address is an error, unlike a failed s: exit status 1"

# ---- 6. Another ed: busybox ed cannot run the program. Measured, and asserted when busybox is there.
if command -v busybox >/dev/null && busybox --list | grep -qx ed; then
    printf '7\n3\n9\n0\n5\n' > "$work/bb.txt"
    # Capture the finite diagnostic before shortening it so head cannot give ed SIGPIPE.
    bbout=$(busybox ed "$work/bb.txt" < timecards.ed 2>&1 || true)
    if grep -qx 'Meetings 17 17' <<<"$bbout"; then fail "busybox ed ran the program; update the README"; fi
    bbout=$(head -3 <<<"$bbout" | tr '\n' '|')
    echo "ok: busybox ed cannot run it (no # comments, t, j, g, Q; no empty match in s). First lines: $bbout"
else
    echo "note: busybox ed not installed; skipped the dialect check"
fi

# ---- 7. The schema.
rm -f "$work/run.db"; run "1 2 3 4 5" >/dev/null
sqlite3 "$work/run.db" "insert into demo_timecards values(1,'Coding',12,12,'w',0)" 2>/dev/null && fail "db accepted a non-demo row"
sqlite3 "$work/run.db" "insert into demo_timecards values(1,'Coding',9,9,'w',1)" 2>/dev/null && fail "db accepted 9 hours"
sqlite3 "$work/run.db" "insert into demo_timecards values(1,'Banking',12,12,'w',1)" 2>/dev/null && fail "db accepted a fifth category"
DICE="1 2 3 4" sh ./timecards.sh >/dev/null 2>&1 && fail "four dice must be refused"
DICE="1 2 x 4 5" sh ./timecards.sh >/dev/null 2>&1 && fail "a non-digit die must be refused"
echo "ok: SQLite refuses a non-demo row, 9 hours and a fifth category; the launcher refuses four dice and a non-digit"
echo "OK: ed-weird ($(ed --version | head -1))"
