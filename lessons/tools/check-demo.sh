#!/usr/bin/env bash
# Validates the shape of any code-challenge entry's output.
#
#   check-demo.sh OUTPUT_FILE [LIMIT]       LIMIT defaults to 40
#
# OUTPUT_FILE is what the entry printed (run-image.sh output is fine: only the rows and the
# "# committed" line are read). Checks: a DEMO ONLY marker, every row's hours are 10-19, every
# running total is the previous total plus the hours, the run stopped on the first card whose
# total passed LIMIT, and the "# committed total=N entries=M" line agrees with the rows.
# Exit 0 = PASS, 1 = FAIL (with the reason).
f=${1:?usage: check-demo.sh OUTPUT_FILE [LIMIT]}; limit=${2:-40}
fail() { echo "FAIL: $*"; exit 1; }
tr -d '\r' < "$f" > "${TMPDIR:-/tmp}/check-demo.$$" || exit 2; f2=${TMPDIR:-/tmp}/check-demo.$$; trap 'rm -f "$f2"' EXIT
grep -q 'DEMO ONLY' "$f2" || fail "no DEMO ONLY marker"
# Only the first run's block: rows between the "# DEMO ONLY" line and the "# committed"/"# captured" line.
# Rows are  Category<TAB>hours<TAB>total<TAB>week...  (regex-dotnet and regex-pcre2 omit the total column).
mapfile -t rows < <(awk '/^# DEMO ONLY/{go=1} go && /^# (committed|captured)/{exit} go' "$f2" \
                    | grep -E $'^(Meetings|Coding|Debugging|Learning)\t[0-9]+(\t|$)')
(( ${#rows[@]} >= 1 )) || fail "no timecard rows found"
prev=0; before_last=0
for r in "${rows[@]}"; do
  IFS=$'\t' read -r cat hrs tot _ <<<"$r"
  (( hrs >= 10 && hrs <= 19 )) || fail "hours not in 10-19: $r"
  if [[ $tot =~ ^[0-9]+$ ]]; then (( tot == prev + hrs )) || fail "running total wrong: $r"; else tot=$(( prev + hrs )); fi
  before_last=$prev; prev=$tot
done
(( prev > limit ))         || fail "final total $prev does not pass $limit"
(( before_last <= limit )) || fail "stopped late: total was already $before_last (over $limit) before the last card"
c=$(sed -nE 's/^# (committed|captured) total=([0-9]+) entries=([0-9]+).*/\2 \3/p' "$f2" | head -1)
[[ $c == "$prev ${#rows[@]}" ]] || fail "summary line ('$c') disagrees with the rows ('$prev ${#rows[@]}')"
echo "PASS: ${#rows[@]} rows, total $prev (limit $limit)"
