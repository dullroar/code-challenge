# AWK, weirder

**Teaches you:** that a regular expression as the record separator turns a stream of random bytes into dice, and that awk's implicit main loop plus one pattern is a whole program.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

There is **no loop, no `if`, no function, and no random-number generator** in [`timecards.awk`](timecards.awk). awk reads `/dev/urandom`; the record separator is the regular expression `[0-9]`, so every record is a stretch of random bytes that ends at a random digit, and gawk puts that digit in `RT`. A digit is a die roll and a record is a card. The loop is awk's own read-a-record loop, and the stop rule is one pattern with an `exit` action: `t > 40 { exit }`.

Without the database, the whole challenge is one line:

```sh
gawk 'BEGIN{RS="[0-9]"; split("Meetings Coding Debugging Learning",C)}
      {printf "%s\t%d\t%d\n", C[(NR-1)%4+1], h=10+RT, t+=h} t>40{exit}' /dev/urandom
```

The straight version is [`awk`](../awk/README.md).

## Run it

**GNU awk** (`gawk`, tested with 5.2.1) and `sqlite3`.

```bash
cd src/awk-weird
gawk -f timecards.awk                 # the dice come from /dev/urandom
gawk -f timecards.awk digits.txt      # ...or from any file: the digits in it ARE the dice
./check.sh                            # set GAWK=/path/to/gawk if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/AwkWeird/demo-timecards.db` (default `~/.local/share/AwkWeird/`). A run looks like this:

```text
# DEMO ONLY run 1794861177-31101
Meetings	17	17	2026-W47	DEMO ONLY
Coding	14	31	2026-W47	DEMO ONLY
Debugging	16	47	2026-W47	DEMO ONLY
# committed total=47 entries=3 DEMO ONLY
# the loop was awk's main loop over /dev/urandom, RS=[0-9] made each digit a die roll, and t > 40 { exit } stopped it
```

Because the input is a file operand, the program is **reproducible**: `printf '5 5 5\n' > d.txt; gawk -f timecards.awk d.txt` always gives Meetings 15/15, Coding 15/30, Debugging 15/45. The digits `3 8 2 9 4 1` give 13, 18, 12 hours and stop at 43. `check.sh` does this with hundreds of digits.

## How the stunt works

Read the rules in order: awk runs **every rule whose pattern matches, for every record, top to bottom**.

### 1. The separator is a regular expression, and the terminator is yours

`RS = "[0-9]"`. In POSIX awk, `RS` is one character. In gawk (and in several other awks), a longer value is a **regular expression**, and gawk stores the text that matched in `RT`. Read `/dev/urandom` with that and the stream is cut after every digit byte. About 10 in 256 bytes are digits, uniformly spread over `0`-`9`, so `RT` is a uniform random digit and a card is the junk before it (ignored). `10 + RT` is hours from 10 to 19. No `rand()`, no seed, no LCG. (I counted 20,000 records in C, UTF-8 and `-b` locales: each digit turned up about 2,000 times.)

### 2. One record is one card

```awk
{ t += h = 10 + RT }                                  # rule 2: the die, and the running total
{ $0 = C[n++ % 4 + 1] "," h "," t "," week }          # rule 3: the card, as a comma record
```

An assignment is an expression, so `t += h = 10 + RT` sets `h` and adds it to `t` in one statement (both start as "" which is 0, no initialisation needed). Assigning to `$0` makes awk **re-split** the record into fields with `FS`, which `BEGIN` set to a comma: `$1` is the category, `$2` the hours, `$3` the total, `$4` the week.

### 3. The same fields, three ways

- **Rule 4:** an `INSERT` built from `$1`..`$4`, printed to `| sql`, a pipe to `sqlite3`.
- **Rule 5:** `{ OFS = "\t"; $1 = $1; print $0, "DEMO ONLY" }`. `$1 = $1` looks like a no-op, and is the famous AWK way to force a rebuild of `$0` joined by `OFS`: the commas become tabs, so the people-readable row is the same record with a different separator.
- The `DEMO ONLY` rule is in the table: `CHECK(demo_only=1)`.

### 4. The stop rule is a bare pattern

```awk
t > 40 { exit }
```

`exit` in a main rule ends input and runs `END`, which commits and closes the pipe. The card that crossed the line has already been through rules 2 to 5, so it is kept without any special case. It is the last rule so that the card has been written before the program stops.

### 5. No `if`, no loop

