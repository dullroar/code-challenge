#!/bin/sh
# The passive inspector. It reads the archive with `tar -t` and `tar -xO` (extract to standard output)
# and prints what each member says. It never uses --to-command, never extracts to disk, never runs
# anything it reads, and never opens the database. It has its own, separate check of the record
# grammar (grep -E, not the case patterns in dispatch.sh); check.sh makes the two agree.
#
#   sh inspect.sh ARCHIVE         exit 0: every member is one the interpreter accepts
#                                 exit 4: some member would be refused (still shown, never run)
set -uf   # -f: a member name with a * in it must never be expanded as a file pattern
ar=${1:?usage: inspect.sh ARCHIVE}
[ -f "$ar" ] || { echo "inspect: no such archive: $ar" >&2; exit 2; }
echo "# inspector (passive: reads $ar, runs nothing from it)"
tar -tf "$ar" > "${TMPDIR:-/tmp}/inspect.$$.names" || { echo "inspect: not a readable tar archive" >&2; exit 2; }
tar -tvf "$ar" --numeric-owner > "${TMPDIR:-/tmp}/inspect.$$.long" || exit 2
trap 'rm -f "${TMPDIR:-/tmp}/inspect.$$".*' EXIT
printf '%-4s %-14s %-5s %-5s %s\n' seq member type bytes decoded
seq=0 bad=0
while IFS= read -r name <&3 && IFS= read -r long <&4; do
    seq=$((seq + 1))
    type=file; case $long in -*) ;; d*) type=dir ;; l*) type=link ;; h*) type=hard ;; *) type=other ;; esac
    # Nth occurrence of this name, so a duplicate name shows both members, in order.
    occ=$(head -n "$seq" "${TMPDIR:-/tmp}/inspect.$$.names" | grep -cxF -- "$name")
    body=
    if [ $type = file ]; then body=$(tar -xOf "$ar" --occurrence="$occ" -- "$name" | head -c 300); fi
    flat=$(printf '%s' "$body" | tr '\n' ' ' | tr -cd '[:print:]')
    set -- $long; bytes=${3:-0}   # the size tar itself reports, not the length of the text
    ln() { printf '%s\n' "$body" | sed -n "$1p"; }
    nl=$(printf '%s\n' "$body" | wc -l)
    verdict=ok
    if [ $type != file ]; then verdict="non-file member"
    elif [ "$bytes" -gt 256 ]; then verdict="bigger than 256 bytes"
    else
        op=$(printf '%s\n' "$name" | sed -n 's/^[0-9][0-9][0-9]\.\(begin\|card\|stop-over\|show\)$/\1/p')
        case $op in
            '') verdict="unknown record type" ;;
            begin) { [ "$nl" -eq 3 ] && ln 1 | grep -qx 'format=tarprog/1' && ln 2 | grep -Eqx 'seed=[0-9]+' && ln 3 | grep -qx 'label=DEMO ONLY'; } || verdict="bad begin record" ;;
            card) { [ "$nl" -eq 2 ] && ln 1 | grep -Eqx 'category=(Meetings|Coding|Debugging|Learning)' && ln 2 | grep -Eqx 'hours=1[0-9]'; } || verdict="bad card record" ;;
            stop-over) { [ "$nl" -eq 1 ] && ln 1 | grep -Eqx 'limit=[0-9]+'; } || verdict="bad stop-over record" ;;
            show) [ "$bytes" -eq 0 ] || verdict="bad show record" ;;
        esac
    fi
    [ "$verdict" = ok ] || bad=$((bad + 1))
    safe=$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '?')
    if [ "$verdict" = ok ]; then printf '%-4s %-14s %-5s %-5s %s\n' "$seq" "$safe" "$type" "$bytes" "${flat:-(empty)}"
    else printf '%-4s %-14s %-5s %-5s REFUSE (%s): %s\n' "$seq" "$safe" "$type" "$bytes" "$verdict" "${flat:-(empty)}"; fi
done 3< "${TMPDIR:-/tmp}/inspect.$$.names" 4< "${TMPDIR:-/tmp}/inspect.$$.long"
echo "# $seq member(s); $bad the interpreter would refuse"
[ "$bad" -eq 0 ] || exit 4
