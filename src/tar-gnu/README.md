---
name: "GNU tar"
teaches: "that a tar archive can be a serialized program: tar reads the members in order, and only the command that the operator attaches gives them an effect."
kind: idiomatic
languages: [tar, sqlite]
lesson: "languages/tar.md#a-program-that-is-an-archive"
loop-by: document-order
evaluation: eager
assurance: implementation-permitted
pairs-with: tar-gnu-weird
machine: "A tape reader (tar) feeding a five-word interpreter"
state: "The archive's members, which are the program, plus one SQLite row that says whether the run has halted or faulted"
tags: [arbitrary-code-execution, capability-security, computation-versus-orchestration, domain-specific-language, exit-status, idempotence, integrity-constraint, interpreter-and-virtual-machine, langsec, least-privilege, observability, parsing, reproducibility, serialization-deserialization-pickling, state-encoding, threat-model, transition-system]
counterexamples: [continuation]
---
# GNU tar: it's just a tar file

**Teaches you:** that a tar archive can be a serialized program: tar reads the members in order, and only the command that the operator attaches gives them an effect.

> **DEMO ONLY.** Fictional time cards, written to a scratch SQLite file under `$XDG_DATA_HOME/TarGnu/`.
> Nothing here touches real time reporting.

The program is a tar archive. Each member is one instruction: the member name says what to do, and the member body says with what. GNU tar walks the archive in order and calls a small dispatcher for every member (`tar --to-command=...`). The dispatcher knows what five words mean. It has no loop, no dice, no category list and no number 40. Those are in the archive.

```text
$ tar -tvf program.tar
-rw-r--r-- 0/0   41 ... 000.begin
-rw-r--r-- 0/0   27 ... 010.card
-rw-r--r-- 0/0    9 ... 011.stop-over
 ...
-rw-r--r-- 0/0    0 ... 990.show

$ sh interpret.sh --execute program.tar
# DEMO ONLY run 1
Meetings	13	13	2026-W47	DEMO ONLY
Coding	11	24	2026-W47	DEMO ONLY
Debugging	13	37	2026-W47	DEMO ONLY
Learning	15	52	2026-W47	DEMO ONLY
# committed total=52 entries=4 DEMO ONLY
```

This is the **idiomatic** entry of a pair. Using `--to-command` is the documented way to feed archive members to a program, so the mechanism is ordinary. The odd part is the application: a time-card generator that is an archive. Its pair, [`tar-gnu-weird`](../tar-gnu-weird/README.md), uses a different tar feature (checkpoints) as a clock.

## Run it

You need **GNU tar** (1.35 was tested), a POSIX shell, `od`, `mktemp`, `date` and `sqlite3`. BSD and macOS tar have no `--to-command`.

```bash
cd src/tar-gnu
sh timecards.sh                     # build the archive, list it, inspect it, run it
SEED=42 sh timecards.sh             # replay one exact program (the seed is stored in the archive)
sh build-archive.sh --seed 7 --hours "12 14 19 10 10" program.tar   # write an archive with chosen hours
sh inspect.sh program.tar           # READ the program. Runs nothing from it.
sh interpret.sh --execute program.tar   # RUN the program. The flag is required.
./check.sh                          # every rule below
```

Records go to `$XDG_DATA_HOME/TarGnu/demo-timecards.db` (default `~/.local/share/TarGnu/`), and the archive stays next to it as `program.tar`, so you can open it.

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker).

```bash
sandbox/container/run-image.sh src/tar-gnu
```

It builds this folder's [`Dockerfile`](Dockerfile) and runs the result with no network, a read-only file system and user `nobody`. The image holds GNU tar (from the Ubuntu base) and sqlite3 on a minimal Ubuntu.

## How the stunt works

The archive is the program, tar is the loop, and the dispatcher is the machine that gives five words their meaning.

```text
000.begin      format=tarprog/1, seed=N, label=DEMO ONLY     start a run
010.card       category=Meetings, hours=13                  add a card
011.stop-over  limit=40                                     halt if the total is over 40
020.card       category=Coding, hours=11
021.stop-over  limit=40
 ...           (five card slots in all)
990.show       (empty)                                      print the rows
```

| Job | Done by |
|---|---|
| Loop | **tar**, walking the members in archive order |
| Category order | **The archive**: card slots in the order Meetings, Coding, Debugging, Learning, Meetings |
| Random hours | **The builder**, once, when it writes the program down. It uses a seeded Park-Miller generator, and the seed is stored in `000.begin` |
| Running total | The meaning of `card`: add the hours to the last total (one SQL statement) |
| Stop rule | **The archive** carries the limit (`limit=40` in each `stop-over` member). The meaning of `stop-over` is "halt if the total is over the limit". A halted run ignores the rest |
| Output | The meaning of `show` |
| Persistence | `sqlite3`, with `CHECK` constraints for the category, the hours and `DEMO ONLY` |

