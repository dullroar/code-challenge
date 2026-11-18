---
name: "GNU tar"
teaches: "that an archive's physical layout can set the pace of a program: tar's checkpoints are a clock, and each tick moves a state machine by one step."
kind: weird
languages: [tar, sqlite]
lesson: "languages/tar.md#the-archive-is-the-clock"
loop-by: dispatch-and-triggers
evaluation: eager
assurance: implementation-permitted
pairs-with: tar-gnu
machine: "A finite-state machine, driven by a logical clock that tar supplies"
state: "One SQLite row (the machine's registers) and the number of records tar has written"
tags: [computation-versus-orchestration, event-driven-programming, exit-status, hyrums-law, integrity-constraint, invariant, leaky-abstraction, logical-clock, observability, operational-semantics, portability, reproducibility, side-effect, state, state-encoding, transition-system]
---
# GNU tar, weirder: the archive is the clock

**Teaches you:** that an archive's physical layout can set the pace of a program: tar's checkpoints are a clock, and each tick moves a state machine by one step.

> **DEMO ONLY.** Fictional time cards, written to a scratch SQLite file under `$XDG_DATA_HOME/TarGnuWeird/`.
> Nothing here touches real time reporting.

GNU tar can run a command every N records while it works (`--checkpoint=N --checkpoint-action=exec=...`). It exists to show progress. Here it is the program's clock. **One checkpoint is one hour of work.** A small state machine takes one step per tick: it works one hour on the open card, closes the card when the hours are used up, draws the next card's length, and sets a flag when the total passes 40. Nothing else moves it forward. No loop calls the tick. If tar writes no records, no hours pass.

```text
$ sh run-clock.sh --seed 42
# DEMO ONLY run 1: seed 42; layout 64 records in 1 member(s); tar -b 1 --checkpoint=1
Meetings	12	12	2026-W47	DEMO ONLY
Coding	17	29	2026-W47	DEMO ONLY
Debugging	17	46	2026-W47	DEMO ONLY
# committed total=46 entries=3 DEMO ONLY
# clock: last tick 64, idle ticks after the stop 18, tape 32768 bytes
```

This is the **weird** entry of a pair. Its ordinary partner, [`tar-gnu`](../tar-gnu/README.md), uses tar's *member traversal* to run a serialized program. This one ignores what the members say and uses only *how many records tar writes*. The first is about what a layout **means**. This one is about **when** it happens.

## Run it

You need **GNU tar** (1.34 and 1.35 were tested), a POSIX shell, `od`, `mktemp`, `date` and `sqlite3`.

```bash
cd src/tar-gnu-weird
sh timecards.sh                       # run the demo (SEED=42 sh timecards.sh replays one exact run)
sh run-clock.sh --ticks 30            # a shorter archive: the clock runs out before the run ends (exit 3)
sh run-clock.sh --interval 2 --ticks 128    # tar ticks every 2nd record: 128 records, 64 ticks
sh run-clock.sh --blocking 4 --ticks 260    # tar -b 4: 65 records, so 65 ticks
./check.sh                            # every rule below, and the prediction tests
```

Records go to `$XDG_DATA_HOME/TarGnuWeird/demo-timecards.db` (default `~/.local/share/TarGnuWeird/`). The archive that tar wrote stays next to it as `tape.tar`.

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker).

```bash
sandbox/container/run-image.sh src/tar-gnu-weird
```

It builds this folder's [`Dockerfile`](Dockerfile) and runs the result with no network, a read-only file system and user `nobody`. The image holds GNU tar (from the Ubuntu base) and sqlite3 on a minimal Ubuntu.

## How the stunt works

### The clock

[`run-clock.sh`](run-clock.sh) lays out a payload, makes a machine, and runs **one** `tar` command:

```sh
tar --format=ustar -b 1 --checkpoint=1 --checkpoint-action="exec=sh .../tick.sh" -cf tape.tar -T list
```

