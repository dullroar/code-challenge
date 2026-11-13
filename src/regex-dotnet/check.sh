#!/usr/bin/env bash
# Checks the rules from plans/regex.md for the .NET track. Uses a throwaway data dir.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data

# 1. The host has no loop keywords and no MatchEvaluator / Replace escape hatch (comment lines excluded).
code=$(grep -Ev '^\s*//' Program.cs)
if grep -Eqw 'for|foreach|while|do|until|goto' <<<"$code"; then
    echo "FAIL: loop keyword found in Program.cs"; exit 1
fi
if grep -Eq 'MatchEvaluator|Regex\.Replace|\.Replace\(|NextMatch|Matches\(' <<<"$code"; then
    echo "FAIL: callback/iteration escape hatch found in Program.cs"; exit 1
fi
[[ $(grep -c 'Regex\.Match(' <<<"$code") -eq 1 ]] || { echo "FAIL: expected exactly one Regex.Match call"; exit 1; }

dotnet build -c Release -v q --nologo -o "$data/bin" >/dev/null

# 2. Run it a bunch of times; every run must produce a sane, internally consistent record set.
for i in $(seq 1 25); do
    out=$(dotnet "$data/bin/RegexDotnet.dll")
    grep -q '^match returned: true$' <<<"$out" || { echo "FAIL run $i: match did not succeed"; echo "$out"; exit 1; }
    commit=$(grep '^# captured' <<<"$out")
    total=$(sed -E 's/.*total=([0-9]+).*/\1/' <<<"$commit")
    entries=$(sed -E 's/.*entries=([0-9]+).*/\1/' <<<"$commit")
    rows=$(grep -cE '^(Meetings|Coding|Debugging|Learning)	' <<<"$out" || true)
    [[ $rows -eq $entries ]] || { echo "FAIL run $i: $rows rows but entries=$entries"; exit 1; }
    sum=$(awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ { s += $2 } END { print s + 0 }' <<<"$out")
    (( sum == total )) || { echo "FAIL run $i: hours sum to $sum but total=$total"; exit 1; }
    (( entries == 4 || total > 40 )) || { echo "FAIL run $i: stopped early at $total"; exit 1; }
    (( entries >= 3 )) || { echo "FAIL run $i: too few entries"; exit 1; }
    (( total <= 40 + 19 )) || { echo "FAIL run $i: overshot ($total)"; exit 1; }
    awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ && ($2 < 10 || $2 > 19) { bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: hours out of 10-19"; exit 1; }
    # An entry list that stopped at 3 must have exceeded 40 by the third; one that did 4 must not have before the fourth.
    first3=$(awk -F'\t' '/^(Meetings|Coding|Debugging)\t/ { s += $2 } END { print s + 0 }' <<<"$out")
    (( entries == 3 && first3 > 40 || entries == 4 && first3 <= 40 )) || { echo "FAIL run $i: stop rule wrong (first three = $first3, entries = $entries)"; exit 1; }
done
echo "OK: 25 runs, every one stopped exactly when the total passed 40 (or after the fourth category)"
