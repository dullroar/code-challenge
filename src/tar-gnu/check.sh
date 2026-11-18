#!/usr/bin/env bash
# Checks the rules of the challenge for the GNU tar entry: the program really is the archive, the inspector
# is passive, the interpreter fails closed, and the four kinds of "same" are kept apart. Uses throwaway dirs.
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
export TMPDIR=$work
fail() { echo "FAIL: $*"; exit 1; }
tar --version | head -1 | grep -q 'GNU tar' || fail "this entry needs GNU tar (--to-command, --occurrence); found: $(tar --version | head -1)"
command -v sqlite3 >/dev/null || fail "sqlite3 is needed"

# ---- 1. The ridiculous constraint is real: tar owns the loop; the dispatcher owns none of the algorithm.
code=$(grep -Ev '^\s*(#|$)' dispatch.sh)
if grep -Eqw 'for|while|until|eval|exec' <<<"$code"; then fail "dispatch.sh has a loop or eval/exec keyword"; fi
grep -q '40' <<<"$code" && fail "dispatch.sh mentions 40: the limit must come from the archive"
grep -Eq 'urandom|RANDOM|random\(' <<<"$code" && fail "dispatch.sh rolls dice: the dice belong in the archive"
grep -Fq '$((' <<<"$code" && fail "dispatch.sh does shell arithmetic: the running total belongs to the card record's SQL, the order to the archive"
grep -Eq 'cats=|categories=' <<<"$code" && fail "dispatch.sh seems to keep a category sequence"
grep -q -- '--to-command' interpret.sh || fail "interpret.sh must be where --to-command is switched on"
if grep -Eq -- '--to-command|--checkpoint|sqlite3|dispatch|eval|\bsh -c\b' <(grep -Ev '^\s*#' inspect.sh); then fail "inspect.sh may only read: found --to-command, sqlite3, dispatch or eval"; fi
echo "ok: tar is the loop; dispatch.sh has no loop, no dice, no 40, no category order; inspect.sh cannot execute"