Why five card slots? Four cards of 10 hours make exactly 40, which does not exceed 40. A fifth card always finishes the job, so five slots are enough for every possible run. A run usually stops at three or four cards, and the unused slots are read and ignored (the `trace` table says `ignored: halted`).

### The dispatcher

[`dispatch.sh`](dispatch.sh) is the interpreter. It is about 80 lines, and most of those lines check that the input is what it claims to be. It has four jobs:

1. Check the member name against a strict pattern. Four names are known: `NNN.begin`, `NNN.card`, `NNN.stop-over` and `NNN.show`.
2. Check the member body: right lines, right words, hours from 10 to 19.
3. Run one SQL statement.
4. Record what happened in a `trace` table.

`check.sh` makes sure the dispatcher has no `for`, `while`, `until`, `eval` or `exec`, no shell arithmetic, no dice and no `40`.

### The builder, the inspector and the interpreter

Three small programs use the same archive:

- [`build-archive.sh`](build-archive.sh) **serializes** the program. The same seed makes the same bytes, because it fixes the order, the times and the owners.
- [`inspect.sh`](inspect.sh) **reads** it. It uses `tar -t` and `tar -xO` (extract to standard output), and it never runs anything from the archive. It has its own check of the record grammar, written differently from the dispatcher's, so `check.sh` can compare the two.
- [`interpret.sh`](interpret.sh) **runs** it. You must pass `--execute`. It first asks the inspector to vet the whole archive, and only then starts `tar --to-command`.

## It's just a tar file: serialization, deserialization, and execution

