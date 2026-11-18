#!/bin/sh
# Lays out the payload whose archive is the clock. At the default settings (-b 1 --checkpoint=1) tar writes
# one 512-byte record per checkpoint, so the number of ticks is the number of 512-byte blocks in the archive:
#     blocks = sum over members of (1 header + ceil(size / 512) data) + 2 end-of-archive blocks.
#   sh layout.sh [--ticks N] [--members M] DIR      writes DIR/m01 ... and DIR/list (the member names, in order)
set -eu
ticks=64 members=1
while [ $# -gt 1 ]; do
    case $1 in --ticks) ticks=$2; shift 2 ;; --members) members=$2; shift 2 ;; *) echo "usage: layout.sh [--ticks N] [--members M] DIR" >&2; exit 2 ;; esac
done
dir=${1:?usage: layout.sh [--ticks N] [--members M] DIR}
case $ticks$members in *[!0-9]*) echo "numbers only" >&2; exit 2 ;; esac
data=$(( ticks - 2 - members ))
[ "$members" -ge 1 ] && [ "$data" -ge 0 ] || { echo "layout: $ticks ticks cannot hold $members member(s)" >&2; exit 2; }
mkdir -p "$dir"; : > "$dir/list"
i=1; each=$(( data / members )); rest=$(( data - each * members ))
while [ "$i" -le "$members" ]; do
    d=$each; [ "$i" -eq "$members" ] && d=$(( each + rest ))
    name=$(printf 'm%02d' "$i")
    head -c $(( d * 512 )) /dev/zero > "$dir/$name"
    echo "$name" >> "$dir/list"
    i=$(( i + 1 ))
done
