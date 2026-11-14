#!/usr/bin/env bash
# Reference answer for exercise C2: a rule check for src/forth-weird, written from scratch.
#   c2-forth-rule-check.sh [PATH/TO/timecards.fs]
# The rule: no loop/branch words, no variables, and the parse position (>in @) is read at least twice.
f=${1:-$(dirname "$0")/../../src/forth-weird/timecards.fs}
# Strip what must not count: "\ ..." line comments, "( ... )" comments and ." ..." strings.
code=$(tr -d '\r' < "$f" | sed -E -e 's/(^|[[:space:]])[\]([[:space:]].*)?$//' -e 's/[(][^)]*[)]//g' -e 's/[.]"[^"]*"//g')
fail() { echo "FAIL: $*"; exit 1; }
if grep -Eiqw 'begin|until|while|repeat|again|if|then|else|do|loop|case|of|recurse|exit|leave' <<<"$code"; then
  fail "banned control word: $(grep -Eiow 'begin|until|while|repeat|again|if|then|else|do|loop|case|of|recurse|exit|leave' <<<"$code" | sort -u | tr '\n' ' ')"; fi
grep -Eiqw 'variable|buffer:' <<<"$code" && fail "a variable is declared"
n=$(grep -o '>in @' <<<"$code" | wc -l)
(( n >= 2 )) || fail ">in @ appears $n time(s); the loop needs the anchor and the jump (>= 2)"
echo "OK: no control words, no variables, >in @ x$n"
