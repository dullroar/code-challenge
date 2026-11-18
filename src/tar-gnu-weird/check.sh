#!/usr/bin/env bash
# Checks the rules of the challenge for the checkpoint-clock entry, and proves that the clock is real: change the
# archive's layout or tar's checkpoint settings and an independent simulation predicts exactly what changes.
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
export TMPDIR=$work
fail() { echo "FAIL: $*"; exit 1; }
tar --version | head -1 | grep -q 'GNU tar' || fail "this entry needs GNU tar (--checkpoint-action); found: $(tar --version | head -1)"
command -v sqlite3 >/dev/null || fail "sqlite3 is needed"
newdb() { export XDG_DATA_HOME=$work/xdg.$1; rm -rf "$XDG_DATA_HOME"; mkdir -p "$XDG_DATA_HOME"; db=$XDG_DATA_HOME/TarGnuWeird/demo-timecards.db; unset TICK_DB; }
rows() { grep -E $'^(Meetings|Coding|Debugging|Learning)\t' <<<"$1" || true; }

# ---- 1. The ridiculous constraint is real: no loop calls the tick; tar's checkpoint does.
code=$(grep -Ev '^\s*(#|$)' run-clock.sh tick.sh | cut -d: -f2-)
# the only loop in the launcher is the argument parser; nothing loops around tar or the tick
loops=$(grep -Ew 'for|while|until|seq' <<<"$code" | grep -vxF 'while [ $# -gt 0 ]; do' || true)
[[ -z $loops ]] || fail "run-clock.sh or tick.sh has a loop besides the argument parser: $loops"
[[ $(grep -c 'tick.sh' run-clock.sh) -eq 1 ]] || fail "run-clock.sh must mention tick.sh exactly once (inside the tar option)"
grep -q -- '--checkpoint-action="exec=sh $here/tick.sh"' run-clock.sh || fail "the tick must be tar's checkpoint action"
[[ $(grep -c '^tar ' run-clock.sh) -eq 1 ]] || fail "run-clock.sh must start tar exactly once"
if grep -Eq -- '--to-command|-x|--extract|--verbose|--totals' <(grep -E '^tar |^    -cf' run-clock.sh); then fail "the tar line must only create"; fi
tick=$(grep -Ev '^\s*--' tick.sql)
if grep -Eqi 'recursive|random\(|\bwith\b|create trigger' <<<"$tick"; then fail "tick.sql has recursion, randomness or a trigger"; fi
echo "ok: no loop anywhere between the checkpoint and the SQL; one tar, one checkpoint action, no recursion, no triggers"

