#!/usr/bin/env bash
# Builds an entry's own image from src/<entry>/Dockerfile and runs it to SHOW OFF the result:
# the entry's output, then a read-only look at every file and SQLite table it wrote.
#
#   sandbox/container/run-image.sh src/forth
#   sandbox/container/run-image.sh --out ./results src/haskell     # also copy what it wrote to ./results
#   sandbox/container/run-image.sh --tty src/regex-sed             # give it a terminal (animations)
#   sandbox/container/run-image.sh --online-build src/GoChallenge1  # allow network for the BUILD only
#
# The build runs with NO network (docker build --network none) and may only start FROM the
# trusted bases built by build-bases.sh. Entries that must download dependencies while building
# (the Go entry) need --online-build; use that only on entries already merged to master.
# The run is the same lockdown as run.sh: no network, read-only root, no capabilities,
# user nobody, limits, a timeout. Host files are reachable only through the opt-in --out folder.
#
# Environment: DOCKER (CLI), SANDBOX_TIMEOUT (seconds, default 300).
# Exit status: the entry's, 124 on timeout, 2 on usage or build errors.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
docker=${DOCKER:-docker}
timeout_s=${SANDBOX_TIMEOUT:-300}
out= tty=() netflag=(--network none)
while [[ ${1:-} == --* ]]; do
    case $1 in
        --out) out=${2:?--out needs a folder}; shift 2 ;;
        --tty) tty=(-t); shift ;;
        --online-build) netflag=(); shift ;;
        *) echo "unknown option $1" >&2; exit 2 ;;
    esac
done
[[ $# -eq 1 ]] || { echo "usage: $0 [--out DIR] [--tty] [--online-build] <entry-dir>" >&2; exit 2; }
command -v "$docker" >/dev/null || { echo "run-image.sh: '$docker' not found (see SANDBOX-SETUP.md)" >&2; exit 2; }
host_path() { if command -v cygpath >/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
export MSYS_NO_PATHCONV=1

dir=$(cd "$1" 2>/dev/null && pwd) || { echo "no such folder: $1" >&2; exit 2; }
name=$(basename "$dir"); name=${name,,}
[[ -f $dir/Dockerfile ]] || { echo "$name has no Dockerfile (no container image for this entry yet)" >&2; exit 2; }
"$here/../dockerfile-lint.sh" "$dir/Dockerfile" || { echo "run-image.sh: Dockerfile rejected by dockerfile-lint.sh" >&2; exit 2; }

# The trusted bases must exist (building them needs network; that is build-bases.sh's job).
need=$(grep -iE '^FROM ' "$dir/Dockerfile" | awk '{print $2}' | grep -E '^(code-challenge-sandbox|cc-(rt|build)-.*):local$' | sort -u)
for img in $need; do
    $docker image inspect "$img" >/dev/null 2>&1 || { echo "missing $img: run sandbox/container/build-bases.sh first" >&2; exit 2; }
done

# Build from a private copy: no bin/obj/data leftovers, and CRLF line endings (a Windows checkout with
# core.autocrlf=true) converted to LF, as sandbox/run.sh does, so shell scripts see what Linux checkouts see.
stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp -r "$dir/." "$stage/"
rm -rf "$stage"/{bin,obj,data,.vs,.git}
{ grep -rlI $'' "$stage" | xargs -r sed -i 's/$//'; } 2>/dev/null

image=cc-entry-$name:local
echo "=== building $image (network: ${netflag[*]:-ALLOWED for this build})"
$docker build "${netflag[@]}" -t "$image" "$(host_path "$stage")" || { echo "build failed" >&2; exit 2; }
echo "image size: $($docker image inspect "$image" --format '{{.Size}}' | awk '{printf "%.0f MB\n", $1/1048576}')"

mount=()
if [[ -n $out ]]; then mkdir -p "$out"; mount=(-v "$(host_path "$(cd "$out" && pwd)"):/out"); fi
container=cc-entry-$name-$$
timeout -k 10 "$timeout_s" "$docker" run --rm --name "$container" "${tty[@]}" \
    --network none \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --user 65534:65534 \
    --pids-limit 256 \
    --memory 2g --memory-swap 2g \
    --cpus 2 \
    --tmpfs /tmp:rw,exec,nosuid,size=256m \
    --tmpfs /work:rw,exec,nosuid,size=512m,uid=65534,gid=65534 \
    "${mount[@]}" \
    "$image"
rc=$?
$docker rm -f "$container" >/dev/null 2>&1
(( rc == 124 )) && echo "TIMEOUT after ${timeout_s}s"
exit $rc
