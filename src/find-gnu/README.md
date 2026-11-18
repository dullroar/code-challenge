---
name: "GNU find"
teaches: "that the GNU extras to find (path depth, file times, regular expressions and a built-in profiler) can replace a whole table of branches, and that find's optimizer has nothing to reorder when every branch ends in a side effect."
kind: weird
languages: [find, sqlite]
lesson: "languages/find.md"
loop-by: self-modifying-control
evaluation: declarative
assurance: accidentally-exploited
pairs-with: find-posix
machine: "A tree walk that grows the tree it is walking, with find itself reading the depth and the clock"
state: "The path from the start directory to the directory being visited; its depth is the running total"
tags: [call-stack, compiler-optimization, control-flow, domain-specific-language, hyrums-law, integrity-constraint, observability, recursion, regular-expression, short-circuit-evaluation, side-effect, state-encoding, transition-system, undefined-behavior, weird-machine]
---
# GNU find: let find do the arithmetic

**Teaches you:** that the GNU extras to find (path depth, file times, regular expressions and a built-in profiler) can replace a whole table of branches, and that find's optimizer has nothing to reorder when every branch ends in a side effect.

> **DEMO ONLY.** Fictional time cards, written to a scratch SQLite file under `$XDG_DATA_HOME/FindGnu/`.
> Nothing here touches real time reporting.

This is the same stunt as [`find-posix`](../find-posix/README.md): one `find`, and the walk digs the directory tree it is walking. The difference is that this entry may use anything GNU find has. That turns out to remove most of the work. The line is about 3 KB, a little over half the size of the portable one. In one profiled run of each, find evaluated about 2,950 tests here and about 57,000 there.

```
# DEMO ONLY run 1
Meetings	13	13	2026-W47	DEMO ONLY
Coding	19	32	2026-W47	DEMO ONLY
Debugging	12	44	2026-W47	DEMO ONLY
# committed total=44 entries=3 DEMO ONLY
Runtime error near line 12: CHECK constraint failed: stop rule fired: total exceeds 40 (19)
```

## Run it

You need **GNU find** (4.9 was tested; as far as we know, BSD and macOS find have no `-fprintf`, so they cannot run it), a POSIX shell, `mktemp` and `sqlite3`.

```bash
cd src/find-gnu
./timecards.sh                      # run the demo
FIND_O=0 ./timecards.sh             # pick the optimizer level, -O0 to -O3 (default 3)
FIND_D=rates ./timecards.sh         # also print find's own profile of the program (stderr)
./check.sh                          # random runs at every -O level, forced dice, the rules below
python3 build-line.py               # print the find line (check.sh compares it with timecards.sh)
```

Records go to `$XDG_DATA_HOME/FindGnu/demo-timecards.db` (default `~/.local/share/FindGnu/`).

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker).

```bash
sandbox/container/run-image.sh src/find-gnu
```

It builds this folder's [`Dockerfile`](Dockerfile) and runs the result with no network, a read-only file system and user `nobody`. The image holds GNU findutils, coreutils and sqlite3 on a minimal Ubuntu.

## How the stunt works

