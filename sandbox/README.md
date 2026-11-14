# sandbox/: running entries we haven't written

This folder is the trusted side of reviewing outside entries. It is changed only by maintainers; `scope-check.sh` rejects any pull request that touches it. Contributor-facing rules are in [`CONTRIBUTING.md`](../CONTRIBUTING.md). To install Docker or Windows Sandbox and set up the toolchains they borrow, see [`SANDBOX-SETUP.md`](../SANDBOX-SETUP.md); this page assumes that is done.

| Piece | What it does |
| --- | --- |
| `linux/Dockerfile` | One image with every toolchain the Linux entries need, pinned: Ubuntu by digest, apt packages, GNU APL and a callout-enabled `pcre2grep` built from SHA-256-checked tarballs. |
| `run.sh <entry>...` | Runs an entry's `make check` (if its Makefile has one) or `check.sh` in that image: no network, read-only root, no capabilities, user `nobody`, 256 processes, 2 GiB memory, 2 CPUs, 15-minute timeout. The entry is mounted read-only and copied into a tmpfs. |
| `container/` | **Per-entry runtime images** that run an entry and *show* what it did, rather than test it. `build-bases.sh` builds the trusted bases (one tiny runtime image per kind of entry: sqlite3 plus the interpreter or libraries, no compiler, no package manager, no setuid); `run-image.sh src/<entry>` builds the entry's own `Dockerfile` on top and runs it with the same lockdown as `run.sh`, then prints a read-only look at every file and SQLite table it wrote. `entrypoint.sh` is shared and lives in the bases, so an entry only chooses *what* to run. |
| `dockerfile-lint.sh <Dockerfile>` | The rules for an entry's own `Dockerfile`: only trusted bases, no `ADD`, no `RUN` in the runtime stage, only `CC_*` variables in its `ENV`. Run by `scope-check.sh` on any PR that ships one, and by `run-image.sh` before building. |
| `scope-check.sh <base> <head>` | The rules a PR must pass before anything in it runs, read from git without a checkout, plus the reviewer report. |
| `selftest.sh` | Proves the above: `selftest/hostile` tries the network, host files, root, capabilities, credentials, a fork bomb and a 3 GiB allocation, and passes only if every probe is blocked. `selftest/sleeper` must be killed at the timeout. `selftest/container-probe.sh` runs inside an entry's runtime image and checks it has no package manager, compiler, fetch tool or setuid binary, can't write outside `/work`, and has no network. Twenty-two fake PRs (seven of them with Dockerfiles) must each be passed or rejected correctly. |
| `windows/run.ps1 <entry>` | Builds and runs a Windows or GUI entry in **Windows Sandbox** (a throwaway Hyper-V VM) with networking off. The host toolchain for that kind of entry is mapped in read-only, so restore is offline. The entry's `check.ps1` runs if it has one; otherwise it gets a smoke test (start, wait, screenshot, ask it to close, then show what it saved). |
| `windows/profiles/` | One file per kind of entry (`dotnet`, `python`, `go`, `gradle`): which host folders to map, how to build and start it, how to show its results. See its README to add a language. |
| `windows/inside.ps1` | The part of that which runs inside the VM, also used by the Actions Windows job. |
| `windows/regression.txt` | The existing Windows entries the gate runs when no PR number is given. |
| `../.github/workflows/sandbox-gate.yml` | The gate on GitHub's machines, triggered by hand. |

## Running an entry to see what it does

For a human to watch an entry run, rather than for the gate to judge it:

