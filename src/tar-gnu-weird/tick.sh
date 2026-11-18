#!/bin/sh
# What tar runs at every checkpoint. It applies one transition (tick.sql) and does nothing else.
# tar sets TAR_CHECKPOINT (1, 2, 3, ...) and ignores our exit status, so a failure here cannot stop the archive:
# it can only leave the machine where it was.
set -u
case ${TAR_CHECKPOINT-} in ''|*[!0-9]*) echo "tick: TAR_CHECKPOINT is not a number" >&2; exit 1 ;; esac
exec sqlite3 -bail -cmd ".parameter init" -cmd ".parameter set @t $TAR_CHECKPOINT" "${TICK_DB:?}" < "${TICK_SQL:?}"
