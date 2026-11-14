#!/usr/bin/env bash
# DEMO ONLY. Fictional timecards, written to a scratch SQLite file under XDG_DATA_HOME. See README.md.
#
# The program is timecards.sed. This script only writes a one-line "tape" (run id, ISO week, a 16-bit
# random seed, whether stdout is a terminal, and the TRACE flag) and runs ONE sed command against it.
# sed's stdout is the screen; sed's fd 3 is the SQL it generates, piped into sqlite3. No loop, no
# arithmetic, no decisions here: those are all regex matches inside timecards.sed.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
db=${XDG_DATA_HOME:-$HOME/.local/share}/RegexSed/demo-timecards.db
mkdir -p "$(dirname "$db")"
exec 4>&1
tty=$(set +e; tty -s <&4; echo $?)

set +e
printf 'run:%s wk:%s rng:%s tty:%s trace:%s\n' "$(date +%s)-$$" "$(date +%G-W%V)" \
    "$(head -c2 /dev/urandom | basenc --base2msbf)" "$tty" "${TRACE:-0}" |
    sed -nEu -f "$here/timecards.sed" 3>&1 1>&4 | sqlite3 "$db"
st=("${PIPESTATUS[@]}")

# sed exiting 1 is the point (the program "fails" after doing all the work); sqlite3 must succeed.
exit $(( st[1] == 1 && st[2] == 0 ? 0 : 3 ))
