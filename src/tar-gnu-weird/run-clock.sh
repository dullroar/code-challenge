#!/bin/sh
# Starts the machine and lets tar's checkpoints drive it.
#   sh run-clock.sh [--seed N] [--ticks N] [--members M] [--interval K] [--blocking B]
# --ticks and --members describe the LAYOUT of the archive. --interval and --blocking are tar's CHECKPOINT
# settings (tar --checkpoint=K -b B). Defaults: a 64-record archive, one checkpoint per record, which gives 64 ticks.
# 64 is more than the longest possible run needs: a run ends by tick 59 at the latest.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
seed= ticks=64 members=1 interval=1 blocking=1
while [ $# -gt 0 ]; do
    case $1 in
        --seed) seed=$2 ;; --ticks) ticks=$2 ;; --members) members=$2 ;; --interval) interval=$2 ;; --blocking) blocking=$2 ;;
        *) echo "usage: run-clock.sh [--seed N] [--ticks N] [--members M] [--interval K] [--blocking B]" >&2; exit 2 ;;
    esac; shift 2
done
[ -n "$seed" ] || seed=$(( $(od -An -N4 -tu4 /dev/urandom | tr -d ' ') % 2147483646 + 1 ))
case $seed$interval$blocking in *[!0-9]*|'') echo "seed, interval and blocking must be whole numbers" >&2; exit 2 ;; esac
data=${XDG_DATA_HOME:-$HOME/.local/share}/TarGnuWeird; mkdir -p "$data"
export TICK_DB=${TICK_DB:-$data/demo-timecards.db} TICK_SQL=$here/tick.sql
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
sh "$here/layout.sh" --ticks "$ticks" --members "$members" "$scratch/payload"

run=$(sqlite3 -cmd ".parameter init" -cmd ".parameter set @seed $seed" -cmd ".parameter set @week '$(date +%G-W%V)'" "$TICK_DB" < "$here/machine.sql" | tail -1)
echo "# DEMO ONLY run $run: seed $seed; layout $ticks records in $members member(s); tar -b $blocking --checkpoint=$interval"
# The clock. tar reads nothing it was not told to read, runs one fixed command per checkpoint, and writes the tape under $data.
tar --format=ustar -b "$blocking" --checkpoint="$interval" --checkpoint-action="exec=sh $here/tick.sh" \
    -cf "$data/tape.tar" -C "$scratch/payload" -T "$scratch/payload/list"

q() { sqlite3 -separator '	' "$TICK_DB" "$@"; }
q "select category, hours, running_total, week, 'DEMO ONLY' from demo_timecards where run_id = $run order by rowid"
echo "# committed total=$(q "select coalesce(max(running_total),0) from demo_timecards where run_id=$run") entries=$(q "select count(*) from demo_timecards where run_id=$run") DEMO ONLY"
echo "# clock: last tick $(q "select tick from fsm where run_id=$run"), idle ticks after the stop $(q "select idle from fsm where run_id=$run"), tape $(wc -c < "$data/tape.tar") bytes"
if [ "$(q "select done from fsm where run_id=$run")" != 1 ]; then
    echo "# the clock ran out: the archive had too few records to finish the run (total $(q "select total from fsm where run_id=$run") hours, open card $(q "select worked from fsm where run_id=$run")/$(q "select target from fsm where run_id=$run"))" >&2
    exit 3
fi