Read [how the portable entry works](../find-posix/README.md#how-the-stunt-works) first. It explains why the walk goes into the directory that `-exec` just made, and why `*` in a pattern can count. This page covers only what the GNU extras change.

**One directory is one hour, with no extra bookkeeping.** In the portable entry a path has three kinds of directory, and the running total is spelled out digit by digit. Here the first hour of a card is the dice directory itself (six random characters), and the remaining hours are `b17` down to `b00`. So the depth of a directory *is* the number of hours so far.

| Job | Done by |
|---|---|
| Loop | the walk, as before |
| Randomness | `mktemp -d`; `-name '?????[abcdef]'` reads the last character. Y and Z are re-rolled on the character before, exactly as in the portable entry |
| Countdown | `-name b12 -exec mkdir {}/b11 \;`, one branch per value (`b17` to `b01`). The names are unique to the countdown, so no path pattern is needed |
| Running total | **`-fprintf ... '%d,'`**. `%d` is the depth of the file, and the depth is the total |
| ISO week | **`%TG-W%TV`**: the modification time of the new directory, formatted with the ISO year and week. No `date`, because making a directory touches its clock |
| Category order | **`-regex '(.*/[^/]{6}){2}.*'`**: "at least two six-character names in the path" is "at least the second card". One regular expression per category |
| Stop rule | **`-regex '([^/]*/){41}.*'`**: "at least 41 slashes" is "the total is over 40". When it matches, nothing more is dug and the walk ends |
| Output | **`-fprintf /dev/fd/3`**: the SQL goes to file descriptor 3. `mktemp` still prints each path it makes, but that goes to stdout, and the host sends stdout to `/dev/null`. The portable entry needs a comment trick for this |
| Persistence | `sqlite3` reads fd 3 through a pipe and holds the `CHECK` constraints |

The host line is `find ... 3>&1 >/dev/null`: fd 3 becomes the pipe, and stdout becomes the bit bucket.

`-exec` runs only two programs, `mkdir` and `mktemp`. No `date`, no `printf`.

### The optimizer

GNU find has a cost-based optimizer (`-O1` to `-O3`) that reorders tests: cheap ones first, likely failures first in an `-a` chain, likely successes first in an `-o` chain. The manual promises it never changes the result and never reorders a side effect against another. This entry puts it to work and then tries to catch it.

- `check.sh` runs the whole demo at `-O0`, `-O1`, `-O2` and `-O3`, 15 random runs and 7 forced-dice scenarios at each. The answers are always right.
- `-D tree` prints the expression tree after optimization. For this line the tree at `-O0` and at `-O3` is **identical**: 3,610 lines, no difference. The optimizer has nothing to move, because every branch is a test followed by an effect (`-name b00 -fprintf ...`), and an effect pins the order.
- We also looked for a case the manual does not spell out: a pure test written *after* an `-exec` (`-exec printf ... \; -type f -name a`). At every level, `-exec` ran on every file, so the tests were not moved in front of the effect.

So we did not find a way to make the optimizer change the answer. A well-demonstrated nothing is still a finding.

### The profiler

`FIND_D=rates ./timecards.sh` passes `-D rates` to find, and find prints, for every test in the program, how often it *really* succeeded. It is find's own profile of your program. The optimizer's guesses are flat (every `-path` or `-regex` is assumed to succeed about 80% of the time), and the real rates are far from that.

## What `check.sh` enforces

`check.sh` needs GNU find. The line must be exactly one `find`, with no `for`, `while`, `until`, `case` or `if` anywhere in `timecards.sh`. Its primaries must be exactly `-O`, `-exec`, `-fprintf`, `-name`, `-o`, `-path`, `-regex` and `-regextype`. `-exec` may run only `mkdir` and `mktemp`. There may be no `-delete`, `-print`, `-printf`, `-ok`, `-execdir` or `-ls`. The line must be what `build-line.py` prints.

Then, at each optimizer level from `-O0` to `-O3`, it runs the demo 15 times and checks hours 10-19, categories in order, running totals, `DEMO ONLY` on every row, an ISO week that matches `date`, a stop exactly when the total passes 40, one stop-rule error on stderr and nothing else, SQLite rows that match the printed ones, and an empty scratch folder afterward. Over the 60 runs, at least eight different hour values must show up.

At every level it also forces the dice with a fake `mktemp` first on `PATH`: seven scenarios that cover the tens and units digits, a total of exactly 40 (which must continue), and the re-roll paths. The answers must not depend on the `-O` level. Then `FIND_D=rates` must print success rates and leave the answers unchanged. Last, SQLite must refuse a non-demo row.

## Gotchas worth knowing

- **GNU only.** `-fprintf`, `%d`, `%T`, `-regex` with `-regextype posix-extended` and `-D` are GNU extensions, and we ran this entry only on GNU find 4.9. Everything here is **implementation-permitted**, and the walk-into-new-directories trick is still **accidentally exploited**, as in the portable entry.
- **`-quit` would end find sooner, and it is not used.** When find stops with `-quit` it exits at once and skips the `-D rates` summary (we measured: zero lines with `-quit`, two without). So the stop rule here is "dig nothing more", and find runs out of tree by itself.
- **`/dev/fd/3` must be a pipe.** find opens an output file with truncation. If fd 3 were your terminal's capture file, each run would erase what was there before. The host always pipes it. Two `-fprintf` calls with the same file name share one stream, so the pieces of one SQL statement stay in order.
- **`-regextype` is positional.** It applies only to the `-regex` tests that come after it, so the line puts it first.
- **`%d` counts from the start directory.** The start directory `t` is depth 0, the first dice directory is depth 1, so the depth of the last hour in a card is exactly the total.
- **`-newer` is not used, on purpose.** The manual says `-newer` reads its reference file's time *once*, when the command line is parsed. A reference file that `-exec` changes later would not be seen again, so it cannot be a live counter.
- **`-files0-from` is not used.** It would let one `find` hand its list to another, but this program has no list to hand over: the tree is the data, and it is made as the walk goes.
- **The line is still long.** About 3 KB, with the countdown (17 branches) and the dice (21 branches) written out. GNU find has no variables either.

---

See the [root README](../../README.md#the-results-so-far) for how this compares to the other entries, and [`CHALLENGE.md`](../../CHALLENGE.md) if you want to write your own.
