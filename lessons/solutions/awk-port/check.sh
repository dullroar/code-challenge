#!/usr/bin/env bash
# Rules check for the awk port, in the style of the repo's entry check.sh files (run it with
# sandbox/run.sh lessons/solutions/awk-port). Static rules first, then 25 runs.
set -euo pipefail
cd "$(dirname "$0")"
grep -q 'DEMO ONLY' timecards.awk || { echo "FAIL: no DEMO ONLY marker"; exit 1; }
code=$(grep -v '^[[:space:]]*#' timecards.awk | sed -E 's/"[^"]*"//g')   # no comments, no string literals
if grep -Eqw 'for|while|do|function|func|goto' <<<"$code"; then
  echo "FAIL: loop or function keyword in timecards.awk"; grep -Enw 'for|while|do|function|func|goto' <<<"$code"; exit 1; fi
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT; export XDG_DATA_HOME=$data
distinct=$(mktemp)
for i in $(seq 25); do
  out=$(seq 5 | awk -f timecards.awk)
  rows=$(grep -cE $'^(Meetings|Coding|Debugging|Learning)\t' <<<"$out")
  total=$(sed -nE 's/^# committed total=([0-9]+) entries=([0-9]+).*/\1/p' <<<"$out")
  entries=$(sed -nE 's/^# committed total=([0-9]+) entries=([0-9]+).*/\2/p' <<<"$out")
  [[ $rows -eq $entries && $total -gt 40 ]] || { echo "FAIL run $i: rows=$rows entries=$entries total=$total"; exit 1; }
  grep -E $'^(Meetings|Coding|Debugging|Learning)\t' <<<"$out" | cut -f2 >> "$distinct"
  db=$data/Awk/demo-timecards.db
  [[ $(sqlite3 "$db" "select count(*) from demo_timecards") -ge $rows ]] || { echo "FAIL run $i: db rows missing"; exit 1; }
done
[[ $(sort -u "$distinct" | wc -l) -ge 5 ]] || { echo "FAIL: fewer than 5 distinct hour values in 25 runs"; exit 1; }
if sqlite3 "$data/Awk/demo-timecards.db" "insert into demo_timecards(run_id,category,hours,running_total,iso_week,created_at,demo_only) values('x','Coding',10,10,'w','t',0)" 2>/dev/null; then
  echo "FAIL: a non-demo row was accepted"; exit 1; fi
echo "OK: 25 runs, stop rule is the pattern, DEMO ONLY enforced by the schema"
