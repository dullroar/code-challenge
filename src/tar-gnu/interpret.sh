#!/bin/sh
# The executing interpreter: the one place where tar's --to-command is switched on.
#
#   sh interpret.sh --execute ARCHIVE
#
# It must be asked twice (the flag AND the archive): reading an archive and running it are different acts.
# First the passive inspector vets the whole archive. Only a clean verdict reaches tar. Then tar traverses
# the members in order and hands each regular member to dispatch.sh. Nothing is extracted to disk.
set -u
here=$(cd "$(dirname "$0")" && pwd)
[ "${1:-}" = --execute ] && [ $# -eq 2 ] || { echo "usage: interpret.sh --execute ARCHIVE   (this RUNS the archive; use inspect.sh to just read it)" >&2; exit 2; }
ar=$2
data=${XDG_DATA_HOME:-$HOME/.local/share}/TarGnu
mkdir -p "$data"
export TARPROG_DB=${TARPROG_DB:-$data/demo-timecards.db}
sh "$here/inspect.sh" "$ar" > /dev/null || { echo "interpret: the inspector found records it would refuse; nothing was run" >&2; exit 4; }
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
echo "# EXECUTING $ar: tar --to-command=dispatch.sh (the operator's choice, not the archive's)"
tar -C "$scratch" --to-command="sh $here/dispatch.sh" -xf "$ar"
