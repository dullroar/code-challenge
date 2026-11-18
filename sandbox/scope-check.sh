#!/usr/bin/env bash
# The deterministic half of reviewing an outside entry: rules a pull request must pass before
# anything in it is run, and a list of the constructs a human (or AI) reviewer must look at.
# It reads the PR's commits with git only; it never checks them out or runs them.
#
#   sandbox/scope-check.sh <base> <head> [--entries-out FILE]
#   sandbox/scope-check.sh origin/master pr/head
#
# Hard rules (any one fails the PR):
#   - It adds exactly one NEW folder under src/, and may otherwise only modify README.md.
#     Nothing else: not sandbox/, .github/, build files, the Gradle wrapper, other entries.
#   - The new folder has a README.md and a check: check.sh (Linux sandbox) and/or check.ps1
#     (Windows), which must build the entry, run it unattended and verify its own rules.
#   - Plain path names only ([A-Za-z0-9._/-]); no symlinks, no submodules.
#   - No binary files, and nothing over 256 KiB.
#   - No invisible or direction-changing characters (Trojan Source), and no control characters.
#   - The README starts with the frontmatter block described in CONTRIBUTING.md (the book is built from it),
#     and has the shared section headings (Run it, Program Flow, How the stunt works, What check.sh enforces, Gotchas worth knowing).
#   - The new folder is easy to try: it ships a Dockerfile, or its README has a "## Run it in Windows Sandbox" section.
#   - A Dockerfile in the new folder must pass dockerfile-lint.sh (trusted bases only, no RUN in the runtime stage).
#
# The report (never fails the PR; it tells the reviewer where to look): network-looking text,
# anything that starts processes or evaluates code, and long encoded blobs.
#
# Exit status: 0 pass, 1 fail, 2 usage or git error.
set -uo pipefail
export LC_ALL=C.UTF-8
# Git Bash: don't let MSYS rewrite "ref/name:path" arguments into Windows path lists.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'

