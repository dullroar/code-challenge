---
name: "ed"
teaches: "that a line editor is a rewriting machine: lines are the data, addresses are the program, and a failed substitution inside a global command is an \"if\"."
kind: weird
languages: [ed, sqlite]
lesson: "languages/editors.md#the-buffer-is-the-machine"
loop-by: rewrite-and-rescan
evaluation: rewriting
assurance: accidentally-exploited
pairs-with: ex-weird
machine: "A string-rewriting machine with line addresses"
state: "The editor buffer: one line per card, and marks (x) that are added by joining lines"
tags: [capability-security, computation-versus-orchestration, hyrums-law, language-specification, markov-algorithm, portability, regular-expression, state, state-encoding, term-rewriting, transition-system, weird-machine]
---
# ed: the buffer is the machine

**Teaches you:** that a line editor is a rewriting machine: lines are the data, addresses are the program, and a failed substitution inside a global command is an "if".

> **DEMO ONLY.** Fictional time cards, written to a scratch SQLite file under `$XDG_DATA_HOME/EdWeird/`.
> Nothing here touches real time reporting.

The program is a file of about 45 `ed` commands. `ed` is the 1970s line editor that `sed`, `vi` and `grep` come from. It has no variable, no arithmetic and no loop statement. The only thing it does is change lines of text. This entry makes it generate time cards anyway. The buffer holds five random digits when `ed` starts. When `ed` ends, the buffer holds the rows.

```text
$ DICE="7 3 9 0 5" ed -s dice.txt < timecards.ed
Meetings 17 17
Coding 13 30
Debugging 19 49
```

Its partner, [`ex-weird`](../ex-weird/README.md), uses the richer language that `vi` is built on: registers, marks and `@`. Here every number is made by writing marks (`x`) next to each other and by rewriting text. A launcher gives `ed` its five digits and stores the rows afterwards. It does no arithmetic.

## Run it

You need **GNU ed** (1.20.1 was tested), a POSIX shell, `tr`, `head`, `fold`, `date` and `sqlite3`.

```bash
cd src/ed-weird
sh timecards.sh                          # run the demo
DICE="7 3 9 0 5" sh timecards.sh         # force the five dice (digits 0-9; the hours are 10 plus the digit)
printf '7\n3\n9\n0\n5\n' > /tmp/dice.txt; ed -s /tmp/dice.txt < timecards.ed    # run only the ed program
./check.sh                               # every rule below
```

Records go to `$XDG_DATA_HOME/EdWeird/demo-timecards.db` (default `~/.local/share/EdWeird/`).

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker).

```bash
sandbox/container/run-image.sh src/ed-weird
```

It builds this folder's [`Dockerfile`](Dockerfile) and runs the result with no network, a read-only file system and user `nobody`. The image holds GNU ed and sqlite3 on a minimal Ubuntu.

## How the stunt works

Read [`timecards.ed`](timecards.ed) from top to bottom. It has six steps.

| Step | What `ed` does | Which ed feature does the work |
|---|---|---|
| 1. Categories | `1s/^/Meetings /`, `2s/^/Coding /`, and so on | **Addresses.** Line 1 is the first card. The order of the categories is the order of the line numbers |
| 2. Hours | `g/x7$/s/7$/xxxxxxx/`: ten rules, one per digit | **A rewrite table.** The digit 7 becomes the hours `17` and seventeen marks (ten, plus seven) |
| 3. The ledger | `0a`, then `Start 0\|` | **Text input.** A line above the first card that says "the total so far is nothing" |
| 4. The run | One `g` command over the card lines | **The global command.** The only loop in the program, and it is ed's own |
| 5. Cleanup | `g/^Dead /d`, `g/^Start /d` | **Deleting lines** that match a pattern |
| 6. Decimals | `g/[\|!]x\{50\}/s/[\|!]x\{50\}/ 5/`, and so on | **A rewrite table** again: fifty marks become the digit 5 |

### Step 4: the run

