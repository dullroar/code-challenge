# Sending in an entry

Entries from anyone are welcome. This repository is, on purpose, a collection of programs that run code from places code shouldn't run: regex engines, markup parsers, build tools, a text interpreter's own parse pointer. Because of that, an entry from someone we don't know is treated as untrusted until we have read it, understood it, and run it somewhere it can't hurt anyone. None of this is personal; it is the same review whoever you are.

## What a pull request may contain

- **One new folder under `src/`**, and optionally one new row in the results table in `README.md`. Nothing else: no changes to `sandbox/`, `.github/`, the root build files, the Gradle wrapper, or other entries. `sandbox/scope-check.sh` rejects anything outside that.
- **Text only.** No binaries (compile at check time), no file over 256 KiB, no symlinks or submodules, plain file names (`A-Z a-z 0-9 . _ - /`), and no invisible or direction-changing Unicode characters. APL glyphs and other visible Unicode are fine.
- **A `README.md`** with a **How the stunt works** section: a plain-English walkthrough of the mechanism. This is the most important part. If we can't follow how your entry works, we can't merge it, however clever it is. In that case we will gladly link to it in your own repository instead (see below).
- **A check script** that builds the entry, runs it unattended, checks its own rules, and exits non-zero on any failure. Look at any existing `check.sh` for the pattern.
  - `check.sh` for the Linux sandbox. It runs with **no network**, as an unprivileged user, on a read-only system with a writable scratch folder. Write your demo data under `$XDG_DATA_HOME` (or `mktemp -d`), and finish within 15 minutes.
  - `check.ps1` for Windows-only entries (WPF and the like). It runs in Windows Sandbox with no network, and restores NuGet packages only from what we already have.
- Your contribution is under the repository's [MIT license](LICENSE).

## Your language's toolchain

Entries run only with what is already in [`sandbox/linux/Dockerfile`](sandbox/linux/Dockerfile): GNU APL, Gforth, GHC, Perl, PCRE2, sed, Make, CMake, a C compiler, .NET 10 and SQLite. If yours needs something else, say so in the pull request and tell us where its official distribution lives. We add it to the image ourselves, in a separate commit, pinned to a version and checksum. Please don't send install scripts, and don't ask us to install an interpreter from your own repository.

## Before you open the pull request

From a Linux, macOS or WSL shell with Docker (or Git Bash with Docker Desktop):

```bash
sandbox/run.sh src/your-entry                 # the same sandbox the gate uses
sandbox/scope-check.sh origin/master HEAD     # the same scope rules, plus the reviewer report
```

The reviewer report at the end of `scope-check.sh` lists every line that touches the network, starts a process, evaluates code, or looks like an encoded blob. It's normal for entries in this repository to have some; expect your README to explain each one.

## What happens next

1. `scope-check.sh` runs against your pull request without checking it out.
2. People (and a few AI reviewers, each asked to translate your code into plain English and list everything it can touch) read the code alongside your README.
3. A maintainer runs the gate: your check, in the sandbox, on a throwaway machine.
4. Then one of two things happens:
   - **Merged**, with credit in the results table.
   - **Linked**: we add a row pointing to your own repository at a specific commit. This is not a rejection. It means we enjoyed it but couldn't vouch for every line, usually because the language is beyond what we can read with confidence.

A passing gate means your entry built, ran and behaved in a sandbox. It is not, on its own, why we merge. Understanding it is.
