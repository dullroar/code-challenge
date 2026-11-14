#!/usr/bin/env bash
# Runs an entry's check inside the Linux sandbox. The check is `make check` if the entry's
# Makefile has a check target (so it can build first), otherwise `bash check.sh`. It runs
# with no network, a read-only root filesystem, no capabilities, an unprivileged user,
# process/memory/CPU limits and a hard timeout.
#
#   sandbox/run.sh src/apl                 # one entry
#   sandbox/run.sh src/apl src/forth ...   # several
#
# The entry folder is mounted read-only and copied to a tmpfs inside the container, so the
# check can build and write freely without touching your checkout. Nothing persists after
# the container exits. In that private copy, CRLF line endings (a Windows checkout with
# core.autocrlf=true) are converted to LF so bash, make and the interpreters see what Linux
# checkouts see. Binary files are left alone.
#
# Environment:
#   SANDBOX_IMAGE    image tag to use/build      (default code-challenge-sandbox:local)
#   SANDBOX_TIMEOUT  seconds per entry           (default 900)
#   SANDBOX_BUILD    0 = never build the image   (default 1: build if it is missing)
#   DOCKER           docker CLI to use           (default docker)
#
# Works on Linux, macOS, WSL, and Git Bash on Windows with Docker Desktop.
# Exit status: 0 if every entry passed, 1 if any failed, 124 if any timed out, 2 on usage errors.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
image=${SANDBOX_IMAGE:-code-challenge-sandbox:local}
timeout_s=${SANDBOX_TIMEOUT:-900}
docker=${DOCKER:-docker}

[[ $# -ge 1 ]] || { echo "usage: $0 <entry-dir> [entry-dir ...]" >&2; exit 2; }
command -v "$docker" >/dev/null || { echo "run.sh: '$docker' not found" >&2; exit 2; }

# Git Bash: hand Docker Desktop Windows paths, and stop MSYS from rewriting container paths.
host_path() { if command -v cygpath >/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
export MSYS_NO_PATHCONV=1

if ! "$docker" image inspect "$image" >/dev/null 2>&1; then
    [[ ${SANDBOX_BUILD:-1} == 1 ]] || { echo "run.sh: image $image not found" >&2; exit 2; }
    echo "run.sh: building $image from $here/linux (first time takes a while)"
    "$docker" build -t "$image" "$(host_path "$here/linux")" || exit 2
fi

status=0
for entry in "$@"; do
    dir=$(cd "$entry" 2>/dev/null && pwd) || { echo "FAIL $entry: no such folder"; status=1; continue; }
    name=$(basename "$dir")
    if [[ ! -f $dir/check.sh ]]; then
        if [[ -f $dir/check.ps1 ]]; then echo "SKIP $name: Windows-only (check.ps1); use sandbox/windows/run.ps1"; continue; fi
        echo "FAIL $name: no check.sh (entries must ship one; see CONTRIBUTING.md)"; status=1; continue
    fi
    container="cc-sandbox-$name-$$"
    echo "=== $name"
    start=$SECONDS
    "$docker" run --rm --name "$container" \
        --network none \
        --read-only \
        --cap-drop ALL \
        --security-opt no-new-privileges \
        --user 65534:65534 \
        --pids-limit 256 \
        --memory 2g --memory-swap 2g \
        --cpus 2 \
        --tmpfs /tmp:rw,exec,nosuid,size=512m \
        --tmpfs /work:rw,exec,nosuid,size=2g,uid=65534,gid=65534 \
        -e HOME=/work/home \
        -v "$(host_path "$dir"):/entry:ro" \
        "$image" \
        bash -c 'mkdir -p "$HOME" && cp -r /entry /work/entry && cd /work/entry \
                 && { grep -rlI $'"'"'\r'"'"' . | xargs -r sed -i "s/\r$//"; } \
                 && if [ -f Makefile ] && grep -q "^check:" Makefile; then set -- "$1" make check; \
                    else set -- "$1" bash ./check.sh; fi \
                 && echo "+ $2 $3" && exec timeout -k 10 "$@"' _ "$timeout_s"
    rc=$?
    # If the CLI itself was interrupted, make sure the container is gone too.
    "$docker" rm -f "$container" >/dev/null 2>&1
    elapsed=$((SECONDS - start))
    case $rc in
        0)   echo "PASS $name (${elapsed}s)" ;;
        124) echo "TIMEOUT $name after ${elapsed}s (limit ${timeout_s}s)"; [[ $status == 1 ]] || status=124 ;;
        137) echo "KILLED $name after ${elapsed}s (timeout or memory limit)"; status=1 ;;
        *)   echo "FAIL $name (rc=$rc, ${elapsed}s)"; status=1 ;;
    esac
done
exit $status