# ---- helpers: an independent simulation of the machine (Park-Miller in awk), and a validator of the rules.
sim() {  # seed ticks -> rows "Cat\thours\ttotal" for every card that closes within `ticks` hours, then "#done" or "#stalled"
    awk -v seed="$1" -v T="$2" 'BEGIN {
        split("Meetings Coding Debugging Learning Meetings", cat, " ")
        s = seed * 48271 % 2147483647; target = 10 + s % 10; worked = 0; total = 0; card = 0; done = 0
        for (t = 1; t <= T && !done; t++) {
            worked++; total++
            if (worked == target) { card++; printf "%s\t%d\t%d\n", cat[card], worked, total
                if (total > 40) done = 1
                s = s * 48271 % 2147483647; target = 10 + s % 10; worked = 0 } }
        print done ? "#done" : "#stalled" }'
}
predicted_ticks() { echo $(( ($1 + $2 - 1) / $2 / $3 )); }   # N blocks, -b B, --checkpoint=K  -> ticks
validate() {  # label output
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

# ---- 2. Random runs: the rules, and the clock invariants (a card closes at the tick equal to its running total).
for i in $(seq 1 20); do
    newdb r$i
    out=$(sh ./timecards.sh 2>"$work/err") || { cat "$work/err"; fail "run $i exited $?"; }
    validate "run $i" "$out"
    [[ -s $work/err ]] && { cat "$work/err"; fail "run $i: unexpected stderr"; }
    [[ $(sqlite3 "$db" "select count(*) from demo_timecards where at_tick != running_total") -eq 0 ]] || fail "run $i: a card closed at a tick that is not its running total"
    read -r last idle total < <(sqlite3 -separator ' ' "$db" "select tick, idle, total from fsm")
    [[ $last -eq 64 && $idle -eq $((64 - total)) ]] || fail "run $i: expected 64 ticks with $((64 - total)) idle, got last=$last idle=$idle"
    [[ $(sqlite3 "$db" "select count(*)||' '||min(demo_only)||max(demo_only) from demo_timecards") == *" 11" ]] || fail "run $i: demo flag"
    seen+=$(rows "$out" | cut -f2 | tr '\n' ' ')
done
[[ $(tr ' ' '\n' <<<"$seen" | grep . | sort -u | wc -l) -ge 8 ]] || fail "fewer than 8 distinct hour values in 20 runs"
[[ -z $(ls -A "$work" | grep -v -e '^xdg' -e '^err$') ]] || fail "scratch left behind: $(ls -A "$work")"
echo "ok: 20 random runs: the rules hold; every card closes at tick = running total; 64 ticks, the rest idle; the scratch is removed"

# ---- 3. Without checkpoint events there is no progress.
newdb none
set +e; out=$(sh run-clock.sh --seed 5 --interval 1000 2>"$work/err"); rc=$?; set -e
[[ $rc -eq 3 && -z $(rows "$out") ]] || fail "with no checkpoint events the machine must stall with no cards (rc=$rc)"
grep -q 'clock ran out' "$work/err" || fail "the stall must be reported"
[[ $(sqlite3 "$db" "select tick||' '||idle||' '||worked||' '||total from fsm") == "0 0 0 0" ]] || fail "state moved without a tick"
echo "ok: --checkpoint=1000 on a 64-record archive: no tick, no card, exit 3, the state untouched"

# ---- 4. Predictions: layout and checkpoint settings, against the simulation.
check_run() {  # seed N(blocks) B K M label
    local seed=$1 n=$2 b=$3 k=$4 m=$5 t want got rc
    t=$(predicted_ticks "$n" "$b" "$k"); want=$(sim "$seed" "$t")
    newdb p
    set +e; out=$(sh run-clock.sh --seed "$seed" --ticks "$n" --members "$m" --blocking "$b" --interval "$k" 2>/dev/null); rc=$?; set -e
    got=$(rows "$out" | cut -f1-3)
    local wantrows; wantrows=$(grep -v '^#' <<<"$want" || true)
    [[ $got == "$wantrows" ]] || { echo "--- predicted ($t ticks)"; echo "$wantrows"; echo "--- got"; echo "$got"; fail "seed $seed, $n blocks, -b $b, K=$k, $m members: cards differ from the prediction"; }
    if [[ $want == *'#done' ]]; then [[ $rc -eq 0 ]] || fail "seed $seed N=$n: expected a finished run, rc=$rc"
    else [[ $rc -eq 3 ]] || fail "seed $seed N=$n: expected a stalled run (rc 3), rc=$rc"; fi
    local size; size=$(stat -c %s "$XDG_DATA_HOME/TarGnuWeird/tape.tar")
    [[ $size -eq $(( ($n + $b - 1) / $b * $b * 512 )) ]] || fail "tape size $size is not the whole records predicted for $n blocks, -b $b"
    # TAR_CHECKPOINT counts RECORDS (K, 2K, 3K, ...), while the machine counts callbacks: so the last value is ticks x K
    [[ $(sqlite3 "$db" "select tick from fsm") -eq $((t * k)) ]] || fail "expected the last TAR_CHECKPOINT to be $((t * k)), got $(sqlite3 "$db" "select tick from fsm")"
}
n=0
for seed in 1 42 999 123456789 2147483646; do
    for layout in "64 1 1 1" "64 1 1 3" "64 1 1 7" "20 1 1 1" "30 1 1 2" "41 1 1 1" "59 1 1 1" "60 1 1 1" "128 1 2 1" "128 2 1 1" "130 4 3 1" "260 4 5 2" "70 8 1 2"; do
        set -- $layout; check_run "$seed" "$1" "$2" "$3" "$4"; n=$((n + 1))
    done
done
echo "ok: $n runs (5 seeds x 13 layouts, 20 to 260 blocks, -b 1..8, checkpoint intervals 1..5, 1..7 members): the cards, the stall, the tape size and the last TAR_CHECKPOINT match the prediction"
# a longer tape changes nothing: the extra ticks arrive after the stop and are idle
newdb long; a=$(rows "$(sh run-clock.sh --seed 42 --ticks 64 2>/dev/null)"); newdb long2; b=$(rows "$(sh run-clock.sh --seed 42 --ticks 600 2>/dev/null)")
[[ $a == "$b" ]] || fail "a longer archive changed the cards"
[[ $(sqlite3 "$db" "select idle from fsm") -eq $((600 - $(sqlite3 "$db" "select total from fsm"))) ]] || fail "600 ticks: the idle count is wrong"
echo "ok: a 600-record archive gives the same cards as a 64-record one; every tick after the stop only counts as idle"

# ---- 5. What one checkpoint counts: records written. Measured directly, with ragged sizes too.
count_ticks() {  # tar options... -> number of checkpoint callbacks (the mode comes from the options)
    : > "$work/ticks"; tar --format=ustar --checkpoint-action="exec=echo x >> $work/ticks" "$@" >/dev/null 2>&1 || true; wc -l < "$work/ticks"
}
mkdir -p "$work/rag"; head -c 1 /dev/zero > "$work/rag/a"; head -c 512 /dev/zero > "$work/rag/b"; head -c 513 /dev/zero > "$work/rag/c"; head -c 5000 /dev/zero > "$work/rag/d"; : > "$work/rag/e"
blocks=$(( (1+1) + (1+1) + (1+2) + (1+10) + (1+0) + 2 ))   # a,b,c,d,e headers+data, 2 end blocks
for bk in "1 1" "1 3" "2 1" "5 2" "20 1"; do
    set -- $bk
    got=$(count_ticks -b "$1" --checkpoint="$2" -cf "$work/rag.tar" -C "$work/rag" a b c d e)
    [[ $got -eq $(predicted_ticks "$blocks" "$1" "$2") ]] || fail "-b $1 --checkpoint=$2: $got ticks, predicted $(predicted_ticks "$blocks" "$1" "$2") ($blocks blocks)"
done
echo "ok: create mode: ticks = floor(ceil(blocks / b) / K) for ragged sizes, empty members and five (b, K) pairs ($blocks blocks)"
tar --format=ustar -b1 -cf "$work/rag1.tar" -C "$work/rag" a b c d e
l=$(count_ticks -b1 --checkpoint=1 -tf "$work/rag1.tar"); x=$(count_ticks -b1 --checkpoint=1 -xf "$work/rag1.tar" -C "$work/rag")
echo "note: the same $blocks-block archive gives $blocks ticks when created, $l when listed (-t) and $x when extracted (-x). Listing skips the data blocks it does not need, so what a tick counts depends on the mode; only creation is used here"
set +e; tar -b1 --checkpoint=1 --checkpoint-action='exec=exit 7' -cf /dev/null -C "$work/rag" d; rc=$?; set -e
echo "note: a checkpoint command that exits 7 does not change tar's own exit status here ($rc); the entry does not depend on that, because ticks after the stop only count as idle"

# ---- 6. A failing callback cannot stop tar, and leaves the machine where it was.
# Make a private copy of the entry whose transition always fails (it updates a table that does not exist).
mkdir -p "$work/clone"; cp run-clock.sh layout.sh tick.sh machine.sql "$work/clone/"
sed 's/UPDATE fsm SET worked/UPDATE nosuchtable SET worked/' tick.sql > "$work/clone/tick.sql"
grep -q nosuchtable "$work/clone/tick.sql" || fail "could not break the copy of tick.sql"
newdb bad
set +e; out=$(sh "$work/clone/run-clock.sh" --seed 7 2>"$work/err"); rc=$?; set -e
[[ $rc -eq 3 && -z $(rows "$out") ]] || fail "a callback that always fails must leave no cards and exit 3 (rc=$rc)"
[[ $(sqlite3 "$db" "select count(*) from demo_timecards") -eq 0 ]] || fail "a failing callback wrote a card"
grep -q 'no such table' "$work/err" || fail "the callback's error must reach stderr, not be hidden"
echo "ok: a callback that fails on every tick: tar still finishes the archive, no card is written, the error is shown, the run exits 3"
# a hostile checkpoint number never reaches SQL
TAR_CHECKPOINT='1; drop table fsm' TICK_DB=$work/x.db TICK_SQL=$here/tick.sql sh tick.sh 2>/dev/null && fail "tick.sh accepted a non-numeric checkpoint"
[[ ! -e $work/x.db ]] || fail "tick.sh touched the database for a bad checkpoint"
echo "ok: tick.sh refuses a TAR_CHECKPOINT that is not a number, before it opens the database"

# ---- 7. The schema refuses what it must.
newdb sch; sh run-clock.sh --seed 3 >/dev/null
sqlite3 "$db" "insert into demo_timecards values(1,'Coding',12,12,'w',1,0)" 2>/dev/null && fail "db accepted a non-demo row"
sqlite3 "$db" "insert into demo_timecards values(1,'Coding',9,9,'w',1,1)" 2>/dev/null && fail "db accepted 9 hours"
sqlite3 "$db" "insert into demo_timecards values(1,'Banking',12,12,'w',1,1)" 2>/dev/null && fail "db accepted a fifth category"
echo "ok: SQLite refuses a non-demo row, 9 hours and a fifth category"
echo "OK: tar-gnu-weird ($(tar --version | head -1))"
