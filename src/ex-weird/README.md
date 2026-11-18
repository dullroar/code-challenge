---
name: "Ex"
teaches: "that an editor's registers can hold a program: a line of text is copied into a register and run with @, and the editor's own marks and line addresses do the arithmetic."
kind: weird
languages: [ex, sqlite]
lesson: "languages/editors.md#a-program-you-can-edit"
loop-by: self-modifying-control
evaluation: eager
assurance: implementation-permitted
pairs-with: ed-weird
machine: "A register machine whose registers are editor marks, and whose program is a register that runs itself"
state: "The marks (where we are on a tape of numbered lines), the first line of the buffer (the next card), and registers a, d and n"
tags: [homoiconicity, language-specification, portability, program-counter, reflection-and-metaprogramming, register-machine, self-modifying-code, state, state-encoding, weird-machine]
---
# Ex: a program you can edit

**Teaches you:** that an editor's registers can hold a program: a line of text is copied into a register and run with @, and the editor's own marks and line addresses do the arithmetic.

> **DEMO ONLY.** Fictional time cards, written to a scratch SQLite file under `$XDG_DATA_HOME/ExWeird/`.
> Nothing here touches real time reporting.

`ex` is the command language of the `vi` editor. It is a line editor like [`ed`](../ed-weird/README.md), with extra powers: **named registers** that hold text, an **`@` command that runs a register as Ex commands**, **marks** that remember a line, and several commands on one line, separated by bars. This entry uses those powers to build something that `ed` cannot: a program that is stored as text, copied into a register, and run, and that decides its own next step by copying a line of *data* into a register and running that too.

```text
$ ex -s dice.txt < timecards.ex
Meetings 17 17
Coding 13 30
Debugging 19 49
```

There is no global command in the program, no regular expression test, no loop statement and no error. The loop is a register that runs itself.

## Run it

You need an **Ex**: **nvi** (a 4.4BSD POSIX ex/vi; 1.81.6 was tested, and it is what the sandbox has) or **Vim** in Ex mode (9.1 was tested). Ubuntu's own `ex` is Vim. You also need a POSIX shell, `tr`, `head`, `fold`, `date` and `sqlite3`.

```bash
cd src/ex-weird
sh timecards.sh                          # run the demo (the launcher finds out which ex you have)
DICE="7 3 9 0 5" sh timecards.sh         # force the five dice (digits 0-9; the hours are 10 plus the digit)
EX=nex sh timecards.sh                   # pick the editor: nex is nvi's ex
printf '7\n3\n9\n0\n5\n' > /tmp/dice.txt; ex -s -u NONE /tmp/dice.txt < timecards.ex      # only the program; with nvi: ex -s
./check.sh                               # every rule below, against the ex you have
```

Records go to `$XDG_DATA_HOME/ExWeird/demo-timecards.db` (default `~/.local/share/ExWeird/`).

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker).

```bash
sandbox/container/run-image.sh src/ex-weird
```

It builds this folder's [`Dockerfile`](Dockerfile) and runs the result with no network, a read-only file system and user `nobody`. The image holds nvi and sqlite3 on a minimal Ubuntu.

## How the stunt works

Read [`timecards.ex`](timecards.ex) from top to bottom. Its comments say what each part does.

### The registers are marks

`ed` keeps its state in the *text* of the buffer. Ex also has state outside the text: **marks**. `k t` puts a mark called `t` on a line, and `'t` is that line as an address. The mark follows its line when lines above it are added or removed. Address arithmetic works on marks, so `'t+17` is "seventeen lines below mark `t`". The command `'t+17k t` puts the mark there. That is **t = t + 17**, with no number anywhere except in the text of the address.

### The tape

Under the five cards the program adds a tape of sixty lines. A line is `total instruction`:

```text
0 @a
1 @a
...
40 @a
41 "
42 "
...
59 "
```

The position of mark `t` on the tape *is* the running total. The text of the line under it is the total as decimal digits, and a *next instruction*. Up to 40 the instruction is `@a`: go on. Above 40 it is a quote mark, which Ex reads as a comment: do nothing. **The limit of 40 is the place where `@a` stops on the tape.** Nothing in the program says "40".

