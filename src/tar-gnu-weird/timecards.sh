#!/bin/sh
# The demo: let a tar archive's checkpoints be the clock. SEED=42 sh timecards.sh replays one exact run.
exec sh "$(dirname "$0")/run-clock.sh" ${SEED:+--seed "$SEED"}
