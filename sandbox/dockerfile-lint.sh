#!/usr/bin/env bash
# Rules for an entry's own Dockerfile (src/<entry>/Dockerfile). The image is built with
# `docker build --network none`, and the gate never builds a contributor's Dockerfile at all;
# this lint is what keeps the file down to "copy my files onto a trusted runtime base".
#
#   sandbox/dockerfile-lint.sh <Dockerfile>     (or - for stdin)
#
# Rules:
#   - FROM only the trusted bases (code-challenge-sandbox:local, cc-rt-*:local, cc-build-*:local), an earlier stage, or scratch.
#   - No ADD, SHELL, ONBUILD; no RUN --mount / --network / --security.
#   - COPY --from only an earlier stage of the same file.
#   - Build stages (all but the last) may RUN anything: it runs offline, in a throwaway build container.
#   - The final stage (the runtime image) may only COPY, ENV, WORKDIR, LABEL, ARG, EXPOSE. No RUN, USER,
#     ENTRYPOINT, CMD, VOLUME or HEALTHCHECK: it inherits user nobody and the trusted entrypoint.
#   - Its ENV may set only CC_* variables (what to run), so PATH, LD_PRELOAD and friends cannot be changed,
#     and it must set CC_RUN.
# Exit status: 0 clean, 1 rules broken, 2 usage.
set -uo pipefail
src=${1:?usage: dockerfile-lint.sh <Dockerfile>}
[[ $src == - ]] && src=/dev/stdin
fails=0
fail() { echo "FAIL  Dockerfile line $1: $2"; fails=$((fails + 1)); }

# Join "\" continuations into logical lines, tagging each with its first physical line number.
mapfile -t logical < <(awk '
    { line = $0; sub(/\r$/, "", line); if (!pending) start = NR
      if (line ~ /\\[ \t]*$/) { sub(/\\[ \t]*$/, "", line); buf = buf line " "; pending = 1; next }
      print start "\t" buf line; buf = ""; pending = 0 }
    END { if (pending) print start "\t" buf }' "$src")

declare -A stages=()
last_from=0 n_from=0
for l in "${logical[@]}"; do
    ln=${l%%$'\t'*} text=${l#*$'\t'}
    text=${text#"${text%%[![:space:]]*}"}
    [[ -z $text || $text == \#* ]] && continue
    [[ ${text%%[[:space:]]*} == [Ff][Rr][Oo][Mm] ]] && { last_from=$ln; n_from=$((n_from + 1)); }
done
(( n_from >= 1 )) || { echo "FAIL  Dockerfile has no FROM"; exit 1; }

final=0 saw_run_cmd=0 current=0
for l in "${logical[@]}"; do
    ln=${l%%$'\t'*} text=${l#*$'\t'}
    text=${text#"${text%%[![:space:]]*}"}
    [[ -z $text || $text == \#* ]] && continue
    kw=${text%%[[:space:]]*}; kw=${kw^^}; rest=${text#*[[:space:]]}
    (( ln >= last_from )) && final=1
    case $kw in
        FROM)
            read -ra w <<<"$rest"
            args=(); for x in "${w[@]}"; do [[ $x == --* ]] || args+=("$x"); done
            img=${args[0]:-}
            if [[ $img =~ ^(code-challenge-sandbox|cc-(rt|build)-[a-z0-9-]+):local$ || $img == scratch || -n ${stages[${img,,}]:-} ]]; then :
            else fail "$ln" "FROM $img is not a trusted base or an earlier stage"; fi
            [[ ${args[1]:-} == [Aa][Ss] && -n ${args[2]:-} ]] && stages[${args[2],,}]=1
            [[ $rest == *--platform* ]] && fail "$ln" "FROM --platform is not allowed"
            ;;
        ADD|SHELL|ONBUILD) fail "$ln" "$kw is not allowed" ;;
        COPY)
            if [[ $rest =~ --from=([^[:space:]]+) ]]; then
                f=${BASH_REMATCH[1]}; [[ -n ${stages[${f,,}]:-} ]] || fail "$ln" "COPY --from=$f must name an earlier stage"
            fi
            ;;
        RUN)
            (( final )) && fail "$ln" "RUN is not allowed in the final (runtime) stage"
            [[ $rest =~ --(mount|network|security) ]] && fail "$ln" "RUN --mount/--network/--security is not allowed"
            ;;
        ENV)
            if (( final )); then
                # ENV a=b c=d   or   ENV a b
                vars=$(sed -E 's/"[^"]*"//g; s/\x27[^\x27]*\x27//g' <<<"$rest")
                names=$(grep -oE '(^|[[:space:]])[A-Za-z_][A-Za-z0-9_]*=' <<<"$vars" | tr -d ' \t=')
                [[ -z $names ]] && names=${rest%%[[:space:]]*}
                for n in $names; do
                    [[ $n =~ ^CC_[A-Z_]+$ ]] || fail "$ln" "ENV $n: the runtime stage may only set CC_* variables"
                    [[ $n == CC_RUN ]] && saw_run_cmd=1
                done
            fi
            ;;
        WORKDIR|LABEL|ARG|EXPOSE|USER|ENTRYPOINT|CMD|VOLUME|HEALTHCHECK|STOPSIGNAL|MAINTAINER)
            if (( final )); then
                case $kw in WORKDIR|LABEL|ARG|EXPOSE) ;; *) fail "$ln" "$kw is not allowed in the final stage (it inherits the trusted base's)" ;; esac
            fi
            ;;
        *) fail "$ln" "unknown instruction $kw" ;;
    esac
done
(( saw_run_cmd )) || fail "$last_from" "the final stage must set ENV CC_RUN (what to run)"

if (( fails )); then echo "dockerfile-lint: FAIL ($fails problem(s))"; exit 1; fi
echo "dockerfile-lint: ok"
