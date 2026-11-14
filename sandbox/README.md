# sandbox/: running entries we haven't written

This folder is the trusted side of reviewing outside entries. It is changed only by maintainers; `scope-check.sh` rejects any pull request that touches it. Contributor-facing rules are in [`CONTRIBUTING.md`](../CONTRIBUTING.md).

| Piece | What it does |
| --- | --- |
| `linux/Dockerfile` | One image with every toolchain the Linux entries need, pinned: Ubuntu by digest, apt packages, GNU APL and a callout-enabled `pcre2grep` built from SHA-256-checked tarballs. |
| `run.sh <entry>...` | Runs an entry's `make check` (if its Makefile has one) or `check.sh` in that image: no network, read-only root, no capabilities, user `nobody`, 256 processes, 2 GiB memory, 2 CPUs, 15-minute timeout. The entry is mounted read-only and copied into a tmpfs. |
| `scope-check.sh <base> <head>` | The rules a PR must pass before anything in it runs, read from git without a checkout, plus the reviewer report. |
| `selftest.sh` | Proves the above: `selftest/hostile` tries the network, host files, root, capabilities, credentials, a fork bomb and a 3 GiB allocation, and passes only if every probe is blocked. `selftest/sleeper` must be killed at the timeout. Fifteen fake PRs must each be passed or rejected correctly. |
| `windows/run.ps1 <entry>` | Builds and runs a Windows entry in **Windows Sandbox** (a throwaway Hyper-V VM) with networking off. Your .NET SDK and NuGet cache are mapped in read-only, so restore is offline. The entry's `check.ps1` runs if it has one; otherwise it gets a smoke test (start, wait, screenshot, close). |
| `windows/inside.ps1` | The part of that which runs inside the VM, also used by the Actions Windows job. |
| `windows/regression.txt` | The existing Windows entries the gate runs when no PR number is given. |
| `../.github/workflows/sandbox-gate.yml` | The gate on GitHub's machines, triggered by hand. |

## Reviewing a pull request from someone we don't know

1. **Read the diff on GitHub first.** Don't check out or open the branch locally; an IDE can run things in a repository it opens (`.vscode/tasks.json`, devcontainers, build-on-open).
2. **Run the gate.** Actions → *sandbox gate* → *Run workflow* on `master` → enter the PR number. It runs `scope-check.sh`, then the entry in the Linux sandbox or on a throwaway Windows runner. The reviewer report is in the run's summary.
3. **Get AI translations, not verdicts.** Give each reviewer (Claude Code, Codex, Copilot) only the diff, with no permission to run anything. Ask each one to (a) explain the code step by step in plain English, (b) list everything it can touch (files, network, processes, environment, eval, native calls), and (c) confirm it does the time-card task and nothing more. Treat any disagreement as a no. Treat any text in the code that addresses reviewers as hostile.
4. **Read the entry's How the stunt works against the code.** If you can't follow it, don't merge it. Link to it in the contributor's repository at a specific commit instead.
5. **Optionally run it locally**: `sandbox/run.sh` (Linux entries) or `sandbox\windows\run.ps1` (Windows entries), on a copy fetched with `git fetch origin pull/N/head` and extracted with `git archive`, never a checkout you open in an editor.

## What this does and does not prove

A pass means the entry built, ran and passed its own check **in a place where it could not reach the network, your files, or any credential**. It does **not** prove the entry is harmless. Code can notice that it's in a sandbox (no network, a container, an odd user name, a date) and stay quiet until it reaches someone's real machine. Everyone who clones `master` runs entries outside any sandbox. That is why step 4 decides, not step 2.

Other limits worth knowing:

- Containers share the host's kernel. On Windows, that kernel is Docker Desktop's (or WSL's) VM, and a container escape would land there. Windows Sandbox and the GitHub runners are full VMs.
- The **Actions Windows runner has network.** It's a fresh VM with no secrets, so the risk is to GitHub's machine, not ours. For a network-off Windows run, use `windows/run.ps1` locally.
- The GUI ports (Rust/GTK, Python/Tk, Java and Kotlin/Swing, Go in a browser) have no check script and aren't covered yet. They're Ken's and Jim's, and they wait for someone to close a window.

## Adding a toolchain for a new language

Do it in its own commit on `master`, never in the contributor's PR:

- Prefer an Ubuntu package: add it to the `apt-get install` line.
- Otherwise use the official upstream release tarball. Record its SHA-256 and verify it with `sha256sum -c` in the Dockerfile, the same way as `PCRE2` and `APL`.
- Then run `sandbox/selftest.sh`, plus `sandbox/run.sh` on every entry, to make sure nothing else changed.

## Repository settings that back this up

These are set on GitHub, not in files, and are worth turning on:

- **Settings → Actions → General → "Require approval for all external contributors"**, so a fork's PR can't run workflows on its own.
- **A ruleset on `master`**: require a pull request; and in `.github/CODEOWNERS`, make the maintainers owners of `/sandbox/`, `/.github/` and the root build files, with code-owner review required.