- The empty last record of a finite file (the text after the last digit, e.g. a trailing newline) has an **empty `RT`**. Rule 1, `RT == "" { next }`, is a pattern with `next` that makes it not a card.
- The default input is added in `BEGIN` with arithmetic instead of an `if`: `ARGV[ARGC] = "/dev/urandom"; ARGC += (ARGC < 2)`. `ARGC < 2` is 1 when no file was named and 0 otherwise, so the new argument only counts when needed. awk reads files named in `ARGV[1..ARGC-1]`, so editing `ARGV` in `BEGIN` is how a program chooses its own input.
- The database directory uses `?:`, an expression and not a statement.

## Why this is weird

AWK is a language where **the program is the body of a loop you did not write**. Here the loop is over a random byte stream cut up by a regular expression, and the language's built-in record machinery stands in for a random-number generator. Most AWK programmers know `RS` as "newline, or maybe an empty line for paragraph mode", and never use `RT`. Seeing `RS="[0-9]"` on `/dev/urandom` is the "wait, you can DO that?".

You should not do this in production because: it is a GNU extension; the program's behaviour depends on a device file; "random digit" is hidden inside an I/O setting; and the stream, not the program, decides how long it runs (a finite file simply ends early, as `check.sh` shows).

## What you can learn

- `RS` as a regular expression, and `RT` (gawk), and that **`RS` applies to every read**, not only to your input file. The first draft of this program printed an empty week: `"date +%G-W%V" | getline week` read `date`'s output with `RS="[0-9]"` already set, so the record ended at the first digit of the year. The `date` call now comes first in `BEGIN`.
- That every rule runs for every record, in order, and that `next` and `exit` are the control flow.
- `$0` assignment re-splits; field assignment (`$1 = $1`) rebuilds `$0` with `OFS`. `FS` and `OFS` are independent.
- Assignment is an expression (`t += h = ...`), and a comparison is the number 0 or 1 (`ARGC += (ARGC < 2)`).
- Editing `ARGV`/`ARGC` in `BEGIN` to choose input files.
- That a finite input makes the program a *function of its input*: swap the file and the dice change.

## Gotchas and limitations

- **gawk only.** The GNU-specific parts: `RT`, `systime()`, `PROCINFO["pid"]`. A regex `RS` is not POSIX but mawk, the one-true-awk and busybox awk all accepted `RS="[0-9]"` when tried here; none of them has `RT`, so they cannot see *which* digit ended the record, and the trick needs exactly that. Worse, the failure is not an error: under mawk `RT` is always empty, so rule 1 skips every record and the stop rule never fires. On `/dev/urandom` mawk 1.3.4 keeps reading until it dies with `out of memory` (tried under a 400 MB limit, which it hit after about a thousand records); on a finite digit file it prints a header and `total=0 entries=0`. Do not run this under another awk without a memory limit and a timeout. `gawk --lint` reports the extensions.
- **A finite input can end before the total passes 40.** `/dev/urandom` never does. With a file, the program stops at end of input and reports whatever total it reached (`check.sh` tests `1 2` and gets 2 cards, 23 hours).
- **Trailing empty record.** A file ending in a newline makes one extra record with empty `RT`; rule 1 handles it. Without rule 1 it would count as a 10-hour card.
- **The run id** is the epoch seconds and the awk's process id.
- **A directory name containing a single quote** breaks the `mkdir` and `sqlite3` command lines here (the straight version quotes properly).
- **Locale.** Digit bytes are never part of a multibyte sequence, and the digit counts above were uniform in every locale tried; `gawk -b` is not needed.
- **Formatting.** No AWK formatter exists; the layout is by hand, one rule per line group with a comment above each rule.

## What `check.sh` enforces

With comments removed: none of `while for do if function switch rand srand`; `RS = "[0-9]"`; a bare `t > 40 { exit }`; `/dev/urandom` as the default input. Then 30 random digit strings, fed in four shapes (no separators, trailing newline, spaces between, letters and lines between), each compared card by card with an independent computation in bash. A short stream ending in a newline must stop cleanly. The one-liner in the header comment is extracted and run against a fixed digit stream. Moving the pattern to `t > 80` must change a stream of 5s from 3 cards to 6, proving the pattern is the stop rule. Finally 25 real runs on `/dev/urandom` are checked for sane records with SQLite agreeing with the output.

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker). The `cc-rt-awk` base image comes from `sandbox/container/build-bases.sh`.

```bash
sandbox/container/run-image.sh src/awk-weird
```

In the image: gawk and sqlite3 on a minimal Ubuntu.