With `-b 1` a *record* is one 512-byte block, and `--checkpoint=1` means "every record". So tar runs `tick.sh` once for every 512 bytes it writes. tar sets `TAR_CHECKPOINT` to the number of records so far, and ignores the command's exit status.

### The machine

[`tick.sh`](tick.sh) runs [`tick.sql`](tick.sql), which is one transition. The whole state is one row in a table called `fsm`:

| Register | Meaning |
|---|---|
| `seed` | Generator state (Park-Miller, 48271 and 2147483647) |
| `card` | Cards closed so far. It picks the category: Meetings, Coding, Debugging, Learning, Meetings |
| `worked`, `target` | Hours worked on the open card, and how long it will take (10 to 19) |
| `total` | The running total |
| `done` | Set when a closed card pushed the total over 40 |
| `tick`, `idle` | The last `TAR_CHECKPOINT`, and how many ticks arrived after `done` |

One tick does four things in one transaction: (1) if `done`, count an idle tick and stop; (2) otherwise work one hour; (3) if `worked = target`, write the card; (4) then close it: next category, draw the next length, and set `done` if the total is over 40. The stop rule is that last `done = total > 40`, and it runs *after* the card is written, so the crossing card is kept.

| Job | Done by |
|---|---|
| Time passing, and the loop | **tar's checkpoints**: one callback per record written |
| What one step does | `tick.sql`: one transaction |
| Random hours | The generator in `fsm.seed`, one draw per closed card |
| Stop rule | `done`, set by the transition that closes the crossing card |
| After the stop | Ticks go on (tar does not stop) and only increase `idle` |
| Persistence | `sqlite3`, with `CHECK` constraints |

### The layout sets the pace

How many ticks exist is decided by the archive, not by the program. For a create command, with `b` the blocking factor and `K` the checkpoint interval:

```text
blocks = sum over members of (1 header + ceil(size / 512) data blocks) + 2 end-of-archive blocks
records = ceil(blocks / b)
ticks   = floor(records / K)
```

[`layout.sh`](layout.sh) writes zero-filled members so that the archive has the number of blocks you ask for. A run needs between 41 and 59 ticks: the total must pass 40, so it is at least 41, and the longest run ends at 40 + 19 = 59. The default is 64 ticks. Ask for fewer and the machine **stalls**: the clock runs out in the middle of a card, the run prints what it has, says `the clock ran out` and exits 3. `check.sh` does not hope for this. It predicts it.

### Prediction, not observation

`check.sh` contains a second implementation of the machine, in awk: the same generator, one loop over ticks. For five seeds and thirteen layouts (20 to 260 blocks, blocking factors 1 to 8, checkpoint intervals 1 to 5, one to seven members) it works out which cards must exist when the clock stops, and whether the run finishes or stalls. Then it runs the entry and compares. It also checks the tape size (whole records) and the last `TAR_CHECKPOINT`, which is `ticks × K`.

## It's just a tar archive, but its layout is the program's schedule

