#!/bin/sh
# The demo: write the program as a tar archive, show it three ways, then run it.
#   SEED=123 sh timecards.sh     replay one exact program
set -eu
here=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}/TarGnu
mkdir -p "$data"
ar=$data/program.tar
if [ -n "${SEED:-}" ]; then sh "$here/build-archive.sh" --seed "$SEED" "$ar"; else sh "$here/build-archive.sh" "$ar"; fi
echo "# DEMO ONLY: $ar is a plain tar archive. tar lists it:"
tar -tvf "$ar" --numeric-owner
echo
sh "$here/inspect.sh" "$ar"
echo
sh "$here/interpret.sh" --execute "$ar"