### The program

The program is one line of text. The script adds it to the buffer after the tape, copies it into register `a` (`'s+1ya a`), and removes it (`'s+1d`). Then `@a` runs it. The bars are line breaks. In order:

| Step | What it does |
|---|---|
| `1t$` | Copy the first card, `Meetings 7`, to the end of the buffer |
| `$s/^.* \([0-9]\)$/'t+1\1k t/` | Rewrite the copy into a *command*: `'t+17k t`. The card's digit became text that Ex can run |
| `$ya d`, `$d` | Copy the command into register `d`, and remove it from the buffer |
| `1s/ \([0-9]\)$/ 1\1/` | Turn the digit of the card into hours: `Meetings 17` |
| `@d` | **Run register `d`.** Mark `t` moves 17 lines down the tape. This is the addition |
| `1t$`, `'tt$`, `$s/ .*$//`, `$-1,$j`, `$p` | Copy the card. Copy the tape line under mark `t`. Keep only its total. Join the two (Ex's join puts a space between them). Print the row: `Meetings 17 17` |
| `'tt$`, `$s/^[0-9]* //`, `$ya n`, `$d` | Copy the tape line again. Keep only its *instruction*. Copy it into register `n` |
| `1d` | The card is used up. The next card is now line 1 |
| `@n` | **Run register `n`.** On the tape it says `@a`, so the program runs again. Above 40 it says `"`, and nothing runs |

| Job | Done by |
|---|---|
| Loop | Register `n` holds `@a`, so the program calls itself |
| Category order | Line addresses (`1s`, `2s`, ...), as in the ed entry |
| Random hours | The launcher gives Ex five digits. A substitution makes each into a command |
| Running total | The mark `t`, moved by a command that the program wrote itself |
| Decimal total | The text of the tape line under the mark |
| Stop rule | The tape: the first line whose instruction is a comment |
| Output | `$p` |
| Persistence | `sqlite3`, with `CHECK` constraints |

The launcher, [`timecards.sh`](timecards.sh), has four jobs: five random digits, run Ex, load the rows into SQLite with the week, and show them. It has no arithmetic, no `awk`, no `sed` and no loop. It also checks every line that Ex prints: anything that is not a card row is an error, except one known note from nvi (see the gotchas).

### What is different from the ed entry

| | [`ed-weird`](../ed-weird/README.md) | `ex-weird` |
|---|---|---|
| State | Text: rows of `x` marks | The mark `t` (a position), and a tape of lines |
| Addition | Join two lines, so the marks sit side by side | Move a mark by an address |
| Control | One global command; a failed `s` is an "if" | A register that runs itself; the tape says whether to run it again |
| Program text | The script | The script, *and* text that the program writes and then runs |
| Stop rule | A regular expression over the marks (`x\{41,\}`) | A line of data on the tape |
| Decimal output | Ten rewrite rules for marks to digits | The tape already has the digits |

## Why this is weird

`ex` was made to edit text. It has no function, no `if` and no loop. What it does have is **code that is just text**. A register can hold a command, and `@` runs it. So a program can write its own next instruction, as a string, and run it. That is the same idea as `eval` in a scripting language, built from a text editor. It is also a jump table: the next step is looked up by *address*, in the data.

### An interactive session and a batch run

Normally you use Ex by typing a command and looking at the result: you move around, you see lines, you change your mind. The entry runs the same commands with **no one watching**. `-s` says "silent: do not show the usual messages". The commands come from a file on standard input, so every step must be right the first time. That is why the comments in the script matter more than they do for a one-off edit.

## What `check.sh` enforces

`check.sh` runs against whichever `ex` you have, and says which one it found.

- **The constraint is real.** `timecards.sh` has no arithmetic, no `awk`, no `sed`, no `expr` and no loop, and starts the editor once. `timecards.ex` has **no `g` or `v` command**, no shell escape and no file command. The tape has 41 go rows and 19 stop rows. The program ends with exactly one `@n`, and `@a` is started once.
- **The rules of the challenge.** 25 random runs: categories in order, hours 10 to 19, correct totals, a stop at the first total over 40 with the crossing card kept, `DEMO ONLY` everywhere, exit status 0 and nothing on stderr.
- **An independent simulation.** A separate model (a short awk program) gives the rows for each dice sequence. The entry agrees on all 1,024 sequences over the digits 0, 4, 5 and 9, and on 400 random ones.
- **Perturbations.** Move the boundary on the tape to 30 and the run stops after 30. Move it to 45, and eleven-hour dice give five cards. Swap two category lines and the categories swap. Delete the last `@n` and only one card runs. Make every tape instruction a comment and only one card runs.
- **Dialects.** Five measured differences between Ex implementations (below), checked for the one you have.
- **The schema.** SQLite refuses a non-demo row, 9 hours and a fifth category. The launcher refuses four dice and a non-digit.

## Gotchas worth knowing

- **Which Ex?** There is no one Ex. We ran the program on **nvi 1.81.6** (a descendant of the 4.4BSD editor that the POSIX `ex` description is based on) and on **Vim 9.1** in Ex mode (`ex -s -u NONE -N`), and both give the same answers. That is **implementation-permitted**: we tested these two, we did not test conformance to the standard. `@` (run a buffer), `k` (mark), `ya` (yank), `t` (copy), `j` (join), the bar and the `"` comment are all described for Ex in POSIX, as far as we can tell from reading it (we did not run a conformance suite). The program uses these and nothing else.
- **Where POSIX Ex ends and Vim begins.** The program uses no Vim extension. `-u NONE` and `-N` are Vim's options, to keep your `.vimrc` out of it. The launcher adds them when it sees Vim. Do not call Vim "Ex": it is a bigger editor that has an Ex mode.
- **Five differences that the program avoids.** The check measures each one.
  1. **Register order.** nvi runs a register of several lines from the **last line to the first**. Vim runs it from the first to the last. This is why the program is **one line**, with bars.
  2. **Nested global commands.** A global command inside a register that was started from a global command works in nvi and is refused by Vim. The program has no global command.
  3. **Printing.** In nvi a bare address (`2`, `+1`) prints the line it moves to. Vim prints nothing. The program moves its mark with `k`, which never prints.
  4. **Errors.** After the first error, nvi stops reading the script and exits with status 1. Vim carries on, and exits with status 1 at the end. The program makes no error on purpose, because a failed search or a backward address range would end it in nvi.
  5. **Backward ranges.** `'t,2` with the mark below line 2 is an error in nvi (`The second address is smaller than the first`). Vim prints nothing and does not stop.
- **nvi says things on standard output.** Its messages go to stdout, not stderr. When it has no terminal (a pipe, a container) it prints `Error: stderr: Inappropriate ioctl for device` first. The launcher drops that one known line, and fails on any other line that is not a card row.
- **nvi needs a recovery folder.** It will not start if it cannot write to `/var/tmp/vi.recover`. The sandbox images link that folder to `/tmp`, because the sandbox root is read-only. That is a fact about the images, and it is the only change they needed for this entry.
- **Ex's join adds a space.** `$-1,$j` puts `Meetings 17` and `17` together as `Meetings 17 17`. The `j` of `ed` does not add one. Both are specified: that is a difference between the two languages, not a quirk.
- **A comment is an instruction.** The tape's "stop" instruction is a quote mark. That works because Ex reads `"` as a comment, in a register as well as in a file.
- **A mark that sits on a deleted line is gone.** The program never deletes the line under mark `t`. It deletes only the card line (line 1) and its own scratch lines at the end of the buffer.
- **The tape is data, and it is long.** Sixty lines, one per possible total from 0 to 59. The longest run ends at 40 + 19 = 59. A different limit needs a different tape, and nothing computes one.

---

See the [root README](../../README.md#the-results-so-far) for how this compares to the other entries, and [`CHALLENGE.md`](../../CHALLENGE.md) if you want to write your own.