For every card line, in buffer order, ed does five things (they are the lines of the global command's list):

1. `-t.` copies the line above (the ledger so far) to just under the card.
2. `-,.j` joins the card and the copy into one line: `Coding 15 xxxxxxxxxxxxxxxMeetings 12|xxxxxxxxxxxx`.
3. A substitution keeps the card's name and hours and puts the two sets of marks together after a bar: `Coding 15|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`. **Adding is writing marks side by side.** Each processed card is the ledger for the next one.
4. A second substitution handles a ledger that has a `!` instead of a `|`. The `!` means that the total already passed 40. The card becomes `Dead 0!` plus the same marks, so that every later card dies too.
5. A third substitution fires when there are 41 or more marks after the bar: `s/^\([^|]*\)|\(x\{41,\}\)$/\1!\2/`. The bar becomes `!`. **That is the stop rule.** It runs *after* the card is written, so the crossing card is kept.

### Why there are no `if` commands

`ed` has no `if`. It has something just as good. **A substitution that finds nothing to replace does nothing, and does not stop the global command.** That is true inside `g`: `s/a/b/` on a line without an `a` is silently skipped. So `s/needs this/becomes this/` means "if the line has the pattern, rewrite it". The three substitutions above are three guarded rewrites, and in each card only the ones that apply fire. A failed *address* (`/nomatch/`) is different: that is an error, and it stops the command list. The entry uses the first kind and never the second.

| Job | Done by |
|---|---|
| Loop | `g/...`: one global command over the card lines |
| Category order | Line addresses (`1s`, `2s`, ...) |
| Random hours | The launcher gives ed five digits. ed turns each into 10 + the digit as text |
| Running total | Joining lines: marks side by side |
| Stop rule | `x\{41,\}`: a regular expression over the marks |
| Output | `,p`, after the rewrite rules of step 6 |
| Persistence | `sqlite3`, with `CHECK` constraints |

The launcher, [`timecards.sh`](timecards.sh), has four jobs: five random digits (`tr` from `/dev/urandom`), run `ed`, load the rows into SQLite with the week, and show them. It has no arithmetic, no `awk`, no `sed` and no loop. `check.sh` makes sure of that.

## Why this is weird

`ed` was made to edit files by hand over a slow teleprinter. Its commands are terse so that you can type fewer characters. Using it as a computer means that you treat the commands as a **rewrite system**: rules on text that fire when their pattern matches. This is the same idea as [`regex-sed`](../regex-sed/README.md), which has `sed` rewrite one line until no rule applies. The difference is the control. `sed` has a branch command and a loop. `ed` has neither, so every repeat has to come from the global command, and every choice from a substitution that may or may not match.

## What `check.sh` enforces

`check.sh` needs GNU ed and sqlite3.

- **The constraint is real.** `timecards.sh` has no arithmetic, no `awk`, no `sed`, no `expr` and no loop, and starts `ed` once. `timecards.ed` has no shell escape (`!`) and no file command (`r`, `w`, `e`, `f`). One global command is the run.
- **The rules of the challenge.** 25 random runs: categories in order, hours 10 to 19, correct totals, a stop at the first total over 40 with the crossing card kept, `DEMO ONLY` everywhere, an empty stderr and no scratch left behind.
- **An independent simulation.** A separate model (a short awk program) says which rows each dice sequence must give. The entry must agree on all 1,024 sequences over the digits 0, 4, 5 and 9, which include totals of exactly 40 and 41, and 400 random ones.
- **Perturbations.** A copy of the program with `x\{41,\}` changed to `x\{31,\}` stops after 30 instead of 40. A copy with `{51,}` stops after 50. A copy with the first two category lines swapped has the first two categories swapped. A copy without the `Dead` rule keeps cards after the crossing one. A copy without the cleanup prints `Dead` rows. The stop rule is in the ed program, and nowhere else.
- **Walls.** A global command inside a global command is refused (`Cannot nest global commands`). A blank line in an ed script is a command and not a separator, so the program uses `#` comments. A failed `s` inside `g` is silent, and a failed address is an error with exit status 1.
- **Another ed.** busybox `ed` (in the sandbox image) cannot run the program, and the check asserts that.
- **The schema.** SQLite refuses a non-demo row, 9 hours and a fifth category. The launcher refuses four dice and a non-digit.

## Gotchas worth knowing

- **GNU ed only.** We tested GNU ed 1.20.1. The program uses `#` comments, `s/^/.../`, back-references, `\{n,\}` intervals and `0a`. POSIX specifies most of these, but busybox ed 1.36.1 (in the check image) has none of `t`, `m`, `j`, `g`, `v` or `Q`, has no `#` comments, and cannot substitute on `^`, on a group or on an interval. So it cannot run the program, and the check says so. This is **implementation-permitted**.
- **The silent failed `s` is accidentally exploited.** The GNU manual says that the command list "stops on the first error" and does not say that a failed substitution inside it is not an error. It is not one, on 1.20.1. Without that, there is no `if`. (The manual's `-l` option, "exit with 0 status even if a command fails", mentions a substitution that finds nothing as an example of a failure, at the top level. The check script confirms that exit status is 0 here.) Do not count on this in another ed.
- **A blank line is a command.** An empty line means "print the next line", and it errors at the end of the buffer. This is why the program uses `#` lines to separate its steps.
- **ed writes its errors to standard output.** With `H` as the first command, a failed command prints `?` and then a reason. Both go to stdout, so the launcher checks ed's exit status (1 on an error), and a stray `?` in the rows would fail the database load.
- **`Newline appended` goes to stdout, too.** If the buffer file does not end with a newline, ed says so on stdout even with `-s`. The launcher adds the newline.
- **GNU ed allows `!` in a command list. We do not use it.** The manual says "any commands are allowed, except `g`, `G`, `v` and `V`", so a shell escape would work inside a global list. Using one would turn this into a shell program. The check forbids it.
- **Positions matter.** `-t.` and `-,.j` reach the ledger by position: it is the line directly above the card. If anything put another line between them, every total would be wrong. This is why the ledger line is created before the run starts, and why dead cards stay in place until the cleanup.
- **Unary is slow.** Totals are strings of up to 59 marks. A million would be a million characters.
- **The dice are the launcher's.** Randomness is the one thing ed cannot do, so it is the one thing the launcher does.

---

See the [root README](../../README.md#the-results-so-far) for how this compares to the other entries, and [`CHALLENGE.md`](../../CHALLENGE.md) if you want to write your own.
