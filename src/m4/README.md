---
name: "m4"
teaches: "that a macro processor is a programming language: no loop statement and no variable, just text that gets scanned again."
kind: weird
languages: [m4]
lesson: "languages/m4.md#a-loop-made-of-rescanning"
loop-by: rewrite-and-rescan
evaluation: rewriting
assurance: implementation-permitted
machine: "A text-rescanning machine"
state: "The input stream: whatever macro text has not been read yet"
tags: [fixed-point-iteration, lazy-evaluation, macro-processing, recursion, scope-and-binding, state, term-rewriting, turing-completeness]
---
# m4

**Teaches you:** that a macro processor is a programming language: no loop statement and no variable, just text that gets scanned again.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

There is one m4 entry and no `m4-weird`, because a whole program written in a macro processor is already the weird version. The challenge ("add 10-19 hour cards until the total passes 40") is done by `m4` itself: it generates the random numbers, keeps the running total, decides when to stop, formats the rows, and writes the SQL. [`timecards.m4`](timecards.m4) is the only source file. The shell appears twice, as plumbing: to read the clock and the OS random pool, and, at the very end, to hand a finished SQL script to `sqlite3`.

## Run it

You need GNU m4 (tested with 1.4.19) and `sqlite3`. The shell is `sh`; `date`, `od`, `tr` and `mkdir` are used for the seed, the clock and the folder.

```bash
cd src/m4
m4 timecards.m4
m4 -Dtc_seed=12345 -Dtc_week=2026-W01 timecards.m4    # a pinned, reproducible run
./check.sh                                              # set M4=/path/to/m4 if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/M4/demo-timecards.db` (default `~/.local/share/M4/`). A run looks like this:

```text
# DEMO ONLY run 1794860448-1900361580
Meetings	15	15	2026-W47	DEMO ONLY
Coding	11	26	2026-W47	DEMO ONLY
Debugging	15	41	2026-W47	DEMO ONLY
# committed total=41 entries=3 DEMO ONLY
# no loop statement: tc_card expands itself again until ifelse says stop, and m4 is the whole program
```

## What it does

It draws cards of 10 to 19 hours, cycling through Meetings, Coding, Debugging and Learning, until the running total is greater than 40 (the card that crosses the line is kept). It prints the rows and saves them to SQLite in one transaction.

## How the stunt works

### m4 in one paragraph

m4 reads text and copies it to the output, except that when it sees a *word* that names a macro it replaces the word with the macro's definition, and then **reads the replacement again**, looking for more macros. That "scan again" step (rescanning) is the entire evaluation model. There are no statements. Quotes (`` ` `` and `'` by default; `[` and `]` in this file) say "do not look inside this yet".

### 1. Make m4 safe for our text

```m4
changecom()dnl
changequote([, ])dnl
```

By default `#` starts a comment, and a comment is copied through **unexpanded**. The program's output lines start with `#`, so without `changecom()` the macros in them would silently not expand. And the default closing quote is `'`, which SQL string literals need, so the quotes become `[` `]`. `dnl` ("discard to new line") eats the rest of the line, including the newline that would otherwise end up in the output. It is also the comment syntax for the source file.

### 2. Macros are the variables

`define([tc_total], 0)` creates a macro whose text is `0`; "assigning" is redefining it: `define([tc_total], eval(tc_total + tc_hours))`. The arguments of `define` are expanded before `define` runs, so the `eval` is done first and the *number* is stored. Every macro starts with `tc_` so that it can never collide with a word in the SQL text, which m4 would helpfully expand.

### 3. A random number generator in 32-bit arithmetic

`eval` is m4's calculator and in GNU m4 it is **32-bit** (try `eval(2147483647 * 4)`: it answers `-4`). So the generator is Park-Miller, `seed = 16807 * seed mod (2^31 - 1)`, computed with Schrage's decomposition, `16807 * (s % 127773) - 2836 * (s / 127773)` and then add `2^31 - 1` back if the result is negative, which never leaves 32 bits. Hours are `10 + seed / 1024 % 10`. `check.sh` compares the output with an independent implementation in bash.

### 4. The loop is a macro that expands itself

```m4
define([tc_card],
  [tc_next()dnl
define([tc_hours], eval(10 + tc_seed / 1024 % 10))dnl
define([tc_n], incr(tc_n))dnl
define([tc_total], eval(tc_total + tc_hours))dnl
tc_append(tc_insert(tc_category(tc_n), tc_hours, tc_total))dnl
tc_row(tc_category(tc_n), tc_hours, tc_total)
ifelse(eval(tc_total > 40), 1, [], [tc_card()])])
```

Expanding `tc_card()` produces: a row of text (the output), some definitions that change the state, and then the result of `ifelse`. If the total is over 40, `ifelse` produces nothing and the expansion ends. Otherwise it produces the text `tc_card()`, and because the output of a macro is rescanned, that text is itself a call. Recursion, with the stop rule as the `ifelse`. `check.sh` proves it: cut the self-call and exactly one card appears.

### 5. `ifelse`, and the gotcha that bit while writing this

