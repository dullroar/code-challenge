#!/usr/bin/env bash
# Checks the rules of the challenge for the Node.js port: the loop body is really empty, the program is nothing but
# that one for statement, the time cards obey the rules, a seed replays a run, the ISO week is right, and the terminal
# pulse stays out of the way (and out of CI). Uses throwaway data. Needs Node 24+ (node:sqlite), sqlite3, GNU date.
set -euo pipefail
cd "$(dirname "$0")"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
export XDG_DATA_HOME=$work/xdg TMPDIR=$work
fail() { echo "FAIL: $*"; exit 1; }
node -e 'if (+process.versions.node.split(".")[0] < 24) process.exit(1)' || fail "needs Node 24 or newer (node:sqlite); found $(node --version)"
command -v sqlite3 >/dev/null || fail "sqlite3 is needed"
db=$XDG_DATA_HOME/JavaScript/demo-timecards.db
rows() { grep -E $'^(Meetings|Coding|Debugging|Learning)\t' <<<"$1" || true; }
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

# ---- 1. The ridiculous constraint is real, and a mutated program is caught.
node check-structure.mjs timecards.mjs || fail "structure"
mut() {   # label, python expression turning the source into a mutant
    node -e 'const s = require("node:fs").readFileSync(process.argv[1], "utf8"); process.stdout.write(new Function("s", "return " + process.argv[2])(s))' timecards.mjs "$2" > "$work/mutant.mjs"
    if node check-structure.mjs "$work/mutant.mjs" >/dev/null 2>&1; then fail "the structure check accepted a mutant: $1"; fi
}
mut "statement after the loop" 's + "\nconsole.log(1);\n"'
mut "a body in the loop" 's.replace("{ /* Intentionally empty. */ }", "{ i.frames++; }")'
mut "a runEverything wrapper" '"function runEverything() {\n" + s + "\n}\nrunEverything();\n"'
mut "a hidden while" 's.replace("i.hours.push(10", "(() => { while (false); })(), i.hours.push(10")'
mut "a second for" 's.replace("i.hours.push(10", "(() => { for (;;) break; })(), i.hours.push(10")'
mut "eval" 's.replace("i.hours.push(10", "eval(1), i.hours.push(10")'
if grep -Eq "node:(net|http|https|http2|dns|tls|dgram|child_process|worker_threads)" timecards.mjs; then fail "the program imports a network, process or thread module"; fi
echo "ok: after its imports the file is one for statement with an empty body; six mutants (a statement after it, a body, a runEverything wrapper, a hidden while, a second for, eval) are rejected; no network or process module"

# ---- 2. Random runs: the rules of the challenge, against the file and the database.
for i in $(seq 1 25); do
    out=$(node timecards.mjs 2>"$work/err") || { cat "$work/err"; fail "run $i exited $?"; }
    validate "run $i" "$out"
    [[ -s $work/err ]] && { cat "$work/err"; fail "run $i: unexpected stderr"; }
    grep -qx 'DEMO ONLY - no real time system is involved' <<<"$out" && fail "run $i: the pulse printed on a non-terminal"
    grep -q $'\033' <<<"$out" && fail "run $i: escape codes on a non-terminal"
    [[ $out == *"Total simulated hours: "*".0"* && $out == *"Saved locally for the modernization exercise."* ]] || fail "run $i: the result text is missing"
    seen+=$(rows "$out" | cut -f2 | tr '\n' ' ')
done
[[ $(tr ' ' '\n' <<<"$seen" | grep . | sort -u | wc -l) -ge 8 ]] || fail "fewer than 8 distinct hour values in 25 runs"
[[ $(sqlite3 "$db" "select count(*) from runs") -eq 25 ]] || fail "expected 25 runs in the database"
[[ $(sqlite3 "$db" "select count(*) from demo_timecards where demo_only <> 1") -eq 0 ]] || fail "a non-demo row"
[[ $(sqlite3 "$db" "select count(distinct user_id) from demo_timecards") -eq 1 && $(sqlite3 "$db" "select user_id from demo_timecards limit 1") == "$(id -un)" ]] || fail "user_id is not the current user"
# every run: running_total is the sum of hours so far, and only the last card is over 40
bad=$(sqlite3 "$db" "select count(*) from (select run_id, running_total - sum(hours) over (partition by run_id order by rowid) as d from demo_timecards) where d <> 0")
[[ $bad -eq 0 ]] || fail "$bad rows whose running_total is not the sum of the hours so far"
[[ $(sqlite3 "$db" "select count(*) from (select run_id, max(running_total) m, min(running_total) n from demo_timecards group by run_id) where m <= 40") -eq 0 ]] || fail "a run that stopped at 40 or under"
echo "ok: 25 random runs: categories in order, hours 10-19, running totals, stop right after the first total over 40, DEMO ONLY, nothing on stderr or in escape codes, the user and the totals in SQLite"

