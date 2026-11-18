#!/bin/sh
# The launcher. It does four small jobs and no computing; every card, total and stop decision is made by ed.
#   1. dice:  five random digits, one per line, become ed's starting buffer (DICE="7 3 9 0 5" forces them)
#   2. run:   ed reads timecards.ed on stdin, edits the buffer, and prints the rows ("Meetings 17 17")
#   3. load:  sqlite3 stores the rows, with the week, DEMO ONLY and the CHECK constraints
#   4. show:  sqlite3 prints them
set -eu
here=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}/EdWeird; mkdir -p "$data"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
if [ -n "${DICE:-}" ]; then printf '%s\n' $DICE > "$scratch/dice.txt"; else { tr -dc '0-9' < /dev/urandom | head -c 5 | fold -w 1; echo; } > "$scratch/dice.txt"; fi
[ "$(grep -cx '[0-9]' "$scratch/dice.txt")" -eq 5 ] || { echo "timecards: need exactly five digits" >&2; exit 2; }
ed -s "$scratch/dice.txt" < "${ED_PROGRAM:-$here/timecards.ed}" > "$scratch/rows.txt" 2> "$scratch/ed.err" || { cat "$scratch/ed.err" >&2; echo "timecards: ed failed" >&2; exit 1; }
[ ! -s "$scratch/ed.err" ] || { cat "$scratch/ed.err" >&2; exit 1; }
db=${ED_DB:-$data/demo-timecards.db}
run=$(sqlite3 "$db" "
  create table if not exists runs(id integer primary key, dice text not null, demo_only integer not null default 1 check (demo_only = 1));
  create table if not exists demo_timecards(run_id integer not null, category text not null check (category in ('Meetings','Coding','Debugging','Learning')),
      hours integer not null check (hours between 10 and 19), running_total integer not null, week text not null, demo_only integer not null check (demo_only = 1));
  insert into runs(dice) values ('$(tr -d '\n' < "$scratch/dice.txt")');
  select max(id) from runs;")
sqlite3 "$db" ".separator ' '" "create temp table stage(category, hours, total);" ".import $scratch/rows.txt stage" \
    "insert into demo_timecards select $run, category, hours, total, '$(date +%G-W%V)', 1 from stage order by rowid;"
echo "# DEMO ONLY run $run"
sqlite3 -separator '	' "$db" "select category, hours, running_total, week, 'DEMO ONLY' from demo_timecards where run_id = $run order by rowid;"
echo "# committed total=$(sqlite3 "$db" "select max(running_total) from demo_timecards where run_id = $run") entries=$(sqlite3 "$db" "select count(*) from demo_timecards where run_id = $run") DEMO ONLY"