[[ $# -ge 2 ]] || { echo "usage: $0 <base> <head> [--entries-out FILE]" >&2; exit 2; }
base=$1 head=$2 entries_out=
[[ ${3:-} == --entries-out ]] && entries_out=${4:?--entries-out needs a file}

fails=0
fail() { echo "FAIL  $*"; fails=$((fails + 1)); }

mb=$(git merge-base "$base" "$head" 2>/dev/null) || { echo "scope-check: no merge base for $base and $head" >&2; exit 2; }

declare -A entries=()
readme_changed=0
while IFS=$'\t' read -r status path; do
    [[ -n $path ]] || continue
    if [[ ! $path =~ ^[A-Za-z0-9._/-]+$ ]]; then fail "unusual path name: $(printf %q "$path")"; continue; fi
    if [[ $path == README.md && $status == M ]]; then readme_changed=1
    elif [[ $path =~ ^src/([^/]+)/ ]]; then entries[${BASH_REMATCH[1]}]=1
    else fail "outside the allowed scope ($status): $path"
    fi
done < <(git diff --name-status --no-renames "$mb" "$head")

if (( ${#entries[@]} != 1 )); then
    fail "expected exactly one new folder under src/, found ${#entries[@]}: ${!entries[*]}"
fi

for entry in "${!entries[@]}"; do
    dir=src/$entry
    git cat-file -e "$mb:$dir" 2>/dev/null && fail "$dir already exists on the base branch (changes to existing entries are reviewed by hand)"
    git cat-file -e "$head:$dir/README.md" 2>/dev/null || fail "$dir has no README.md"
    git cat-file -e "$head:$dir/check.sh" 2>/dev/null || git cat-file -e "$head:$dir/check.ps1" 2>/dev/null         || fail "$dir has no check.sh or check.ps1"

    readme=$(git show "$head:$dir/README.md" 2>/dev/null || true)
    fm=$(awk 'NR==1 && $0 != "---" { exit } NR>1 && $0 == "---" { exit } NR>1 { print }' <<<"$readme")
    if [[ -z $fm ]]; then
        fail "$dir/README.md must start with the frontmatter block described in CONTRIBUTING.md"
    else
        for key in name teaches kind languages lesson loop-by evaluation assurance tags; do
            grep -q "^$key:" <<<"$fm" || fail "$dir/README.md frontmatter is missing '$key:'"
        done
        tags=$(sed -nE 's/^tags:[[:space:]]*\[(.*)\][[:space:]]*$/\1/p' <<<"$fm" | tr -d ' ')
        [[ -n $tags ]] || fail "$dir/README.md frontmatter needs a non-empty tags: [a, b] list"
        # An unknown tag is not a failure: a maintainer adds the concept at merge. Say so.
        for t in ${tags//,/ }; do
            git cat-file -e "$mb:lessons/cs-source/concepts/$t.md" 2>/dev/null || echo "NOTE  $dir/README.md: tag '$t' is not a concept yet; a maintainer decides whether to add it"
        done
        langs=$(sed -nE 's/^languages:[[:space:]]*\[(.*)\][[:space:]]*$/\1/p' <<<"$fm" | tr -d ' ')
        for l in ${langs//,/ }; do
            git show "$mb:lessons/cs-source/languages.txt" 2>/dev/null | grep -q "^$l:" || echo "NOTE  $dir/README.md: language '$l' is not in lessons/cs-source/languages.txt yet; a maintainer adds it"
        done
        role=$(sed -nE 's/^loop-by:[[:space:]]*([A-Za-z0-9-]+).*/\1/p' <<<"$fm")
        git cat-file -e "$mb:lessons/cs-source/roles/$role.md" 2>/dev/null || echo "NOTE  $dir/README.md: loop-by '$role' is not a known role"
    fi

    # The section headings every entry shares, so readers and the book can rely on them.
    for h in '## Run it' '## Program Flow' '## How the stunt works' '## Gotchas worth knowing'; do
        grep -qxF "$h" <<<"$readme" || fail "$dir/README.md needs a section headed exactly '$h' (see CONTRIBUTING.md)"
    done
    if git cat-file -e "$head:$dir/check.sh" 2>/dev/null; then
        grep -qxF '## What `check.sh` enforces' <<<"$readme" || fail "$dir/README.md needs a section headed exactly '## What \`check.sh\` enforces'"
    elif git cat-file -e "$head:$dir/check.ps1" 2>/dev/null; then
        grep -qxF '## What `check.ps1` enforces' <<<"$readme" || fail "$dir/README.md needs a section headed exactly '## What \`check.ps1\` enforces'"
    fi

    if ! git cat-file -e "$head:$dir/Dockerfile" 2>/dev/null; then
        git show "$head:$dir/README.md" 2>/dev/null | grep -q '^## Run it in Windows Sandbox' \
            || fail "$dir needs a Dockerfile, or a '## Run it in Windows Sandbox' section in its README, so a reviewer can try it safely"
    fi
    if git cat-file -e "$head:$dir/Dockerfile" 2>/dev/null; then
        lint=$(git show "$head:$dir/Dockerfile" | "$(dirname "$0")/dockerfile-lint.sh" - 2>&1) || { fail "$dir/Dockerfile breaks the container rules:"; sed 's/^/        /' <<<"$lint"; }
    fi

    while read -r mode type _ path; do
        case $mode in
            120000) fail "symlink: $path" ;;
            160000) fail "submodule: $path" ;;
        esac
        [[ $type == blob ]] || continue
        size=$(git cat-file -s "$head:$path")
        (( size <= 262144 )) || fail "too large ($size bytes): $path"
    done < <(git ls-tree -r "$head" -- "$dir")

    while IFS=$'\t' read -r added deleted path; do
        [[ $added == - ]] && fail "binary file: $path"
    done < <(git diff --numstat "$mb" "$head" -- "$dir")
done

# Every text file the PR adds or changes, for the character checks and the report. Binary files
# are skipped here (git's numstat shows them as "-"); inside src/ they have already failed above.
mapfile -t files < <(git diff --numstat --diff-filter=AM "$mb" "$head" | awk -F'\t' '$1 != "-" && $3 != "README.md" { print $3 }')
(( readme_changed )) && files+=(README.md)

hidden='[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{2064}\x{2066}-\x{2069}\x{FEFF}\x{00AD}\x{2028}\x{2029}]'
control='[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'
content() {   # the PR's version of a file; for README.md only the lines the PR adds
    if [[ $1 == README.md ]]; then git diff -U0 "$mb" "$head" -- README.md | sed -n 's/^+\([^+]\)/\1/p'
    else git show "$head:$1"; fi
}
for f in "${files[@]}"; do
    hits=$(content "$f" | grep -nP "$hidden" | cut -d: -f1 | tr '\n' ' ')
    [[ -n $hits ]] && fail "invisible or bidi characters in $f, line(s): $hits"
    hits=$(content "$f" | grep -naP "$control" | cut -d: -f1 | tr '\n' ' ')
    [[ -n $hits ]] && fail "control characters in $f, line(s): $hits"
done

echo
echo "=== Reviewer report: lines to read closely (informational, not failures)"
# label|PCRE. Deliberately broad: a reviewer would rather skip ten harmless hits than miss one.
patterns=(
    'network|https?://|\b\d{1,3}(\.\d{1,3}){3}\b|/dev/(tcp|udp)|\bsocket\b|\bcurl\b|\bwget\b|\bnc\b|HttpClient|WebClient|urllib|requests\.|net/http|fetch\('
    'starts processes|\bsystem\s*\(|\bexec[a-z]*\b|\bpopen\b|\bspawn|Process\.Start|ProcessBuilder|Runtime\.getRuntime|subprocess|os\.system|readProcess|callProcess|createProcess|open-pipe|\$\(shell|execute_process|⎕SH|⎕CMD|⎕FIO|\(\?C|`[^`]+`'
    'evaluates or loads code|\beval\b|⍎|⎕FX|⎕NA|\(\?\{|\(\?\?\{|Assembly\.Load|Activator|XamlReader|ObjectDataProvider|DllImport|LoadLibrary|dlopen|__import__|importlib|\bcompile\s*\(|Reflection|ClassLoader|unsafePerformIO|foreign import'
    'encoded blob|[A-Za-z0-9+/]{80,}={0,2}|(\\x[0-9A-Fa-f]{2}){12,}|\b[0-9A-Fa-f]{64,}\b|base64|FromBase64|atob\('
    'environment and identity|\bgetenv\b|GetEnvironmentVariable|os\.environ|\$ENV\{|\bHOME\b|\.ssh|\.aws|\.gitconfig|credential|token|password'
)
for p in "${patterns[@]}"; do
    label=${p%%|*} re=${p#*|}
    out=
    for f in "${files[@]}"; do
        r=$re; [[ $f == *.md ]] && r=${re//'|`[^`]+`'/}   # Markdown code spans aren't shell backticks
        hits=$(content "$f" | grep -nP -- "$r" | cut -c1-200 | sed "s|^|  $f:|")
        [[ -n $hits ]] && out+=$hits$'\n'
    done
    if [[ -n $out ]]; then echo "--- $label"; printf '%s' "$out"; fi
done

echo
if (( fails )); then echo "scope-check: FAIL ($fails problem(s))"; exit 1; fi
[[ -n $entries_out ]] && printf 'src/%s\n' "${!entries[@]}" > "$entries_out"
echo "scope-check: PASS (new entry: src/${!entries[*]})"
