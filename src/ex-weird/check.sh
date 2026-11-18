#!/usr/bin/env bash
# Checks the rules of the challenge for the Ex entry. Ex owns the whole computation, the launcher owns none of it,
# and the program has no global command, no regular-expression test and no error exit: the loop is a register that
# runs itself, and the stop rule is a line of data on a tape. Runs against whichever `ex` is installed:
# nvi (the sandbox) or Vim in Ex mode, and says which.
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
export TMPDIR=$work XDG_DATA_HOME=$work/xdg; mkdir -p "$XDG_DATA_HOME"
fail() { echo "FAIL: $*"; exit 1; }
command -v sqlite3 >/dev/null || fail "sqlite3 is needed"
ex=${EX:-ex}; command -v "$ex" >/dev/null || fail "no $ex found"
case $("$ex" --version < /dev/null 2>&1 | head -n 1) in
    *VIM*) impl=vim; flags="-s -u NONE -N"; export_term= ;;
    *) impl=nvi; flags="-s"; export TERM=dumb ;;
esac
echo "ex implementation: $impl ($(if [[ $impl == vim ]]; then "$ex" --version < /dev/null 2>&1 | head -n 1 | cut -c1-40; else echo "$(basename "$(readlink -f "$(command -v "$ex")")"), $(dpkg-query -W -f='nvi ${Version}' nvi 2>/dev/null || echo version unknown)"; fi))"
rows() { grep -E $'^(Meetings|Coding|Debugging|Learning)\t' <<<"$1" || true; }
pick() { if [[ $impl == nvi ]]; then echo "$1"; else echo "$2"; fi; }   # a message for nvi, a message for Vim
# run a small Ex script against a buffer; prints ex's output without nvi's one known terminal note; exit status in $xrc
exrun() { local text=$1 script=$2; printf '%b' "$text" > "$work/b.txt"
          set +e; out=$(printf '%b' "$script" | "$ex" $flags "$work/b.txt" 2>&1); xrc=$?; set -e
          out=$(grep -vx 'Error: stderr: Inappropriate ioctl for device' <<<"$out" || true); }

# ---- 1. The constraint is real: the launcher only seeds, loads and shows; Ex does the rest.
code=$(grep -Ev '^\s*(#|$)' timecards.sh)
if grep -Eq '\$\(\(|\bawk\b|\bexpr\b|(^|[|;&(] *)(bc|dc)( |$)|\bperl\b|\bpython|\bsed\b|(^|[;&|{(] *)(while|for|until) ' <<<"$code"; then fail "timecards.sh does arithmetic, text processing or looping"; fi
[[ $(grep -c '^"\$ex" ' timecards.sh) -eq 1 ]] || fail "timecards.sh must start the editor exactly once"
prog=$(grep -Ev '^"|^q!$' timecards.ex)   # q! (quit without writing) is the only ! allowed
if grep -nE '(^|[|])[^|]*[gGvV]/|[gv]!|!' <<<"$prog" | grep -v '^[0-9]*:[0-9]* @a$'; then fail "timecards.ex has a global command or a shell escape"; fi
if grep -nE '(^|[|])[0-9$.,'"'"'a-z+-]*(w|W|r|e|E|f|so|source|vi|visual|x|wq|!) *(\||$)' <<<"$prog" | grep -Ev '^[0-9]+:[0-9]+ ' | grep .; then fail "timecards.ex uses a file or shell command"; fi
[[ $(grep -c '^[0-9]* @a$' timecards.ex) -eq 41 && $(grep -c '^[0-9]* "$' timecards.ex) -eq 19 ]] || fail "the tape must have 41 go rows (0-40) and 19 stop rows (41-59)"
[[ $(grep -c '|@n$' timecards.ex) -eq 1 ]] || fail "the one-line program must end by running register n"
[[ $(grep -c '^@a$' timecards.ex) -eq 1 ]] || fail "@a must be started exactly once at the top level"
echo "ok: timecards.sh has no arithmetic, no awk/sed, no loop; the editor starts once; timecards.ex has no g or v command, no shell escape, no file command; the tape is 41 go rows and 19 stop rows"