# ---- 3. A seed replays a run, and a separate simulation of the generator agrees (including the edge cases).
sim() {  # seed -> category TAB hours TAB total, until the total passes 40 (Park-Miller, as the program has it)
    awk -v r="$1" 'BEGIN { split("Meetings Coding Debugging Learning Meetings", cat, " ")
        for (n = 1; ; n++) { r = r * 48271 % 2147483647; h = 10 + r % 10; t += h; printf "%s\t%d\t%d\n", cat[n], h, t; if (t > 40) break } }'
}
find_seed() {  # find a seed whose run has the given total and card count (awk searches, the program then has to agree)
    awk -v want_t="$1" -v want_n="$2" 'BEGIN { for (s = 1; s < 400000; s++) { r = s; t = 0; for (n = 1; n <= 5; n++) { r = r * 48271 % 2147483647; t += 10 + r % 10; if (t > 40) break }
        if (t == want_t && n == want_n) { print s; exit } } }'
}
check_seed() {
    local seed=$1 out got want
    out=$(SEED=$seed node timecards.mjs); got=$(rows "$out" | cut -f1-3); want=$(sim "$seed")
    [[ $got == "$want" ]] || { echo "--- seed $seed want"; echo "$want"; echo "--- got"; echo "$got"; fail "seed $seed: the program and the simulation disagree"; }
}
for seed in 1 2 42 999 123456789 2147483646; do check_seed "$seed"; done
a=$(rows "$(SEED=42 node timecards.mjs)" | cut -f1-3); b=$(rows "$(SEED=42 node timecards.mjs)" | cut -f1-3)
[[ $a == "$b" ]] || fail "SEED=42 twice gave different cards"
for spec in "41 3" "41 4" "42 4" "50 5" "51 5" "57 3"; do
    set -- $spec; s=$(find_seed "$1" "$2"); [[ -n $s ]] || fail "no seed found for total $1 in $2 cards"
    check_seed "$s"
done
# a run of exactly 40 after four cards must go on to a fifth: four tens is rare, so search for four cards that make 40 and confirm the program takes a fifth
s=$(awk 'BEGIN { for (s = 1; s < 4000000; s++) { r = s; t = 0; for (n = 1; n <= 4; n++) { r = r * 48271 % 2147483647; t += 10 + r % 10 } if (t == 40) { print s; exit } } }')
if [[ -n $s ]]; then check_seed "$s"; [[ $(rows "$(SEED=$s node timecards.mjs)" | wc -l) -eq 5 ]] || fail "a total of exactly 40 after four cards must continue to a fifth"; echo "ok: seed $s makes exactly 40 after four cards, and the program goes on to a fifth"; fi
echo "ok: replay: SEED=42 twice gives the same cards; 12 seeds (totals 41, 42, 50, 51, 57 in 3 to 5 cards) match a separate simulation of the generator"

# ---- 4. The ISO week is computed by hand in the program; it must agree with GNU date, year boundaries included.
for d in 2026-12-31 2021-01-03 2024-12-30 2026-01-01 2016-01-03 2020-12-31 2027-01-03 2015-12-28 2012-01-01 2038-12-31; do
    got=$(NOW=$d SEED=1 node timecards.mjs | sed -n 2p | cut -f4); want=$(date -d "$d" +%G-W%V)
    [[ $got == "$want" ]] || fail "NOW=$d: week $got, GNU date says $want"
done
echo "ok: ISO year and week agree with GNU date for 10 dates, including 53-week years and the first days of January"

# ---- 5. The pulse: only on a terminal, never for CI, and never before the computation is complete.
if command -v script >/dev/null; then
    pty() { env "$@" timeout 30 script -qec "node timecards.mjs" /dev/null < /dev/null | tr -d '\r'; }
    t=$(pty PULSE_CYCLES=1 SEED=7); [[ $t == *$'\033[1m'*DEMO\ ONLY* && $t == *$'\033[2m'* ]] || fail "on a terminal the DEMO ONLY line should pulse (bold, then dim)"
    first=${t%%$'\033'*}; [[ $first == *"# committed total="* && $first == *"Saved locally"* ]] || fail "the pulse started before the report was printed"
    t=$(pty PULSE_CYCLES=1 SEED=7 NO_COLOR=1); [[ $t != *$'\033[1m'* && $t != *$'\033[2m'* && $t != *$'\033[0m'* ]] || fail "NO_COLOR: styling codes were printed"
    [[ $t == *"*DEMO ONLY"* ]] || fail "NO_COLOR: the plain pulse should still blink"
    t=$(pty PULSE_CYCLES=1 SEED=7 TERM=dumb); [[ $t != *$'\033'* ]] || fail "TERM=dumb: escape codes were printed"
    echo "ok: on a pseudo-terminal the DEMO ONLY line pulses (bold, dim) after the report; NO_COLOR uses plain blinking; TERM=dumb and redirected output get no escape codes and no pulse"
else
    echo "note: 'script' is not installed; the terminal pulse was not tested"
fi
start=$SECONDS; SEED=3 node timecards.mjs >/dev/null; (( SECONDS - start < 3 )) || fail "a redirected run took 3 seconds or more: is the pulse running?"
echo "ok: a redirected run ends at once (no timer, no sleep)"

# ---- 6. Errors and the schema.
# (a regular file where the data folder should be: mkdir fails at once. Not /proc: a recursive mkdir there spins in Node 24.)
: > "$work/afile"
set +e; XDG_DATA_HOME=$work/afile timeout 20 node timecards.mjs >/dev/null 2>"$work/err"; rc=$?; set -e
[[ $rc -ne 0 && -s $work/err ]] || fail "an unwritable data directory must end with a non-zero status and a message (rc=$rc)"
sqlite3 "$db" "insert into demo_timecards values(1,'Coding',12,12,'u',2026,1,0)" 2>/dev/null && fail "db accepted a non-demo row"
sqlite3 "$db" "insert into demo_timecards values(1,'Coding',9,9,'u',2026,1,1)" 2>/dev/null && fail "db accepted 9 hours"
sqlite3 "$db" "insert into demo_timecards values(1,'Banking',12,12,'u',2026,1,1)" 2>/dev/null && fail "db accepted a fifth category"
sqlite3 "$db" "insert into runs(seed, demo_only) values (1, 0)" 2>/dev/null && fail "db accepted a non-demo run"
echo "ok: an unwritable data folder ends with a non-zero status and a message; SQLite refuses a non-demo row or run, 9 hours and a fifth category"
echo "OK: javascript (node $(node --version))"
