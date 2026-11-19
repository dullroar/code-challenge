#!/usr/bin/env bash
# Checks the rules of the regex challenge for the .NET track. Uses a throwaway data dir.
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
    (( total > 40 )) || { echo "FAIL run $i: stopped early at $total"; exit 1; }
    (( entries >= 3 && entries <= 5 )) || { echo "FAIL run $i: $entries entries; a run has 3 to 5"; exit 1; }
    (( total <= 40 + 19 )) || { echo "FAIL run $i: overshot ($total)"; exit 1; }
    awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ && ($2 < 10 || $2 > 19) { bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: hours out of 10-19"; exit 1; }
    # The stop rule: the total before the last card is 40 or less (exactly 40 continues), and the last card took it over 40.
    before_last=$(awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ { prev = s; s += $2 } END { print prev + 0 }' <<<"$out")
    (( before_last <= 40 )) || { echo "FAIL run $i: kept going after the total passed 40 (total before the last card = $before_last)"; exit 1; }
done

# 3. Exactly 40 continues. Four 10-hour cards total exactly 40, so a fifth card must be drawn: Meetings again, total 50.
#    A copy of the host with every card worth 10 hours makes that the only possible run.
mkdir "$data/fixed"; cp RegexDotnet.csproj "$data/fixed/"
sed "s/string Draw() => new('a', Random.Shared.Next(10, 20));/string Draw() => new('a', 10);/" Program.cs > "$data/fixed/Program.cs"
grep -q "new('a', 10)" "$data/fixed/Program.cs" || { echo "FAIL: the exactly-40 test could not rewrite Draw() in Program.cs"; exit 1; }
(cd "$data/fixed" && dotnet build -c Release -v q --nologo -o "$data/fixedbin" >/dev/null)
out=$(dotnet "$data/fixedbin/RegexDotnet.dll")
[[ $(grep -cE '^(Meetings|Coding|Debugging|Learning)	' <<<"$out") -eq 5 ]] || { echo "FAIL: all-10 cards must give five rows (exactly 40 continues)"; echo "$out"; exit 1; }
grep -q '^# captured total=50 entries=5' <<<"$out" || { echo "FAIL: expected total=50 entries=5"; echo "$out"; exit 1; }
mapfile -t rows < <(grep -E '^(Meetings|Coding|Debugging|Learning)	' <<<"$out")
[[ ${rows[3]} == Learning* && ${rows[4]} == Meetings* ]] || { echo "FAIL: the fourth card must be Learning and the fifth Meetings"; echo "$out"; exit 1; }

echo "OK: 25 runs, every one stopped exactly when the total passed 40; exactly 40 continued to a fifth card"