- **Linux entries:** `sandbox/container/run-image.sh src/<entry>`. Each entry carries its own `Dockerfile`: a build stage with the toolchain, then a runtime stage that copies in only the finished program on a base with just enough to run it (117 to 350 MB, against 2.45 GB for the toolchain image). No network, no host files (unless you pass `--out`), and a read-only look at the results afterwards. The Go entry serves its page on loopback *inside* the container; the entrypoint fetches it from there with `wget` and then "closes" it, so no port is ever published.
- **Windows and GUI entries:** `sandbox\windows\run.ps1 src\<entry>`. Covers .NET (WPF, XAML, LINQ), Python/Tk, and, untested so far, Go (in Edge) and Java/Kotlin Swing.
- **GUI entries on Linux:** the Rust/GTK entry runs in a container on a virtual display (Xvfb) and is screenshotted from inside; use `--out` to get the PNG. There is deliberately no Windows Sandbox profile for it: GTK 4 on Windows is not something to ship into a sandbox.

Prerequisites for both are in [`SANDBOX-SETUP.md`](../SANDBOX-SETUP.md).

### Why an entry's Dockerfile is safe to carry in a pull request

A `RUN` line in a Dockerfile is code that runs at build time, normally with network and as root, so a contributor's Dockerfile could otherwise defeat the whole gate. Three things keep it contained:

1. **The gate never builds one.** It still uses the trusted toolchain image. Entry images are built only by people running `run-image.sh`, after the PR has been read.
2. **It builds with `docker build --network none`** from base images a maintainer built from `master` (`build-bases.sh`). The packages and the pinned downloads (GNU APL, pcre2grep) live in those bases, not in the entry.
3. **`dockerfile-lint.sh` limits what it may say:** `FROM` only the trusted bases or an earlier stage; no `ADD`, `SHELL` or `ONBUILD`; no `RUN --mount`/`--network`; `COPY --from` only an earlier stage; and the final (runtime) stage may only `COPY`, `WORKDIR`, `LABEL`, `ARG`, `EXPOSE` and `ENV CC_*`, so it can't run anything, change the user, or touch `PATH`. `scope-check.sh` applies it to PRs.

What is left: a `RUN` in a *build* stage still runs arbitrary code in an offline, throwaway build container, as root, on the Docker VM. Read it like any other code in the PR. (The one exception to "offline" is `--online-build`, for entries already on `master`.)

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
- The **Actions Windows runner has network.** It's a fresh VM with no secrets, so the risk is to GitHub's machine, not ours. For a network-off Windows run, use `windows/run.ps1` locally. The job prints the names of any credential-like environment variables the entry could read. When first tested (2026-11-14) there were no tokens (no `ACTIONS_RUNTIME_TOKEN`, OIDC token or `GITHUB_TOKEN`); the only names were an orchestration ID and the runner image's stock `PGPASSWORD` for its preinstalled Postgres. The runner does have a real desktop, so WPF windows open and the screenshots in the run's artifacts show them.
- The GUI ports (Rust/GTK, Python/Tk, Java and Kotlin/Swing, Go in a browser) have no check script and aren't covered yet. They're Ken's and Jim's, and they wait for someone to close a window.

## Adding a toolchain for a new language

Do it in its own commit on `master`, never in the contributor's PR:

- For the **container** images, add a line to `container/build-bases.sh` (a new `cc-rt-<name>` runtime base with the packages the entry needs at run time) and, if it must be compiled, put the compiler in the toolchain image as below. Entries then say `FROM cc-rt-<name>:local`; the lint already accepts `cc-rt-*` and `cc-build-*`.
- For **Windows Sandbox**, add a profile in `windows/profiles/`.

- Prefer an Ubuntu package: add it to the `apt-get install` line.
- Otherwise use the official upstream release tarball. Record its SHA-256 and verify it with `sha256sum -c` in the Dockerfile, the same way as `PCRE2` and `APL`.
- Then run `sandbox/selftest.sh`, plus `sandbox/run.sh` on every entry, to make sure nothing else changed.

## Repository settings that back this up

These are set on GitHub, not in files, and are worth turning on:

- **Settings → Actions → General → "Require approval for all external contributors"**, so a fork's PR can't run workflows on its own.
- **A ruleset on `master`**: require a pull request; and in `.github/CODEOWNERS`, make the maintainers owners of `/sandbox/`, `/.github/` and the root build files, with code-owner review required.