# ---- helpers
sim() {  # "d d d d d" limit -> the rows an independent simulation says must be printed
    awk -v limit="${2:-40}" -v digits="$1" 'BEGIN { split("Meetings Coding Debugging Learning Meetings", cat, " "); n = split(digits, d, " ")
        for (i = 1; i <= n; i++) { h = 10 + d[i]; t += h; printf "%s\t%d\t%d\n", cat[i], h, t; if (t > limit) break } }'
}
run() { DICE="$1" EX_DB=$work/run.db EX_PROGRAM=${2:-$here/timecards.ex} sh ./timecards.sh 2>"$work/err"; }
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
    out=$(EX_DB=$work/run.db sh ./timecards.sh 2>"$work/err") || { cat "$work/err"; fail "run $i exited $?"; }
    validate "run $i" "$out"
    [[ -s $work/err ]] && { cat "$work/err"; fail "run $i: unexpected stderr"; }
    seen+=$(rows "$out" | cut -f2 | tr '\n' ' ')
done
[[ $(tr ' ' '\n' <<<"$seen" | grep . | sort -u | wc -l) -ge 8 ]] || fail "fewer than 8 distinct hour values in 25 runs"
[[ -z $(ls -A "$work" | grep -v -e '^xdg$' -e '^run.db$' -e '^err$' -e '^b.txt$') ]] || fail "scratch left behind: $(ls -A "$work")"
echo "ok: 25 random runs: categories in order, hours 10-19, totals right, stop right after the first total over 40, DEMO ONLY, exit status 0, nothing on stderr"

# ---- 3. Every dice sequence over {0,4,5,9} and 400 random ones, against the independent simulation.
n=0
mapfile -t seqs < <( { for a in 0 4 5 9; do for b in 0 4 5 9; do for c in 0 4 5 9; do for d in 0 4 5 9; do for e in 0 4 5 9; do echo "$a $b $c $d $e"; done; done; done; done; done
                      for i in $(seq 1 400); do { tr -dc 0-9 < /dev/urandom | head -c 5 | fold -w1 | tr '\n' ' '; } || true; echo; done; } )
for s in "${seqs[@]}"; do
    s=${s% }; rm -f "$work/run.db"
    got=$(rows "$(run "$s")" | cut -f1-3); want=$(sim "$s")
    [[ $got == "$want" ]] || { echo "--- dice $s: want"; echo "$want"; echo "--- got"; echo "$got"; fail "ex disagrees with the simulation"; }
    n=$((n + 1))
done
echo "ok: $n dice sequences, including totals of exactly 40 and 41 and all-10s and all-19s, agree with the simulation"

# ---- 4. Perturbations: change the program and the behavior changes as predicted. The logic is in the Ex program.
perturb() {   # label, sed expression, dice
    sed "$2" timecards.ex > "$work/p.ex"; cmp -s timecards.ex "$work/p.ex" && fail "$1: the mutation changed nothing"
    rm -f "$work/run.db"; out=$(run "$3" "$work/p.ex") || fail "$1: the mutated program failed: $(cat "$work/err")"
}
perturb "stop at 30" 's/^\(3[1-9]\|40\) @a$/\1 "/' "3 3 3 3 3"
[[ $(rows "$out" | cut -f1-3) == "$(sim "3 3 3 3 3" 30)" ]] || fail "moving the @a/comment boundary on the tape to 30 should move the stop rule to 'over 30'"
perturb "stop at 45" 's/^\(4[1-5]\) "$/\1 @a/' "1 1 1 1 1"
[[ $(rows "$out" | cut -f1-3) == "$(sim "1 1 1 1 1" 45)" ]] || fail "moving the boundary to 45 should give five cards for eleven-hour dice (got: $(rows "$out" | cut -f3 | tr '\n' ' '))"
perturb "swap two categories" 's/^1s\/\^\/Meetings \/|2s\/\^\/Coding \//1s\/^\/Coding \/|2s\/^\/Meetings \//' "5 5 5 5 5"
[[ $(rows "$out" | cut -f1 | tr '\n' ' ') == "Coding Meetings Debugging " ]] || fail "swapping lines 1 and 2 should swap their categories"
perturb "no loop" 's/|@n$//' "5 5 5 5 5"
[[ $(rows "$out" | wc -l) -eq 1 ]] || fail "without the final @n the program must run exactly one card (got $(rows "$out" | wc -l))"
perturb "stop at once" 's/^0 @a$/0 "/; s/^\([0-9]\|[1-3][0-9]\|40\) @a$/\1 "/' "5 5 5 5 5"
[[ $(rows "$out" | wc -l) -eq 1 ]] || fail "with every tape row a comment the program must stop after one card"
echo "ok: perturbations: moving the @a/comment boundary on the tape to 30 or 45 moves the stop rule; swapping two address lines swaps their categories; deleting the final @n removes the loop; all-comment tape stops after one card"

