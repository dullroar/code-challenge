#!/usr/bin/env bash
# Checks the rules from plans/regex.md for the PCRE2 track. Uses a throwaway data dir.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export XDG_DATA_HOME=$data
exe=${1:-./timecards}

# 1. The host has no loop keywords (comment lines excluded).
if grep -Ev '^\s*(/?\*|//)' timecards.c | grep -Eqw 'for|while|do|goto'; then
    echo "FAIL: loop keyword found in timecards.c"; exit 1
fi

# 2. Run it a bunch of times; every run must end in NOMATCH with a sane committed record set.
for i in $(seq 1 25); do
    out=$("$exe") || { echo "FAIL run $i: nonzero exit"; echo "$out"; exit 1; }
    grep -q '^pcre2_match returned -1 (no match)$' <<<"$out" || { echo "FAIL run $i: not NOMATCH"; echo "$out"; exit 1; }
    commit=$(grep '^# committed' <<<"$out")
    total=$(sed -E 's/.*total=([0-9]+).*/\1/' <<<"$commit")
    entries=$(sed -E 's/.*entries=([0-9]+).*/\1/' <<<"$commit")
    rows=$(grep -cE '^(Meetings|Coding|Debugging|Learning)	' <<<"$out" || true)
    [[ $rows -eq $entries ]] || { echo "FAIL run $i: $rows rows but entries=$entries"; exit 1; }
    (( entries == 4 || total > 40 )) || { echo "FAIL run $i: stopped early at $total"; exit 1; }
    (( entries >= 3 )) || { echo "FAIL run $i: too few entries"; exit 1; }
    (( total <= 40 + 19 )) || { echo "FAIL run $i: overshot ($total)"; exit 1; }
    awk -F'\t' '!/^#/ && NF == 4 && ($2 < 10 || $2 > 19) { bad = 1 } END { exit bad }' <<<"$out" || { echo "FAIL run $i: hours out of 10-19"; exit 1; }
    sleep 0.05
done
echo "OK: 25 runs, all returned no-match after committing a valid record set"