`ifelse(a, b, then, else)` compares `a` and `b`. With more arguments it continues **in groups of three**: `ifelse(a, b, then, c, d, then2, ..., else)`. A natural first attempt at a four-way switch, `ifelse(n, 0, [Meetings], 1, [Coding], ...)`, is wrong: after the first group it compares `1` with `[Coding]`, and GNU m4 prints "excess arguments to builtin `ifelse` ignored". The fix is to repeat the thing being tested in every group (`tc_pick`). That is a very m4 kind of bug, and a very m4 kind of warning.

### 6. A string that grows: `defn`

```m4
define([tc_append], [define([tc_sql], defn([tc_sql])[$1])])
```

`defn(name)` returns a macro's definition *quoted*, so it is not scanned again. Appending is "redefine the macro as itself plus the new text". That is how the SQL script accumulates card by card. Diversions are m4's other way to collect text (`divert(1)` sends output to a numbered buffer, `undivert(1)` pours it back), and `divert(-1)` is the "bit bucket" (a place where output just disappears) that this file uses to silence the definitions. The SQL is not collected in a diversion because `undivert` does not *return* text: inside an argument list it prints directly and the argument comes out empty, so a diversion cannot be passed to `syscmd`.

### 7. The empty quote `[]`

In `tc_row`, `$1[]tc_tab` has an empty quoted string in the middle. Without it, `Meetings` followed by `tc_tab` would be read as one word, `Meetingstc_tab`, which is not a macro. `[]` expands to nothing but splits the word. You will use this every time you paste macros together.

### 8. Saving

```m4
syscmd([d="${XDG_DATA_HOME:-$HOME/.local/share}/M4"; mkdir -p "$d" && sqlite3 "$d/demo-timecards.db" <<'END_OF_DEMO_SQL'
]defn([tc_sql])[COMMIT;
END_OF_DEMO_SQL
])
```

The quoting here switches in and out: the first and last pieces are literal shell text in `[ ]`, and `defn([tc_sql])` is outside the quotes so it is expanded into the script. A shell here-document with a quoted terminator carries the SQL, so the shell never sees it as anything but data. `sysval` (the exit status) is checked afterwards and a failure aborts with `m4exit(1)`.

### 9. Pinning the seed

`ifdef([tc_seed], [], [define(...)])` means "only compute a seed if none was given on the command line with `-D`". That is what makes a run reproducible, which is what lets the tests compare it with a reference.

## Why this is weird

Because it works. m4 was designed to preprocess text, in the 1970s, as the macro layer that shipped with Unix tools and later powered `sendmail.cf` and GNU `autoconf`. It has no loops, no variables, no arithmetic of its own beyond `eval`, no strings in any usual sense: everything is text being rewritten. The challenge needs state, repetition, random numbers and a stop rule, and each of those is built here from define, rescan and quoting. If you can write this, you can read `configure`.

## What you can learn

- Rescanning: how text-in, text-out evaluation works, and why quoting is the whole point.
- `define`/`defn`/`pushdef`-style state, and recursion as the only repetition.
- The `ifelse` grouping rule, `dnl`, `[]` and `changequote`.
- Diversions, and what `undivert` does not do.
- That 32-bit `eval` is a design limit you have to work around, not a bug.
- Why `#` comments are dangerous in a language where comments are not skipped.

## Gotchas worth knowing

- **GNU m4 extensions: two.** `esyscmd` (capture a command's output: seed, clock, week) and `format` (used once, to make a tab character). Everything else (`define`, `defn`, `ifelse`, `ifdef`, `eval`, `incr`, `divert`, `changecom`, `changequote`, `syscmd`, `sysval`, `dnl`, `-D`) is POSIX. BSD m4 has `esyscmd` but not `format`. One more GNU-specific *behavior* to know about: `eval` is 32-bit there, and the generator is built around that limit; another m4 may have a different width.
- **Recursion depth.** Every card nests one more expansion. At 3 to 5 cards that is nothing; a rule that needed thousands of cards would need a different shape (m4 can do tail-recursion tricks, but this file does not).
- **The SQL is not escaped.** Every value is a number or one of four fixed words. Do not feed user text into `tc_insert`.
- **The seed.** Three random bytes from `/dev/urandom`, scaled: about 24 bits of entropy, ample for a demo. A pinned seed must be 1 to 2147483646.
- **The shell does the plumbing.** If you object that `syscmd` is a shell call: yes, to save the file, exactly as the Forth entry pipes to `sqlite3`. The computation is m4's.
- **Formatting.** There is no formatter for m4. Layout: one macro per paragraph, a comment block above each section, bodies indented two spaces.

## What `check.sh` enforces

With `dnl` lines removed: exactly one `syscmd` and exactly three `esyscmd`; `tc_card` ends by expanding itself. With a pinned seed, 47 runs (a fixed set plus 41 consecutive seeds) match an independent bash implementation card for card, including the stop rule and the category cycle. With the self-call removed, exactly one card appears. And 25 real runs each check the rows (hours 10-19, categories in order, correct running totals, the stop rule), and that SQLite holds exactly what was printed, all marked `DEMO ONLY`.

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker). The `cc-rt-m4` base image comes from `sandbox/container/build-bases.sh`.

```bash
sandbox/container/run-image.sh src/m4
```

The image holds GNU m4 and sqlite3 on a minimal Ubuntu.