# ---- 5. Dialects. The program avoids every difference below; each is measured here, for the implementation we have.
exrun 'one\ntwo\nthree\n' '$a\n1p\n2p\n3p\n.\n4,$ya a\n4,$d\n@a\nq!\n'
if [[ $impl == nvi ]]; then [[ $(tr '\n' ' ' <<<"$out") == "three two one " ]] || fail "nvi should run a multi-line register bottom to top (got: $out)"; else [[ $(tr '\n' ' ' <<<"$out") == "one two three " ]] || fail "Vim should run a multi-line register top to bottom (got: $out)"; fi
echo "ok: dialect ($impl): a multi-line register runs $(pick 'bottom to top' 'top to bottom'); the program's register is ONE line, so order never matters"
exrun 'x\ny\nz\n' '$a\ng/^y$/p\n.\n4ya b\n4d\ng/^x$/@b\nq!\n'
if [[ $impl == nvi ]]; then [[ $out == y ]] || fail "nvi should allow a global command inside a register run from a global command (got: $out)"; else [[ -z $out ]] || fail "Vim should refuse a nested global command (got: $out)"; fi
echo "ok: dialect ($impl): a global command inside a register run by a global command is $(pick allowed refused); the program has no global command at all"
exrun 'l1\nl2\nl3\nl4\n' '2\n+1\nq!\n'
if [[ $impl == nvi ]]; then [[ $(tr '\n' ' ' <<<"$out") == "l2 l3 " ]] || fail "nvi should print the line a bare address moves to (got: $out)"; else [[ -z $out ]] || fail "Vim should not print for a bare address (got: $out)"; fi
echo "ok: dialect ($impl): a bare address $(pick 'prints the line it moves to' 'prints nothing'); the program moves its mark with the k command, which never prints"
exrun 'l1\nl2\nl3\n' '/zzz/\n1p\nq!\n'
if [[ $impl == nvi ]]; then [[ $xrc -eq 1 && $out == *"Pattern not found"* && $out != *l1* ]] || fail "nvi should stop at the first error (rc=$xrc, out: $out)"; else [[ $out == *l1* ]] || fail "Vim should go on after an error (out: $out)"; fi
echo "ok: dialect ($impl): after an error the editor $(pick "stops reading the script (exit status $xrc)" "goes on and exits with status $xrc at the end"); the program makes no error on purpose, because in nvi a failed search would end it"
exrun 'l1\nl2\nl3\nl4\n' '4\nk t\n1\n'"'"'t,2p\nq!\n'
if [[ $impl == nvi ]]; then [[ $out == *"second address is smaller"* ]] || fail "nvi should refuse a backward range (got: $out)"; fi
echo "ok: dialect ($impl): a backward range, 't,2 with the mark below line 2 reversed: $(pick 'an error, The second address is smaller than the first' "Vim prints nothing, and does not stop")"

# ---- 6. The schema.
rm -f "$work/run.db"; run "1 2 3 4 5" >/dev/null
sqlite3 "$work/run.db" "insert into demo_timecards values(1,'Coding',12,12,'w',0)" 2>/dev/null && fail "db accepted a non-demo row"
sqlite3 "$work/run.db" "insert into demo_timecards values(1,'Coding',9,9,'w',1)" 2>/dev/null && fail "db accepted 9 hours"
sqlite3 "$work/run.db" "insert into demo_timecards values(1,'Banking',12,12,'w',1)" 2>/dev/null && fail "db accepted a fifth category"
DICE="1 2 3 4" sh ./timecards.sh >/dev/null 2>&1 && fail "four dice must be refused"
DICE="1 2 x 4 5" sh ./timecards.sh >/dev/null 2>&1 && fail "a non-digit die must be refused"
echo "ok: SQLite refuses a non-demo row, 9 hours and a fifth category; the launcher refuses four dice and a non-digit"
echo "OK: ex-weird ($impl)"
