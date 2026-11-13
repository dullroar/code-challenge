#!/usr/bin/env bash
# Checks the rules from plans/regex.md for the Perl track. Uses a throwaway data dir.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data

# 1. The host has no loop keywords (comment lines excluded).
if grep -v '^\s*#' timecards.pl | grep -Eqw 'for|foreach|while|until|goto'; then
    echo "FAIL: loop keyword found in timecards.pl"; exit 1
fi

# 2. Run it a bunch of times; every run must end in a false match with a sane committed record set.
for i in $(seq 1 25); do
    out=$(perl timecards.pl)
    grep -q '^match returned: false$' <<<"$out" || { echo "FAIL run $i: match did not return false"; echo "$out"; exit 1; }
    commit=$(grep '^# committed' <<<"$out")
    total=$(sed -E 's/.*total=([0-9]+).*/\1/' <<<"$commit")
    entries=$(sed -E 's/.*entries=([0-9]+).*/\1/' <<<"$commit")
    rows=$(grep -c 'DEMO ONLY$' <<<"$(grep -v '^#' <<<"$out")" || true)
    [[ $rows -eq $entries ]] || { echo "FAIL run $i: $rows rows but entries=$entries"; exit 1; }
    (( entries == 4 || total > 40 )) || { echo "FAIL run $i: stopped early at $total"; exit 1; }
    (( entries >= 3 )) || { echo "FAIL run $i: too few entries"; exit 1; }
    (( total <= 40 + 19 )) || { echo "FAIL run $i: overshot ($total)"; exit 1; }
    awk -F'\t' '/^(Meetings|Coding|Debugging|Learning)\t/ && ($2 < 10 || $2 > 19) { bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: hours out of 10-19"; exit 1; }
done
echo "OK: 25 runs, all returned false after committing a valid record set"
