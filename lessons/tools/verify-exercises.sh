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
chk=$here/check-demo.sh; sbx=$here/run-in-sandbox.sh; sol=$here/../solutions
pass=0; failn=0; failed=()
want=("$@")
selected() { [[ ${#want[@]} -eq 0 ]] && return 0; local w; for w in "${want[@]}"; do [[ $1 == $w* ]] && return 0; done; return 1; }
ok()  { echo "  PASS  $1"; pass=$((pass+1)); }
bad() { echo "  FAIL  $1: $2"; failn=$((failn+1)); failed+=("$1"); }
# expect LABEL COMMAND...  (must succeed)      expectnot LABEL COMMAND...  (must fail)
expect()    { local l=$1; shift; if "$@" >"$W/last" 2>&1; then ok "$l"; else bad "$l" "$(tail -2 "$W/last" | tr '\n' ' ')"; fi; }
expectnot() { local l=$1; shift; if "$@" >"$W/last" 2>&1; then bad "$l" "expected a failure but it passed"; else ok "$l"; fi; }
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
  SANDBOX_TIMEOUT=40 img "$d" "$W/b6a.txt"; if contains "$W/b6a.txt" "TIMEOUT"; then ok "B6 4-down: runs forever (TIMEOUT)"; else bad B6a "no timeout"; fi
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

if selected C1; then echo "C1 weird next to boring (measured)"
  for p in cobol haskell forth apl; do
    a=$(cat src/$p/timecards.* | grep -vcE '^\s*(#|\\|--|\*|⍝)'); b=$(cat src/$p-weird/timecards.* | grep -vcE '^\s*(#|\\|--|\*|⍝)')
    echo "     $p: $a code lines vs $p-weird: $b"
  done; ok "C1 pairs measurable"
fi

if selected C2; then echo "C2 rule check"
  c2=$sol/c2-forth-rule-check.sh; src=src/forth-weird/timecards.fs
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
