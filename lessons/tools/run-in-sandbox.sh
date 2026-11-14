#!/usr/bin/env bash
# Runs a command inside the repo's locked-down toolchain container, on a private copy of a folder.
# Use it when an exercise needs an environment variable or a command that run-image.sh does not offer.
#
#   run-in-sandbox.sh [-e NAME=VALUE]... FOLDER COMMAND...
#
#   lessons/tools/run-in-sandbox.sh -e TRACE=1 src/regex-sed ./timecards.sh
#   lessons/tools/run-in-sandbox.sh src/make-gnu make NOW=1700000000
#
# FOLDER is mounted read-only and copied to a tmpfs, CRLF line endings are converted (as in
# sandbox/run.sh), and the command runs there with no network, a read-only root, no capabilities,
# user nobody, resource limits and a timeout (SANDBOX_TIMEOUT seconds, default 120).
# Needs the toolchain image: sandbox/container/build-bases.sh.
set -uo pipefail
docker=${DOCKER:-docker}; image=${SANDBOX_IMAGE:-code-challenge-sandbox:local}
envs=()
while [[ ${1:-} == -e ]]; do envs+=(-e "${2:?-e needs NAME=VALUE}"); shift 2; done
[[ $# -ge 2 ]] || { echo "usage: $0 [-e NAME=VALUE]... FOLDER COMMAND..." >&2; exit 2; }
dir=$(cd "$1" 2>/dev/null && pwd) || { echo "no such folder: $1" >&2; exit 2; }; shift
host_path() { if command -v cygpath >/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
export MSYS_NO_PATHCONV=1
exec "$docker" run --rm -i --network none --read-only --cap-drop ALL --security-opt no-new-privileges \
    --user 65534:65534 --pids-limit 256 --memory 2g --memory-swap 2g --cpus 2 \
    --tmpfs /tmp:rw,exec,nosuid,size=512m --tmpfs /work:rw,exec,nosuid,size=1g,uid=65534,gid=65534 \
    -e HOME=/work/home -e XDG_DATA_HOME=/work/xdg "${envs[@]}" \
    -v "$(host_path "$dir"):/entry:ro" "$image" \
    bash -c 'mkdir -p "$HOME" "$XDG_DATA_HOME" && cp -r /entry /work/entry && cd /work/entry \
             && { grep -rlI $'"'"'\r'"'"' . | xargs -r sed -i "s/\r$//"; } ; exec timeout -k 5 "$@"' _ "${SANDBOX_TIMEOUT:-120}" "$@"