In [`tar-gnu`](../tar-gnu/README.md#its-just-a-tar-file-serialization-deserialization-and-execution) the *content* of the archive is the program, and the order of the members is the order of execution. Here the payload is zeros. The program is the machine in `tick.sql`, and the archive only decides **when** each step runs. That is a second thing a serialized layout can do: it influences when events happen, as well as what they mean. A longer archive means more ticks. A bigger blocking factor means fewer. Change the layout and the schedule changes, with the same bytes of "program".

## Why this is weird

Checkpoints are a progress indicator. Nobody designed them as a scheduler. Using them as one turns tar into an event source: **control flow is inverted**. The usual program calls tar. Here tar calls the program, once per record, and the program has no loop of its own. It is a callback in an event-driven design, and the clock is the thing that makes it go.

## What `check.sh` enforces

`check.sh` needs GNU tar and sqlite3.

- **The constraint is real.** The only loop in `run-clock.sh` and `tick.sh` is the argument parser. There is exactly one `tar` command, the tick is its checkpoint action, and it only creates. `tick.sql` has no recursion, no triggers and no random function.
- **The rules of the challenge.** 20 random runs: categories in order, hours 10 to 19, correct totals, a stop at the first total over 40 with the crossing card kept, `DEMO ONLY` everywhere, an empty stderr, a removed scratch folder, and at least eight different hour values overall.
- **The clock invariants.** Each card is closed at the tick whose number is its running total. The default run sees 64 ticks, and every tick after the stop is counted as idle.
- **No clock, no progress.** With `--checkpoint=1000` on a 64-record archive there is no tick. No card is written, the state stays at zero, and the run exits 3.
- **Predictions.** 65 runs compared with the simulation (see above), including the stalls, and the tape size.
- **Extra ticks change nothing.** A 600-record archive gives the same cards as a 64-record one.
- **What one checkpoint counts.** In create mode, `floor(ceil(blocks / b) / K)`, for ragged sizes, empty members and five pairs of `b` and `K`.
- **A failing callback.** A copy of the entry whose transition fails on every tick: tar still finishes, no card is written, the SQL error reaches stderr, and the run exits 3.
- **A bad `TAR_CHECKPOINT`.** A value that is not a number is refused before the database is opened.
- **The schema.** SQLite refuses a non-demo row, 9 hours and a fifth category.

## Gotchas worth knowing

- **What GNU tar promises, and what we saw.** The manual documents `--checkpoint=N`, `--checkpoint-action=exec=COMMAND` and the `TAR_CHECKPOINT` variable. That is **implementation-permitted**: GNU only, and not in POSIX. It also says a checkpoint counts *records*. How many records a command writes for a given set of members is what we measured, on GNU tar 1.34 (Ubuntu 22.04) and 1.35 (Ubuntu 24.04 and 26.04), and the numbers were the same everywhere.
- **A checkpoint counts records, not files.** With `-b 1` a record is 512 bytes. The default is `-b 20`, so a record is 10,240 bytes and the whole demo archive would be three records. That is why the entry sets `-b 1`.
- **`TAR_CHECKPOINT` counts records, the machine counts callbacks.** With `--checkpoint=2` the variable reads 2, 4, 6, and so on, and the machine still adds one hour per call. The entry therefore counts calls, and stores the variable only as a record of where each card closed.
- **The mode changes the count.** Creating the same 21-block archive gives 21 ticks. Listing it with `-t` gives 10, because tar skips over data it does not need to read. Extracting it gives 21 again. Only creation is used here, and it is the mode with the simplest rule. Treat the listing number as **accidentally exploited** knowledge, not as a promise.
- **The callback's exit status is ignored.** A command that exits with status 7 leaves tar's own status at 0. We saw this on every release we tried. The entry does not rely on it: tar cannot be told to stop, so the machine makes the extra ticks harmless, and a failed tick only means that the machine did not move.
- **tar does not stop at the stop rule.** After the crossing card tar still writes all its records, and the callback still runs for each. The 18 idle ticks in the example are those. This is why the design has a `done` flag, and does not try to kill tar.
- **Where a failed tick shows.** If `tick.sql` fails, SQLite's message goes to stderr, tar carries on, and the run ends with `the clock ran out` and exit 3.
- **Not a recursive tar.** The checkpoint command is `sh tick.sh`, and it runs one `sqlite3`. It never starts another `tar`.
- **It is slow on purpose.** About 64 ticks, one `sqlite3` start per tick: a few tenths of a second. Do not use a checkpoint as a scheduler.
- **The producer.** The tape here is made by `layout.sh`. `tar-gnu` could write it instead, but then each demo would depend on the other in CI, and the entry would have to read a program it does not use. The two entries stay independent.

---

See the [root README](../../README.md#the-results-so-far) for how this compares to the other entries, and [`CHALLENGE.md`](../../CHALLENGE.md) if you want to write your own.
