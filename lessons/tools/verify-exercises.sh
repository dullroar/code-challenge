#!/usr/bin/env bash
# Runs the reference solution of every Docker-runnable exercise in lessons/exercises.md and reports
# PASS or FAIL for each, so the exercises and answers-key.md are proven against the real entries.
#
#   lessons/tools/verify-exercises.sh            # all of them (several minutes: it builds images)
#   lessons/tools/verify-exercises.sh B1 B6      # only the named exercises (prefix match)
#
# Needs Docker and the trusted base images (sandbox/container/build-bases.sh). Every mutation is made
# on a COPY of the entry in a temp folder, so your checkout is never touched. Windows Sandbox
# exercises are checked by lessons/tools/verify-windows.ps1.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); repo=$(cd "$here/../.." && pwd); cd "$repo"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
sol=$here/../solutions
# The helper scripts are run through bash, so this works whatever their file mode is (a Windows checkout
# loses the executable bit). chk, sbx and c2 hold function NAMES, which "$chk" ... runs like a command.
chk_run() { bash "$here/check-demo.sh" "$@"; }
sbx_run() { bash "$here/run-in-sandbox.sh" "$@"; }
c2_run()  { bash "$sol/c2-forth-rule-check.sh" "$@"; }
chk=chk_run; sbx=sbx_run
pass=0; failn=0; failed=()
want=("$@")
selected() { [[ ${#want[@]} -eq 0 ]] && return 0; local w; for w in "${want[@]}"; do [[ $1 == $w* ]] && return 0; done; return 1; }
ok()  { echo "  PASS  $1"; pass=$((pass+1)); }
bad() { echo "  FAIL  $1: $2"; failn=$((failn+1)); failed+=("$1"); }
# expect LABEL COMMAND...  (must succeed)      expectnot LABEL COMMAND...  (must fail)
expect()    { local l=$1; shift; if "$@" >"$W/last" 2>&1; then ok "$l"; else bad "$l" "$(tail -2 "$W/last" | tr '\n' ' ')"; fi; }
expectnot() { local l=$1; shift; "$@" >"$W/last" 2>&1; local rc=$?
              if (( rc == 0 )); then bad "$l" "expected a failure but it passed"
              elif (( rc == 126 || rc == 127 )); then bad "$l" "the command could not be run (exit $rc), so this proves nothing: $(tail -1 "$W/last")"
              else ok "$l"; fi; }
copy() { rm -rf "$W/$2"; mkdir -p "$W/$2"; cp -r "$1" "$W/$2/"
         { grep -rlI $'\r' "$W/$2" | xargs -r sed -i $'s/\r$//'; } 2>/dev/null   # a Windows checkout has CRLF; mutations match LF
         echo "$W/$2/$(basename "$1")"; }   # copy SRC SLOT -> path of the copy
img()  { sandbox/container/run-image.sh "$1" > "$2" 2>&1; }                                        # img DIR OUTFILE
contains() { grep -q -- "$2" "$1"; }
mutate() { # mutate FILE OLD NEW : replace the first literal OLD with NEW; fails if OLD is absent
  python -I -c '
import sys
p, old, new = sys.argv[1:4]
s = open(p, encoding="utf-8", newline="").read()
cr, lf = chr(13), chr(10)
if cr + lf in s: old, new = old.replace(lf, cr + lf), new.replace(lf, cr + lf)   # a Windows checkout has CRLF
if old not in s: sys.exit("mutation target not found: " + old)
open(p, "w", encoding="utf-8", newline="").write(s.replace(old, new, 1))' "$1" "$2" "$3"
}

echo "== verifying exercises (work dir $W)"

if selected A1; then echo "A1 baseline rows"
  for e in cobol-weird forth-weird regex-sed regex-dotnet; do img src/$e "$W/a1-$e.txt"; expect "A1 $e passes check-demo" "$chk" "$W/a1-$e.txt"; done
fi

if selected B1; then echo "B1 COBOL ALTER"
  d=$(copy src/cobol-weird b1); mutate "$d/timecards.cob" 'PIC 99 VALUE 59.' 'PIC 99 VALUE 49.'
  img "$d" "$W/b1.txt"; expect "B1 headroom 49 stops above 50" "$chk" "$W/b1.txt" 50
  expectnot "B1 ...and the entry's own check.sh fails" sandbox/run.sh "$d"
  d=$(copy src/cobol-weird b1b); mutate "$d/timecards.cob" $'       NEXT-CARD.\n           GO TO MEETINGS-CARD.' $'       NEXT-CARD.\n           DISPLAY "x"\n           GO TO MEETINGS-CARD.'
  img "$d" "$W/b1b.txt"; if contains "$W/b1b.txt" "is not an alterable paragraph"; then ok "B1 DISPLAY in NEXT-CARD: 'not an alterable paragraph'"; else bad B1b "compiler message not seen"; fi
fi

if selected B2; then echo "B2 Haskell laziness"
  d=$(copy src/haskell-weird b2); mutate "$d/timecards.hs" 'entries <- evaluate (length cards)' 'let entries = length cards'
  img "$d" "$W/b2.txt"; if contains "$W/b2.txt" "handle is closed"; then ok "B2 lazy let: 'handle is closed'"; else bad B2a "no 'handle is closed'"; fi
  expectnot "B2 ...and check-demo fails" "$chk" "$W/b2.txt"
  d=$(copy src/haskell-weird b2b); mutate "$d/timecards.hs" 'unsafeInterleaveIO $ case actions of' 'id $ case actions of'
  img "$d" "$W/b2b.txt"; if contains "$W/b2b.txt" "cyclic evaluation in fixIO"; then ok "B2 no unsafeInterleaveIO: 'cyclic evaluation in fixIO'"; else bad B2b "no 'cyclic evaluation'"; fi
fi

if selected B3; then echo "B3 Forth anchor"
  d=$(copy src/forth-weird b3); mutate "$d/timecards.fs" $'0 0 >in @ step rewind?' $'0 0\n>in @ step rewind?'
  img "$d" "$W/b3a.txt"; expect "B3 '0 0' on the previous line is harmless" "$chk" "$W/b3a.txt"
  d=$(copy src/forth-weird b3b); mutate "$d/timecards.fs" '0 0 >in @ step rewind?' '>in @ 0 0 step rewind?'
  SANDBOX_TIMEOUT=30 img "$d" "$W/b3b.txt"; expectnot "B3 '>in @ 0 0 ...' runs away (no PASS)" "$chk" "$W/b3b.txt"
  rows=$(grep -cE $'^(Meetings|Coding|Debugging|Learning)\t' "$W/b3b.txt")
  if ! contains "$W/b3b.txt" "# committed" && (( rows > 20 )); then ok "B3 ...hundreds of rows, never commits ($rows rows)"; else bad B3b "did not run away"; fi
  d=$(copy src/forth-weird b3c); mutate "$d/timecards.fs" 'over 41 <' 'over 51 <'
  img "$d" "$W/b3c.txt"; expect "B3 '51 <' stops above 50" "$chk" "$W/b3c.txt" 50
fi

if selected B4; then echo "B4 Make"
  d=$(copy src/make-gnu b4); mutate "$d/Makefile" '0))@:)' '0)))'
  img "$d" "$W/b4.txt"; if contains "$W/b4.txt" "# committed total=0 entries=0"; then ok "B4 no '@:': no restart, zero cards"; else bad B4 "still produced cards"; fi
  expectnot "B4 ...check-demo fails" "$chk" "$W/b4.txt"
  "$sbx" src/make-gnu make NOW=1700000000 > "$W/b4n.txt" 2>&1
  if contains "$W/b4n.txt" "2023-W46" && [[ $(date -u -d @1700000000 +%G-W%V) == 2023-W46 ]]; then ok "B4 NOW=1700000000 gives 2023-W46 (matches date)"; else bad B4n "week mismatch"; fi
fi

if selected B5; then echo "B5 CMake literal"
  d=$(copy src/cmake b5)
  python -I -c '
import sys, re
p = sys.argv[1]; s = open(p, encoding="utf-8", newline="").read()
n = re.subn(r"\"\^x{41}\"", "\"^" + "x" * 31 + "\"", s, count=1)
assert n[1] == 1; open(p, "w", encoding="utf-8", newline="").write(n[0])' "$d/timecards.cmake"
  img "$d" "$W/b5.txt"; expect "B5 31 x's: stops above 30" "$chk" "$W/b5.txt" 30
  expectnot "B5 ...entry's own check.sh fails" sandbox/run.sh "$d"
fi

if selected B6; then echo "B6 APL"
  d=$(copy src/apl-weird b6); mutate "$d/timecards.apl" ',5↓⊂[1]' ',4↓⊂[1]'
  SANDBOX_TIMEOUT=40 img "$d" "$W/b6a.txt"; if ! contains "$W/b6a.txt" "# committed" && (contains "$W/b6a.txt" "TIMEOUT" || contains "$W/b6a.txt" "Killed") && (( $(grep -cE $'^(Meetings|Coding|Debugging|Learning)\t([0-9]+)\t\\2\t' "$W/b6a.txt") > 20 )); then ok "B6 4-down: never commits, total == hours on every row (TIMEOUT, or killed for memory)"; else bad B6a "did not run away as described"; fi
  d=$(copy src/apl-weird b6b); mutate "$d/timecards.apl" $'\n⎕IO←0\n' $'\n⎕IO←1\n'
  img "$d" "$W/b6b.txt"; if contains "$W/b6b.txt" "INDEX ERROR"; then ok "B6 IO=1: INDEX ERROR"; else bad B6b "no INDEX ERROR"; fi
fi

if selected B7; then echo "B7 LINQ enumerate twice (and Random(42))"
  mkdir -p "$W/lq"; cp "$sol/b7-linq/"* "$W/lq/"
  SANDBOX_TIMEOUT=300 "$sbx" -e DOTNET_CLI_TELEMETRY_OPTOUT=1 -e DOTNET_NOLOGO=1 "$W/lq" dotnet run > "$W/b7.txt" 2>&1
  n() { awk -v s="($1)" 'index($0, "-- " s) == 1 {on=1; next} /^-- \(/ {on=0} on && /^effect/ {c++} END {print c+0}' "$W/b7.txt"; }
  if [[ $(n a) == 0 && $(n b) == 3 && $(n c) == 6 && $(n d) == 3 ]]; then ok "B7 effects: a=0 b=3 c=6 d=3"; else bad B7 "counts $(n a) $(n b) $(n c) $(n d)"; fi
  if grep -q '^16 11 11 15 11$' "$W/b7.txt"; then ok "B7 Random(42).Next(10,20) = 16 11 11 15 11"; else bad B7r "seed sequence differs"; fi
fi

if selected B8; then echo "B8 regex failure modes"
  d=$(copy src/regex-dotnet b8); mutate "$d/Program.cs" ')*");' ')*(?!)");'
  img "$d" "$W/b8a.txt"; if contains "$W/b8a.txt" "match returned: false" && contains "$W/b8a.txt" "total=0 entries=0"; then ok "B8 .NET (?!): false, zero captures"; else bad B8a "unexpected output"; fi
  expectnot "B8 ...entry's check.sh fails" sandbox/run.sh "$d"
  d=$(copy src/regex-pcre2grep b8b); mutate "$d/timecards.sh" '(?C{/usr/bin/sqlite3' '(?C{sqlite3'
  img "$d" "$W/b8b.txt"; expectnot "B8 pcre2grep relative path: no rows" "$chk" "$W/b8b.txt"
  if ! contains "$W/b8b.txt" "DEMO ONLY" && contains "$W/b8b.txt" "=== EXIT 0"; then ok "B8 ...and nothing says why (exit 0, no output)"; else bad B8b "it said something"; fi
fi

if selected B9; then echo "B9 sed trace"
  "$sbx" -e TRACE=1 src/regex-sed ./timecards.sh > "$W/b9.out" 2> "$W/b9.err"
  if (( $(grep -c 'tot:' "$W/b9.err") > 10 )) && grep -Eq 'tot:#{41}' "$W/b9.err"; then ok "B9 trace has state lines and a 41+ tally"; else bad B9 "trace shape unexpected"; fi
  if grep -q 'rng:1(01|1)' src/regex-sed/timecards.sed; then ok "B9 the reject rule is in timecards.sed"; else bad B9r "reject rule moved"; fi
fi

# rows_of FILE : count card rows in the first run's block (between "# DEMO ONLY" and "# committed")
rows_of() { awk '/^# DEMO ONLY/{go=1} go && /^# (committed|captured)/{exit} go' "$1" | grep -cE $'^(Meetings|Coding|Debugging|Learning)\t'; }

if selected B10; then echo "B10 Lisp method combination"
  d=$(copy src/lisp-weird b10); mutate "$d/timecards.lisp" '(:method-combination or)' '(:method-combination progn)'; mutate "$d/timecards.lisp" '(defmethod punch or ' '(defmethod punch progn '
  ok5=1; for i in 1 2 3 4 5; do img "$d" "$W/b10-$i.txt"; [[ $(rows_of "$W/b10-$i.txt") == 5 ]] && contains "$W/b10-$i.txt" "PUNCH had 0 OR methods and 5 ran" || ok5=0; done
  if (( ok5 )); then ok "B10 progn: exactly 5 cards on all 5 runs"; else bad B10a "not always 5 cards"; fi
  expectnot "B10 ...and the entry's own check.sh fails" sandbox/run.sh "$d"
  d=$(copy src/lisp-weird b10b); mutate "$d/timecards.lisp" '(:method-combination or)' '(:method-combination progn)'
  img "$d" "$W/b10b.txt"; if contains "$W/b10b.txt" "Invalid qualifiers for PROGN method combination"; then ok "B10 generic only: 'Invalid qualifiers for PROGN method combination'"; else bad B10b "warning not seen"; fi
  d=$(copy src/lisp-weird b10c); mutate "$d/timecards.lisp" '(> (total ledger) 40)' '(> (total ledger) 100)'
  ok5=1; for i in 1 2 3; do img "$d" "$W/b10c-$i.txt"; [[ $(rows_of "$W/b10c-$i.txt") == 5 ]] || ok5=0; msg=$("$chk" "$W/b10c-$i.txt" 100 2>&1); [[ $msg == *"does not pass 100"* ]] || ok5=0; done
  if (( ok5 )); then ok "B10 limit 100: always 5 cards, never passes 100"; else bad B10c "unexpected card count or total"; fi
fi

if selected B11; then echo "B11 m4 quoting"
  "$sbx" src/m4 m4 -Dtc_seed=12345 timecards.m4 > "$W/b11a.txt" 2>&1; "$sbx" src/m4 m4 -Dtc_seed=12345 timecards.m4 > "$W/b11b.txt" 2>&1
  ra=$(grep -E $'^(Meetings|Coding|Debugging|Learning)\t' "$W/b11a.txt"); rb=$(grep -E $'^(Meetings|Coding|Debugging|Learning)\t' "$W/b11b.txt")
  if [[ -n $ra && $ra == "$rb" ]] && [[ $(cut -f2,3 <<<"$ra" | tr '\n\t' ' ') == "19 19 13 32 16 48 " ]]; then ok "B11 seed 12345: identical rows 19/19 13/32 16/48"; else bad B11a "rows differ: $(tr '\n' ' ' <<<"$ra")"; fi
  d=$(copy src/m4 b11); mutate "$d/timecards.m4" '1, [], [tc_card()])' '1, [], tc_card())'
  SANDBOX_TIMEOUT=20 "$sbx" "$d" m4 timecards.m4 > "$W/b11c.txt" 2>&1; rc=$?
  if [[ $rc == 124 ]] && ! contains "$W/b11c.txt" "# committed"; then ok "B11 no brackets: runs until the timeout (exit 124), prints nothing"; else bad B11c "exit $rc"; fi
  "$sbx" "$d" m4 -L 50 -Dtc_seed=7 timecards.m4 > "$W/b11d.txt" 2>&1; rc=$?
  if [[ $rc != 0 ]] && contains "$W/b11d.txt" "recursion limit of 50 exceeded" && ! contains "$W/b11d.txt" "# committed"; then ok "B11 no brackets, -L 50: 'recursion limit of 50 exceeded', no commit"; else bad B11d "exit $rc"; fi
  d=$(copy src/m4 b11e); mutate "$d/timecards.m4" 'eval(tc_total > 40)' 'eval(tc_total > 60)'
  img "$d" "$W/b11e.txt"; expect "B11 '> 60' stops above 60" "$chk" "$W/b11e.txt" 60
fi

if selected B12; then echo "B12 Tcl SQLite program"
  d=$(copy src/tcl-weird b12); mutate "$d/timecards.tcl" 'PRAGMA recursive_triggers = ON;' 'PRAGMA recursive_triggers = OFF;'
  img "$d" "$W/b12a.txt"; if [[ $(rows_of "$W/b12a.txt") == 1 ]] && contains "$W/b12a.txt" "entries=2"; then ok "B12 recursion off: 1 card printed, summary counts 2"; else bad B12a "rows $(rows_of "$W/b12a.txt")"; fi
  expectnot "B12 ...and check-demo fails" "$chk" "$W/b12a.txt"
  d=$(copy src/tcl-weird b12b); mutate "$d/timecards.tcl" "'expr {10 + int(rand() * 10)}'" "'expr {10}'"
  ok5=1; for i in 1 2 3; do img "$d" "$W/b12b-$i.txt"; [[ $(rows_of "$W/b12b-$i.txt") == 5 ]] && contains "$W/b12b-$i.txt" "total=50 entries=5" && "$chk" "$W/b12b-$i.txt" >/dev/null || ok5=0; done
  if (( ok5 )); then ok "B12 hours row = expr {10}: always 5 cards, total 50, check-demo passes"; else bad B12b "not five tens"; fi
fi

if selected B13; then echo "B13 AWK RT"
  d=$(copy src/awk-weird b13); printf '1 2\n' > "$d/d.txt"
  "$sbx" "$d" gawk -f timecards.awk d.txt > "$W/b13a.txt" 2>&1
  if grep -qE $'^Meetings\t11\t11\t' "$W/b13a.txt" && grep -qE $'^Coding\t12\t23\t' "$W/b13a.txt" && contains "$W/b13a.txt" "total=23 entries=2"; then ok "B13 file '1 2': cards 11 and 12, total 23"; else bad B13a "$(tr '\n' ' ' < "$W/b13a.txt")"; fi
  "$sbx" "$d" mawk -f timecards.awk d.txt > "$W/b13c.txt" 2>&1
  if contains "$W/b13c.txt" "total=0 entries=0" && ! grep -qE $'^(Meetings|Coding)\t' "$W/b13c.txt"; then ok "B13 mawk on the file: no RT, so zero cards and no error"; else bad B13c "$(tr '\n' ' ' < "$W/b13c.txt")"; fi
  d=$(copy src/awk-weird b13b); printf '1 2\n' > "$d/d.txt"; mutate "$d/timecards.awk" 'RT == "" { next }' ''
  "$sbx" "$d" gawk -f timecards.awk d.txt > "$W/b13b.txt" 2>&1
  if grep -qE $'^Debugging\t10\t33\t' "$W/b13b.txt" && contains "$W/b13b.txt" "total=33 entries=3"; then ok "B13 no guard: a phantom 10-hour third card"; else bad B13b "$(tr '\n' ' ' < "$W/b13b.txt")"; fi
  d=$(copy src/awk-weird b13d); mutate "$d/timecards.awk" 't > 40 { exit }' 't > 80 { exit }'
  img "$d" "$W/b13d.txt"; expect "B13 't > 80' stops above 80" "$chk" "$W/b13d.txt" 80
fi

if selected B14; then echo "B14 find dice"
  d=$(copy src/find-posix b14); mkdir "$d/bin"
  for n in xxxxxS xxxxxY xxxxYZ; do
    printf '#!/bin/sh\nif [ "$#" -eq 2 ] && [ "$1" = -d ]; then d=${2%%XXXXXX}%s; mkdir "$d" && printf "%%s\\n" "$d"; else exec /usr/bin/mktemp "$@"; fi\n' "$n" > "$d/bin/mktemp"; chmod +x "$d/bin/mktemp"
    "$sbx" "$d" sh -c 'PATH=$PWD/bin:$PATH sh ./timecards.sh' > "$W/b14-$n.txt" 2>&1
  done
  if grep -qE $'^Meetings\t19\t19\t' "$W/b14-xxxxxS.txt" && grep -qE $'^Coding\t19\t38\t' "$W/b14-xxxxxS.txt" && grep -qE $'^Debugging\t19\t57\t' "$W/b14-xxxxxS.txt" && contains "$W/b14-xxxxxS.txt" "total=57 entries=3"; then ok "B14 xxxxxS: three cards of 19 hours"; else bad B14a "$(tr '\n' ' ' < "$W/b14-xxxxxS.txt")"; fi
  if grep -qE $'^Debugging\t13\t39\t' "$W/b14-xxxxxY.txt" && grep -qE $'^Learning\t13\t52\t' "$W/b14-xxxxxY.txt" && contains "$W/b14-xxxxxY.txt" "total=52 entries=4"; then ok "B14 xxxxxY: re-roll reads x, 13 hours, 39 continues to 52"; else bad B14b "$(tr '\n' ' ' < "$W/b14-xxxxxY.txt")"; fi
  if grep -qE $'^Learning\t10\t40\t' "$W/b14-xxxxYZ.txt" && grep -qE $'^Meetings\t10\t50\t' "$W/b14-xxxxYZ.txt" && contains "$W/b14-xxxxYZ.txt" "total=50 entries=5"; then ok "B14 xxxxYZ: ten hours, 40 continues, fifth card is Meetings"; else bad B14c "$(tr '\n' ' ' < "$W/b14-xxxxYZ.txt")"; fi
fi

if selected B15; then echo "B15 GNU find stop rule and profile"
  d=$(copy src/find-gnu b15); mutate "$d/timecards.sh" '{41}' '{31}'
  img "$d" "$W/b15.txt"; expect "B15 '{31}' stops above 30" "$chk" "$W/b15.txt" 30
  expectnot "B15 ...and the entry's own check.sh fails" sandbox/run.sh "$d"
  d=$(copy src/find-gnu b15b)
  "$sbx" -e FIND_D=rates "$d" sh ./timecards.sh > "$W/b15b.txt" 2>&1
  if contains "$W/b15b.txt" "real success rate" && contains "$W/b15b.txt" "est success rate"; then ok "B15 FIND_D=rates prints est and real success rates"; else bad B15b "no profile on stderr"; fi
fi

if selected B16; then echo "B16 tar: read the program, then run it"
  d=$(copy src/tar-gnu b16)
  "$sbx" "$d" sh -c '
    set -e
    sh build-archive.sh --seed 1 --hours "12 12 12 12 12" a.tar
    sh inspect.sh a.tar > /dev/null; sh interpret.sh --execute a.tar > step1.txt
    mkdir x; tar -C x -xf a.tar; printf "limit=20\n" > x/021.stop-over
    O="000.begin 010.card 011.stop-over 020.card 021.stop-over 030.card 031.stop-over 040.card 041.stop-over 050.card 051.stop-over 990.show"
    tar --format=ustar -cf b.tar -C x $O; rm "$TARPROG_DB" 2>/dev/null || true; rm -f "$XDG_DATA_HOME/TarGnu/demo-timecards.db"
    sh interpret.sh --execute b.tar > step2.txt
    sqlite3 "$XDG_DATA_HOME/TarGnu/demo-timecards.db" "select count(*) from trace where outcome like \"ignored%\"" > ignored.txt
    printf "touch pwned\n" > x/025.exec
    tar --format=ustar -cf c.tar -C x 000.begin 010.card 011.stop-over 020.card 021.stop-over 025.exec 030.card 031.stop-over 990.show
    set +e; sh inspect.sh c.tar > insp.txt; r1=$?; sh interpret.sh --execute c.tar > /dev/null 2> interp.err; r2=$?; set -e
    [ "$r1" = 4 ] && [ "$r2" = 4 ] && [ ! -e pwned ] && grep -q "REFUSE (unknown record type)" insp.txt
    mkdir plain; tar -C plain -xf c.tar; [ -f plain/025.exec ] && [ ! -e plain/pwned ] && [ ! -e pwned ]
    cat step1.txt; echo ---STEP2; cat step2.txt; echo ---IGN; cat ignored.txt' > "$W/b16.txt" 2>&1
  s1=${W}/b16-1.txt; sed -n '1,/^---STEP2/p' "$W/b16.txt" | grep -v '^---' > "$s1"
  sed -n '/^---STEP2/,/^---IGN/p' "$W/b16.txt" | grep -v '^---' > "$W/b16-2.txt"
  expect "B16 step 1: four cards pass check-demo" "$chk" "$s1"
  if grep -qE $'^Learning\t12\t48\t' "$s1" && contains "$s1" "total=48 entries=4"; then ok "B16 step 1: 12, 24, 36, 48"; else bad B16a "$(tr '\n' ' ' < "$s1")"; fi
  expect "B16 step 2: limit 20 in the archive stops after two cards" "$chk" "$W/b16-2.txt" 20
  if contains "$W/b16-2.txt" "total=24 entries=2" && tail -1 "$W/b16.txt" | grep -qx 3; then ok "B16 step 2: two cards, three slots ignored"; else bad B16b "$(tr '\n' ' ' < "$W/b16-2.txt") / $(tail -1 "$W/b16.txt")"; fi
  if grep -q '^---IGN' "$W/b16.txt"; then ok "B16 step 3: inspector and interpreter exit 4, no pwned, plain tar -xf inert"; else bad B16c "$(tail -3 "$W/b16.txt" | tr '\n' ' ')"; fi
fi

if selected B17; then echo "B17 tar weirder: predict the clock"
  d=$(copy src/tar-gnu-weird b17)
  "$sbx" "$d" sh -c '
    set +e
    sh run-clock.sh --seed 42 --ticks 45 > s45.txt 2> s45.err; echo $? > s45.rc
    rm -rf "$XDG_DATA_HOME/TarGnuWeird"
    sh run-clock.sh --seed 42 --ticks 46 > s46.txt 2>/dev/null; echo $? > s46.rc
    rm -rf "$XDG_DATA_HOME/TarGnuWeird"
    sh run-clock.sh --seed 42 --ticks 92 --interval 2 > i92.txt 2>/dev/null; echo $? > i92.rc
    sqlite3 "$XDG_DATA_HOME/TarGnuWeird/demo-timecards.db" "select tick from fsm" > i92.tick
    rm -rf "$XDG_DATA_HOME/TarGnuWeird"
    sh run-clock.sh --seed 42 --ticks 91 --interval 2 > i91.txt 2>/dev/null; echo $? > i91.rc
    rm -rf "$XDG_DATA_HOME/TarGnuWeird"
    sh run-clock.sh --seed 42 --ticks 260 --blocking 4 > b4.txt 2>/dev/null; echo $? > b4.rc
    echo "tape=$(wc -c < "$XDG_DATA_HOME/TarGnuWeird/tape.tar") idle=$(sqlite3 "$XDG_DATA_HOME/TarGnuWeird/demo-timecards.db" "select idle from fsm") nonzero=$(tr -d "\\000" < "$XDG_DATA_HOME/TarGnuWeird/tape.tar" | wc -c)" > b4.info
    for f in s45.rc s45.err s46.rc i92.rc i92.tick i91.rc b4.rc b4.info; do echo "== $f"; cat $f; done
    echo "== s45rows"; grep -c "^[A-Z][a-z]*	" s45.txt; echo "== s46rows"; grep -c "^[A-Z][a-z]*	" s46.txt' > "$W/b17.txt" 2>&1
  b=$(tr '\n' '|' < "$W/b17.txt")
  if [[ $b == *"== s45.rc|3|"* && $b == *"clock ran out"* && $b == *"== s45rows|2|"* ]]; then ok "B17 45 ticks: two cards, the clock ran out, exit 3"; else bad B17a "$b"; fi
  if [[ $b == *"== s46.rc|0|"* && $b == *"== s46rows|3|"* ]]; then ok "B17 46 ticks: three cards, exit 0"; else bad B17b "$b"; fi
  if [[ $b == *"== i92.rc|0|"* && $b == *"== i92.tick|92|"* && $b == *"== i91.rc|3|"* ]]; then ok "B17 --interval 2: 92 records finish (last TAR_CHECKPOINT 92), 91 stall"; else bad B17c "$b"; fi
  nz=$(sed -nE 's/.*nonzero=([0-9]+).*/\1/p' "$W/b17.txt")
  if [[ $b == *"== b4.rc|0|"* && $b == *"tape=133120 idle=19 nonzero="* && ${nz:-999} -lt 100 ]]; then ok "B17 -b 4: 65 ticks, 19 idle, a 133120-byte tape that is zeros but for one header"; else bad B17d "$b"; fi
fi

if selected B18; then echo "B18 ed: move the stop rule and break the cleanup"
  d=$(copy src/ed-weird b18)
  "$sbx" -e DICE="0 0 0 0 0" "$d" sh ./timecards.sh > "$W/b18a.txt" 2>&1
  "$sbx" -e DICE="9 9 9 9 9" "$d" sh ./timecards.sh > "$W/b18b.txt" 2>&1
  if grep -qE $'^Meetings\t10\t50\t' "$W/b18a.txt" && contains "$W/b18a.txt" "total=50 entries=5"; then ok "B18 ten-hour cards: five cards, 40 continues, 50 stops"; else bad B18a "$(tr '\n' ' ' < "$W/b18a.txt")"; fi
  if grep -qE $'^Debugging\t19\t57\t' "$W/b18b.txt" && contains "$W/b18b.txt" "total=57 entries=3"; then ok "B18 nineteen-hour cards: three cards, total 57"; else bad B18b "$(tr '\n' ' ' < "$W/b18b.txt")"; fi
  "$sbx" -e DICE="3 3 3 3 3" "$d" sh ./timecards.sh > "$W/b18c.txt" 2>&1
  contains "$W/b18c.txt" "total=52 entries=4" && ok "B18 before: 13 13 13 13 gives four cards" || bad B18c "$(tr '\n' ' ' < "$W/b18c.txt")"
  d=$(copy src/ed-weird b18d); mutate "$d/timecards.ed" 'x\{41,\}' 'x\{31,\}'
  "$sbx" -e DICE="3 3 3 3 3" "$d" sh ./timecards.sh > "$W/b18d.txt" 2>&1
  expect "B18 x{31,}: stops above 30" "$chk" "$W/b18d.txt" 30
  contains "$W/b18d.txt" "total=39 entries=3" && ok "B18 x{31,}: three cards, total 39" || bad B18d "$(tr '\n' ' ' < "$W/b18d.txt")"
  d=$(copy src/ed-weird b18e); mutate "$d/timecards.ed" $'g/^Dead /d\n' ''
  "$sbx" "$d" sh -c "printf '3\\n3\\n3\\n3\\n3\\n' > d.txt; ed -s d.txt < timecards.ed" > "$W/b18e.txt" 2>&1
  if grep -qx 'Dead 0 52' "$W/b18e.txt"; then ok "B18 without the cleanup: Dead 0 52 shows"; else bad B18e "$(tr '\n' ' ' < "$W/b18e.txt")"; fi
fi

if selected C1; then echo "C1 weird next to boring (measured)"
  for p in cobol haskell forth apl lisp tcl awk; do
    a=$(cat src/$p/timecards.* | grep -vcE '^\s*(#|\\|--|\*|⍝|;)'); b=$(cat src/$p-weird/timecards.* | grep -vcE '^\s*(#|\\|--|\*|⍝|;)')
    echo "     $p: $a code lines vs $p-weird: $b"
  done; ok "C1 pairs measurable"
fi

if selected C2; then echo "C2 rule check"
  c2=c2_run; src=src/forth-weird/timecards.fs
  expect "C2 passes on the real entry" "$c2" "$src"
  sed 's/^drop /begin drop /' "$src" > "$W/m1.fs";                expectnot "C2 mutation 1 (begin added)" "$c2" "$W/m1.fs"
  sed 's/^utime drop/variable v utime drop/' "$src" > "$W/m2.fs"; expectnot "C2 mutation 2 (variable added)" "$c2" "$W/m2.fs"
  sed 's/>in @/0/g' "$src" > "$W/m3.fs";                          expectnot "C2 mutation 3 (>in @ removed)" "$c2" "$W/m3.fs"
  cp "$src" "$W/m4.fs"; mutate "$W/m4.fs" '\ <== THE LOOP' '\ begin if until <== THE LOOP'
  expect "C2 banned words inside a comment do not trigger" "$c2" "$W/m4.fs"
fi

if selected C3; then echo "C3 a loop whose state is the input stream (awk)"
  for n in 1 3 10; do
    got=$(seq "$n" | "$sbx" src/regex-sed bash -c "awk '{ print ++c }'" 2>/dev/null | tail -1)
    if [[ $got == "$n" ]]; then ok "C3 N=$n counts to $n"; else bad "C3 N=$n" "got '$got'"; fi
  done
fi

if selected D; then echo "D port the challenge (awk reference answer)"
  expect "D check.sh passes in the sandbox" sandbox/run.sh lessons/solutions/awk-port
  img lessons/solutions/awk-port "$W/d.txt"; expect "D run-image output passes check-demo" "$chk" "$W/d.txt"
  d=$(copy lessons/solutions/awk-port dm); mutate "$d/timecards.awk" 'total <= 40 {' 'total <= 40 { for (i=0;i<1;i++) x=1'
  expectnot "D mutation: a for loop is caught" sandbox/run.sh "$d"
  d=$(copy lessons/solutions/awk-port dm2); mutate "$d/timecards.awk" 'hours = 10 + int(rand() * 10)' 'hours = 10'
  expectnot "D mutation: constant hours is caught" sandbox/run.sh "$d"
fi

if selected F; then echo "F prove a README claim (takeWhile drops the crossing card)"
  mkdir -p "$W/f"; cp "$sol/f-takewhile.hs" "$W/f/"
  "$sbx" "$W/f" runghc f-takewhile.hs > "$W/f.txt" 2>&1
  if grep -q 'takeWhile: \[15,26,38\]' "$W/f.txt" && grep -q 'span: \[15,26,38,49\]' "$W/f.txt"; then ok "F takeWhile drops 49, span keeps it"; else bad F "$(tr '\n' ' ' < "$W/f.txt")"; fi
  sed 's/takeWhile (<= 40)/takeWhile (<= 50)/' "$sol/f-takewhile.hs" > "$W/f/neg.hs"; "$sbx" "$W/f" runghc neg.hs > "$W/fn.txt" 2>&1
  if grep -q 'takeWhile: \[15,26,38,49\]' "$W/fn.txt"; then ok "F negative control: a higher limit changes the result"; else bad Fn "$(tr '\n' ' ' < "$W/fn.txt")"; fi
fi

echo; echo "== $pass passed, $failn failed"
(( failn == 0 )) || { printf 'failed: %s\n' "${failed[*]}"; exit 1; }
