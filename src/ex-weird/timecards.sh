#!/bin/sh
# The launcher. Four small jobs and no computing; every card, total and stop decision is made by Ex.
#   1. dice:  five random digits, one per line, become the editor's starting buffer (DICE="7 3 9 0 5" forces them)
#   2. run:   an Ex implementation reads timecards.ex on stdin and prints the rows ("Meetings 17 17")
#   3. load:  sqlite3 stores the rows, with the week, DEMO ONLY and the CHECK constraints
#   4. show:  sqlite3 prints them
# EX picks the editor. By default it is `ex`: nvi (a 4.4BSD POSIX ex, the one in the sandbox) or Vim in Ex mode.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}/ExWeird; mkdir -p "$data"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
if [ -n "${DICE:-}" ]; then printf '%s\n' $DICE > "$scratch/dice.txt"; else { tr -dc '0-9' < /dev/urandom | head -c 5 | fold -w 1; echo; } > "$scratch/dice.txt"; fi
[ "$(grep -cx '[0-9]' "$scratch/dice.txt")" -eq 5 ] || { echo "timecards: need exactly five digits" >&2; exit 2; }

ex=${EX:-ex}
case $("$ex" --version < /dev/null 2>&1 | head -n 1) in
    *VIM*) flags="-s -u NONE -N" ;;      # Vim in Ex mode: batch (-s), no vimrc, not vi-compatible
    *) flags="-s"; export TERM=dumb ;;   # nvi: batch; TERM=dumb stops it from complaining about the terminal
esac
# nvi writes its messages to standard output, so everything it prints is checked below.
# shellcheck disable=SC2086
"$ex" $flags "$scratch/dice.txt" < "${EX_PROGRAM:-$here/timecards.ex}" > "$scratch/out.txt" 2> "$scratch/ex.err" || { cat "$scratch/out.txt" "$scratch/ex.err" >&2; echo "timecards: ex failed" >&2; exit 1; }
[ ! -s "$scratch/ex.err" ] || { cat "$scratch/ex.err" >&2; exit 1; }
# One known nvi note, when it has no terminal. Anything else that is not a row is an error.
grep -vx 'Error: stderr: Inappropriate ioctl for device' "$scratch/out.txt" > "$scratch/rows.txt" || true
if grep -vqxE '(Meetings|Coding|Debugging|Learning) [0-9]+ [0-9]+' "$scratch/rows.txt"; then cat "$scratch/out.txt" >&2; echo "timecards: ex printed something that is not a row" >&2; exit 1; fi

db=${EX_DB:-$data/demo-timecards.db}
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