# ---- helpers
rows() { grep -E $'^(Meetings|Coding|Debugging|Learning)\t' <<<"$1" || true; }
cats=(Meetings Coding Debugging Learning Meetings)
expect_rows() {   # hours... -> the rows an independent simulation says the program must print (category, hours, total)
    local t=0 k=0 h
    for h in "$@"; do t=$((t + h)); printf '%s\t%s\t%s\n' "${cats[k]}" "$h" "$t"; k=$((k + 1)); (( t > 40 )) && break; done
}
newdb() { export XDG_DATA_HOME=$work/xdg.$1 TARPROG_DB=$work/db.$1; rm -rf "$XDG_DATA_HOME" "$TARPROG_DB"; mkdir -p "$XDG_DATA_HOME"; }
validate() {   # label output
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
canary() { [[ ! -e $work/CANARY && ! -e $work/CANARY2 && ! -e $PWD/CANARY && ! -e $work/stage/CANARY ]] || fail "$1: a canary file exists: archive content was executed"; }
mkar() {   # OUT member:content ... : a hand-made archive, members in the order given ("\n" in content = newline)
    local out=$1; shift; local s; s=$(mktemp -d "$work/mk.XXXXXX"); local names=() m
    for m in "$@"; do mkdir -p "$s/$(dirname "${m%%:*}")"; printf '%b' "${m#*:}" > "$s/${m%%:*}"; names+=("${m%%:*}"); done
    tar --format=ustar --mtime=@0 --owner=0 --group=0 --numeric-owner -cf "$out" -C "$s" "${names[@]}"
}

# ---- 2. Random runs through the whole demo; every rule of the challenge.
for i in $(seq 1 25); do
    newdb r$i
    out=$(sh ./timecards.sh 2>"$work/err") || { cat "$work/err"; fail "run $i: timecards.sh exited $?"; }
    validate "run $i" "$out"
    [[ -s $work/err ]] && { cat "$work/err"; fail "run $i: unexpected stderr"; }
    run=$(sed -nE 's/^# DEMO ONLY run ([0-9]+)$/\1/p' <<<"$out")
    dbrow=$(sqlite3 "$TARPROG_DB" "select count(*)||' '||max(running_total)||' '||min(demo_only)||max(demo_only) from demo_timecards where run_id=$run")
    entries=$(sed -nE 's/.*entries=([0-9]+).*/\1/p' <<<"$out"); total=$(sed -nE 's/.*total=([0-9]+).*/\1/p' <<<"$out")
    [[ $dbrow == "$entries $total 11" ]] || fail "run $i: db says '$dbrow', output says '$entries $total 11'"
    seen+=$(rows "$out" | cut -f2 | tr '\n' ' ')
done
[[ $(tr ' ' '\n' <<<"$seen" | grep . | sort -u | wc -l) -ge 8 ]] || fail "fewer than 8 distinct hour values in 25 runs: is it random?"
echo "ok: 25 random runs: categories in order, hours 10-19, totals right, stop right after the first total over 40, DEMO ONLY, SQLite agrees"

# ---- 3. Forced dice: exact scenarios, predicted by an independent simulation.
forced() {
    newdb f; local out got want
    sh build-archive.sh --seed 7 --hours "$*" "$work/f.tar"
    out=$(sh interpret.sh --execute "$work/f.tar") || fail "forced '$*': interpreter exited $?"
    got=$(rows "$out" | cut -f1-3); want=$(expect_rows "$@")
    [[ $got == "$want" ]] || { echo "--- want"; echo "$want"; echo "--- got"; echo "$got"; fail "forced '$*' differs"; }
    # the cards after the stop were read from the archive and ignored
    local nextra=$(( 5 - $(wc -l <<<"$want") ))
    [[ $(sqlite3 "$TARPROG_DB" "select count(*) from trace where outcome like 'ignored%'") -eq $nextra ]] || fail "forced '$*': expected $nextra ignored cards"
}
forced 10 10 10 10 10; forced 19 19 19 10 10; forced 11 12 13 14 15; forced 15 16 10 10 10; forced 10 10 10 10 11; forced 18 19 10 10 10; forced 14 13 14 10 10
echo "ok: 7 forced-dice programs: a total of exactly 40 continues; the crossing card is kept; later cards are read and ignored"

# ---- 4. Four different kinds of "the same".
sh build-archive.sh --seed 99 "$work/a1.tar"; sh build-archive.sh --seed 99 "$work/a2.tar"; sh build-archive.sh --seed 100 "$work/a3.tar"
cmp -s "$work/a1.tar" "$work/a2.tar" || fail "same seed, different bytes: the serializer is not deterministic"
cmp -s "$work/a1.tar" "$work/a3.tar" && fail "different seeds gave the same bytes"
echo "ok: byte-for-byte: the same seed gives the same archive bytes; another seed does not"
newdb s1; o1=$(sh interpret.sh --execute "$work/a1.tar"); newdb s2; o2=$(sh interpret.sh --execute "$work/a1.tar")
[[ $(rows "$o1") == "$(rows "$o2")" ]] || fail "same archive, two fresh databases, different cards"
echo "ok: behavioral: one archive run in two fresh databases gives the same cards (the weeks agree too, unless midnight passed)"
# state: what the inspector decodes is what the database holds
newdb s3; sh interpret.sh --execute "$work/a1.tar" >/dev/null
decoded=$(sh inspect.sh "$work/a1.tar" | sed -nE 's/^[0-9]+ +[0-9]+\.card +file +[0-9]+ +category=([A-Za-z]+) hours=([0-9]+)$/\1 \2/p')
dbcards=$(sqlite3 -separator ' ' "$TARPROG_DB" "select category, hours from demo_timecards order by rowid")
[[ $(head -n "$(wc -l <<<"$dbcards")" <<<"$decoded") == "$dbcards" ]] || fail "the cards the inspector decodes are not the cards the database holds"
echo "ok: state: the cards the inspector decodes are the cards the database holds (the unread ones were never run)"
# not idempotent: a second run into the same database is a second run, with the same cards
sh interpret.sh --execute "$work/a1.tar" >/dev/null
[[ $(sqlite3 "$TARPROG_DB" "select count(*) from runs") -eq 2 ]] || fail "expected 2 runs after replaying into one database"
[[ $(sqlite3 "$TARPROG_DB" "select group_concat(category||hours) from demo_timecards where run_id=1") == $(sqlite3 "$TARPROG_DB" "select group_concat(category||hours) from demo_timecards where run_id=2") ]] || fail "replay made different cards"
echo "ok: replay is deterministic but NOT idempotent: a second run into the same database adds a second run (nothing claims live-process equivalence)"

# ---- 5. The inspector and the interpreter agree on structure, and the dispatcher saw exactly what was listed.
newdb ag; sh interpret.sh --execute "$work/a1.tar" >/dev/null
insp=$(sh inspect.sh "$work/a1.tar" | awk '$2 ~ /^[0-9][0-9][0-9]\./ { print $2 }')
traced=$(sqlite3 "$TARPROG_DB" "select name from trace order by n")
listed=$(tar -tf "$work/a1.tar")
[[ $insp == "$listed" && $traced == "$listed" ]] || { echo "inspector: $insp"; echo "tar -t: $listed"; echo "traced: $traced"; fail "inspector, tar -t and the dispatcher disagree on the member sequence"; }
echo "ok: the inspector, tar -t and the dispatcher's own trace list the same 12 members in the same order"

# ---- 6. Passive consumers: listing, plain extraction and inspection run nothing.
mkdir "$work/shim"; for p in sqlite3 date; do printf '#!/bin/sh\necho "%s $*" >> "%s/shim.log"\nexit 1\n' "$p" "$work" > "$work/shim/$p"; chmod +x "$work/shim/$p"; done
mkar "$work/evil.tar" "000.begin:format=tarprog/1\nseed=1\nlabel=DEMO ONLY\n" "010.card:category=Coding\nhours=\$(touch $work/CANARY)\n" \
    "020.card:category=Coding\nhours=10; touch $work/CANARY2\n" "030.exec:touch $work/CANARY\n" "990.show:"
: > "$work/shim.log"
( cd "$work" && PATH=$work/shim:$PATH sh "$here/inspect.sh" evil.tar > evil.report; echo $? > evil.rc ) || true
[[ $(cat "$work/evil.rc") -eq 4 ]] || fail "inspector exit status on the hostile archive should be 4, got $(cat "$work/evil.rc")"
canary inspector; [[ ! -s $work/shim.log ]] || fail "inspector called sqlite3 or date: $(cat "$work/shim.log")"
[[ $(grep -c REFUSE "$work/evil.report") -eq 3 ]] || { cat "$work/evil.report"; fail "inspector should flag 3 records (2 bad cards, 1 unknown type)"; }
mkdir "$work/plain"; tar -C "$work/plain" -xf "$work/evil.tar"; tar -tvf "$work/evil.tar" >/dev/null
canary "plain tar -xf"; [[ -f $work/plain/030.exec ]] || fail "plain extraction should have written the member as an inert file"
[[ ! -e $work/plain/demo-timecards.db ]] || fail "plain extraction created a database"
echo "ok: tar -t, plain tar -xf and the inspector run nothing from a hostile archive (3 canaries, a shimmed sqlite3 and date, no DB)"

# ---- 7. The interpreter fails closed.
sh interpret.sh "$work/a1.tar" 2>/dev/null && fail "interpret.sh ran without --execute"
newdb fc; sh interpret.sh --execute "$work/evil.tar" 2>/dev/null && fail "interpreter ran a hostile archive"
canary "interpreter preflight"; [[ ! -e $TARPROG_DB ]] || fail "the preflight let something reach the database"
echo "ok: no --execute, no run; a hostile archive is refused by the preflight before anything runs"
# Defense in depth: skip the preflight and hand tar the hostile archive directly. tar keeps going after a failing
# child, so the dispatcher itself must refuse everything after the first bad record.
mkar "$work/mid.tar" "000.begin:format=tarprog/1\nseed=1\nlabel=DEMO ONLY\n" "010.card:category=Meetings\nhours=12\n" "030.exec:touch $work/CANARY\n" \
    "040.card:category=Coding\nhours=15\n" "041.stop-over:limit=40\n" "990.show:"
newdb dd; mkdir -p "$work/stage"
set +e; tar -C "$work/stage" --to-command="sh $here/dispatch.sh" -xf "$work/mid.tar" >/dev/null 2>"$work/tar.err"; rc=$?; set -e
[[ $rc -ne 0 ]] || fail "tar exited 0 although a child refused a record"
canary "dispatcher alone"
[[ $(sqlite3 "$TARPROG_DB" "select count(*) from demo_timecards") -eq 1 ]] || fail "records after the bad one were not refused"
[[ $(sqlite3 "$TARPROG_DB" "select count(*) from trace where outcome like 'refused%'") -eq 4 ]] || fail "expected the bad record and the 3 after it to be refused"
echo "ok: with the preflight bypassed, tar exits $rc, the dispatcher refuses the bad record and everything after it, and only the card before it ran"
# Each kind of bad member, run alone behind a good begin: the dispatcher must refuse it.
bad() {
    local label=$1; shift; newdb bad; mkar "$work/bad.tar" "000.begin:format=tarprog/1\nseed=1\nlabel=DEMO ONLY\n" "$@"
    mkdir -p "$work/stage"; set +e; tar -C "$work/stage" --to-command="sh $here/dispatch.sh" -xf "$work/bad.tar" >/dev/null 2>&1; set -e
    [[ $(sqlite3 "$TARPROG_DB" "select count(*) from demo_timecards") -eq 0 ]] || fail "$label: a card was accepted"
    [[ $(sqlite3 "$TARPROG_DB" "select count(*) from trace where outcome like 'refused%'") -ge 1 ]] || fail "$label: nothing was refused"
}
bad "hours=9" "010.card:category=Coding\nhours=09\n"
bad "hours=20" "010.card:category=Coding\nhours=20\n"
bad "hours with a command" "010.card:category=Coding\nhours=1\$(touch $work/CANARY)\n"
bad "unknown category" "010.card:category=Banking\nhours=12\n"
bad "extra line" "010.card:category=Coding\nhours=12\nnote=x\n"
bad "bad name" "10.card:category=Coding\nhours=12\n"
bad "name with a path" "x/010.card:category=Coding\nhours=12\n"
bad "oversize" "010.card:$(head -c 400 /dev/zero | tr '\0' 'a')"
bad "unknown op" "010.run:category=Coding\nhours=12\n"
canary "bad members"
# a member that is not a regular file never reaches the dispatcher, and the inspector flags it
mkdir "$work/ty"; mkdir "$work/ty/050.dir"; ln -s /etc/passwd "$work/ty/060.link"; printf 'format=tarprog/1\nseed=1\nlabel=DEMO ONLY\n' > "$work/ty/000.begin"
tar --format=ustar -cf "$work/ty.tar" -C "$work/ty" 000.begin 050.dir 060.link
set +e; sh inspect.sh "$work/ty.tar" >/dev/null; rc=$?; set -e; [[ $rc -eq 4 ]] || fail "inspector should flag a directory and a symlink member (exit 4, got $rc)"
echo "ok: bad hours, command-looking hours, unknown category, extra line, bad name, oversize, unknown op, directory and symlink members are all refused"

# ---- 8. The database refuses what the schema forbids, whoever asks.
newdb db; sh interpret.sh --execute "$work/a1.tar" >/dev/null
sqlite3 "$TARPROG_DB" "insert into demo_timecards values(1,'Coding',12,12,'2026-W01',0)" 2>/dev/null && fail "db accepted a non-demo row"
sqlite3 "$TARPROG_DB" "insert into demo_timecards values(1,'Coding',9,9,'2026-W01',1)" 2>/dev/null && fail "db accepted 9 hours"
sqlite3 "$TARPROG_DB" "insert into demo_timecards values(1,'Banking',12,12,'2026-W01',1)" 2>/dev/null && fail "db accepted a fifth category"
echo "ok: SQLite refuses a non-demo row, 9 hours and a fifth category"
echo "OK: tar-gnu ($(tar --version | head -1))"
