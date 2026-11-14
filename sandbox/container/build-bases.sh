#!/usr/bin/env bash
# Builds (or rebuilds) the trusted images the per-entry Dockerfiles start from:
#   code-challenge-sandbox:local   the build toolchain (sandbox/linux/Dockerfile); build stages only
#   cc-rt-<name>:local             the minimal runtime bases (sandbox/container/Dockerfile)
# Needs network (apt, and the toolchain's pinned downloads). Run it yourself, from master.
#
#   sandbox/container/build-bases.sh            # whichever are missing
#   sandbox/container/build-bases.sh --force    # rebuild all
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
docker=${DOCKER:-docker}
force=0; [[ ${1:-} == --force ]] && { force=1; shift; }
only=" $* "   # optional: names of the bases to build, e.g. gforth haskell
host_path() { if command -v cygpath >/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
export MSYS_NO_PATHCONV=1

# name|extra apt packages (sqlite3 is always included, for the inspect step)
bases=(
    'sqlite|'
    'gforth|gforth'
    'haskell|libgmp10 libffi8'
    'pcre2|libpcre2-8-0'
    'go|busybox-static'
    'make|make'
    'cmake|cmake'
    'gtk|xvfb scrot libgtk-4-1 fonts-dejavu-core'
    'dotnet|dotnet-runtime-10.0 libicu74'
    'apl|libpcre2-32-0 libstdc++6'
)

if (( force )) || ! $docker image inspect code-challenge-sandbox:local >/dev/null 2>&1; then
    echo "building code-challenge-sandbox:local (the build toolchain; slow the first time)"
    $docker build -t code-challenge-sandbox:local "$(host_path "$here/../linux")"
fi
for b in "${bases[@]}"; do
    name=${b%%|*} pkgs=${b#*|}
    [[ $only == "  " || $only == *" $name "* ]] || continue
    if (( force )) || ! $docker image inspect "cc-rt-$name:local" >/dev/null 2>&1; then
        echo "building cc-rt-$name:local"
        $docker build --target runtime -t "cc-rt-$name:local" --build-arg "PACKAGES=$pkgs" "$(host_path "$here")"
    fi
done
if [[ $only == "  " || $only == *" build-go "* ]]; then
    $docker image inspect cc-build-go:local >/dev/null 2>&1 && (( ! force )) || { echo "building cc-build-go:local"; $docker build --target build-go -t cc-build-go:local "$(host_path "$here")"; }
fi
if [[ $only == "  " || $only == *" build-rust "* ]]; then
    $docker image inspect cc-build-rust:local >/dev/null 2>&1 && (( ! force )) || { echo "building cc-build-rust:local"; $docker build --target build-rust -t cc-build-rust:local "$(host_path "$here")"; }
fi
$docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep -E '^(REPOSITORY|cc-rt-|cc-build-|code-challenge-sandbox)'