A tar archive is a way to write files into one stream of bytes. It is not a program format. What turns this one into a program is a *consumer* that gives its members a meaning. This section separates the steps. See the concept page, [Serialization, deserialization and object pickling](../../lessons/cs/06-state-beyond-variables.md#serialization-deserialization-and-object-pickling), for the general ideas.

1. **Encoding data.** A card is two lines in a member body: `category=Coding` and `hours=11`. The data is in the bytes of the member.
2. **Encoding program instructions and interpretation context.** The instruction is in the member *name* (`010.card`), and the order of the members is the order of execution. The context is a promise between the writer and the reader: the format `tarprog/1`. Tar knows nothing about it. Two programs that agree on the promise can understand each other, and no other program can.
3. **Encoding program state.** The archive holds the *initial* state: the seed, and the dice already rolled. The *running* state (the total so far, and whether the run has halted) is in SQLite. It is not in the archive, and tar never changes the archive while it reads it.
4. **Capturing live execution state or continuations.** This entry does **not** do that. If you kill the interpreter after the second card, nothing can resume it from the third. You could start the whole program again. That gives the same cards (replay), and it is not the same as continuing the interrupted process.
5. **Pickling versus tar.** Python's `pickle` stores a *recipe to rebuild objects*, and unpickling calls whatever the recipe names. Tar stores *files*, and extracting writes files. Both are serialization. Deserialization (parsing the bytes into pieces) and execution (giving the pieces an effect) are two different steps. Pickle joins them by design. Here you can do the first without the second: `inspect.sh` parses and shows every member, and runs nothing.
6. **How a malicious consumer turns inert bytes into instructions.** The bytes have no power. The consumer does. A dispatcher that passed the body of `010.card` to a shell would make every card a command. This one does not. It checks every record with a strict pattern, and it does not pass any part of a record to a shell or an interpreter. `check.sh` builds archives with `$(touch ...)` inside the hours and a member called `030.exec`, and shows that none of them runs.
7. **Two trust boundaries.** `tar -xf program.tar` writes the members as files and runs nothing. An archive **cannot register a hook for itself**. The power comes from the command line: `--to-command=...` is the operator's choice, and tar asks nothing of the archive. So the boundary is at the command the operator types, and it is the same trust you give to any program you start.

### Four kinds of "the same"

| Kind | Claim in this entry | How `check.sh` tests it |
|---|---|---|
| Byte for byte | The same seed gives the same archive bytes | `cmp` of two builds |
| Structure and state | The cards the inspector decodes are the cards the database holds | compare the two lists |
| Behavior | One archive run in two fresh databases gives the same cards | compare the rows |
| Live process | **Not claimed** | A second run into the same database makes a second run, and nothing resumes anything |

The replay is also **not idempotent**: running the same archive twice into one database adds a second run with the same cards. Deterministic replay and idempotence are different properties.

## Why this is idiomatic

`--to-command` is in the GNU tar manual, under "Extracting Files to a Program". It exists for jobs like piping each member through a filter. This entry uses it as documented: one process per regular member, the member bytes on standard input, the member's details in `TAR_*` environment variables. What is unusual is not the mechanism. It is using an archive as a program, with the interpreter attached by the person who runs it.

## What `check.sh` enforces

`check.sh` needs GNU tar and sqlite3.

- **The constraint is real.** `dispatch.sh` has no `for`, `while`, `until`, `eval` or `exec`, no shell arithmetic, no random source and no `40`. `inspect.sh` has no `--to-command`, no `sqlite3` and no `eval`.
- **The rules of the challenge.** 25 random runs: categories in order, hours 10 to 19, correct running totals, a stop right after the first total over 40 (the crossing card is kept), `DEMO ONLY` on every row, SQLite rows that match the printed ones, an empty stderr, and at least eight different hour values overall.
- **Forced dice.** Seven programs with chosen hours, compared with a separate simulation. A total of exactly 40 must continue. The unused cards must show as `ignored: halted` in the trace.
- **Four kinds of "the same".** See the table above.
- **Agreement.** The inspector, `tar -t` and the dispatcher's own trace list the same twelve members in the same order.
- **Passive consumers.** `tar -t`, plain `tar -xf` and the inspector run nothing from a hostile archive. The test uses canary files, and shim versions of `sqlite3` and `date` that fail the test if anything calls them.
- **Fail closed.** No `--execute`, no run. A hostile archive is refused by the preflight before anything starts. With the preflight bypassed (`tar --to-command` called directly), the dispatcher refuses the bad record **and everything after it**, and tar's exit status is not zero. Each of these bad members is refused: hours below 10, hours above 19, hours with a command in them, an unknown category, an extra line, a bad name, a name with a path, an oversize body and an unknown record type. The inspector also flags a directory and a symlink member.
- **The schema.** SQLite refuses a non-demo row, 9 hours and a fifth category.

## What you can learn

- **Data is not code until a consumer says so.** The same bytes are a listing, a set of files, or a program, depending on the command.
- **Parse first, run second.** A passive reader of the same format lets you review a program before you run it.
- **Fail closed.** An unknown record is an error. It is not skipped, and it is not guessed.
- **Say which "same" you mean.** Bytes, structure, behavior and a live process are four different promises.
- **A format is a contract between two programs.** Tar did not define `tarprog/1`. The builder and the dispatcher agreed on it, and nothing but a test keeps them in step.

## Gotchas worth knowing

- **GNU only.** `--to-command` is a GNU extension, and so is `--occurrence`, which the inspector uses. Both are **implementation-permitted**: the GNU manual documents them, and POSIX tar does not have them. We tested only GNU tar 1.35.
- **tar does not stop when the command fails.** We tried it. The child's status is reported (`Child returned status 1`), tar keeps reading, and in the end it exits with status 2. That is why the dispatcher writes `faulted` to the database and refuses every later member itself. The halt is the interpreter's, and it is **not a tar guarantee**.
- **Which members reach the command.** Only regular files. Directories, symlinks and hard links do not. A hard link to an earlier member is silently skipped, not run twice. The inspector reports non-file members, and the preflight refuses them.
- **Duplicate names run twice, in order.** Tar does not de-duplicate. The inspector uses `--occurrence=N` so it can show each one.
- **tar protects you from `..`.** A member called `../x` is refused by tar itself ("Member name contains '..'") before any command runs. A member name with a newline in it is passed on, so the dispatcher matches names with a pattern that cannot match it.
- **The variable is `TAR_FILETYPE`.** Not `TAR_TYPE`. On 1.35 the dispatcher reads `TAR_FILENAME` and `TAR_SIZE`. A pax archive also adds `TAR_ATIME` and `TAR_CTIME`, so this entry writes `ustar` archives. That keeps the bytes reproducible.
- **The dice are rolled at build time.** The archive holds all five cards, and the unused ones were also rolled. If you want the dice rolled while the program runs, the interpreter would need a random source, and the point of this entry is that it has none.
- **A short run wastes slots.** The shortest legal run is three cards (19 + 19 + 19). The last two slots are then read and ignored.
- **SQLite is plumbing.** The `card` statement does one addition in SQL. That is the meaning of `card`, and it is the one place arithmetic lives. The stop test lives in `stop-over`, and its limit comes from the archive.

---

See the [root README](../../README.md#the-results-so-far) for how this compares to the other entries, and [`CHALLENGE.md`](../../CHALLENGE.md) if you want to write your own.
