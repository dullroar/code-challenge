---
name: "Common Lisp"
teaches: "how `LOOP` can express a whole algorithm as a list of clauses: count, draw, sum, collect, stop."
kind: idiomatic
languages: [common-lisp]
lesson: "languages/lisp.md"
loop-by: loop-statement
evaluation: eager
assurance: guaranteed
pairs-with: lisp-weird
tags: [control-flow, domain-specific-language, homoiconicity, macro-processing]
analogies: [monoid-and-fold]
---
# Common Lisp

**Teaches you:** how `LOOP` can express a whole algorithm as a list of clauses: count, draw, sum, collect, stop.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

This is the straight version, the one that shows how Common Lisp is *meant* to be written. The challenge ("add 10-19 hour cards until the total passes 40") is a single `LOOP` form in `draw-cards`; everything else in [`timecards.lisp`](timecards.lisp) is a small function that does one job and has a docstring. The weird version is [`lisp-weird`](../lisp-weird/README.md).

## Run it

You need [SBCL](https://www.sbcl.org/) (tested with 2.2.9) and `sqlite3`. Nothing else is needed: no Quicklisp, no ASDF, no libraries. The program uses only what ships in the standard and in SBCL itself.

```bash
cd src/lisp
sbcl --script timecards.lisp                 # a normal run
sbcl --script timecards.lisp 2026-01-01      # pin the date, so the ISO week is predictable
./check.sh                                   # set SBCL=/path/to/sbcl if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/Lisp/demo-timecards.db` (default `~/.local/share/Lisp/`). A run looks like this:

```text
# DEMO ONLY run 1794860153-ONSTYU
Meetings	13	13	2026-W47	DEMO ONLY
Coding	18	31	2026-W47	DEMO ONLY
Debugging	12	43	2026-W47	DEMO ONLY
# committed total=43 entries=3 DEMO ONLY
# one LOOP form with SUM, COLLECT and UNTIL is the whole challenge
```

## What it does

It draws cards of 10 to 19 hours, cycling through Meetings, Coding, Debugging and Learning, until the running total is greater than 40 (the card that crosses the line is kept). It prints each card, then writes all of them to SQLite in one transaction.

## How the stunt works

Read the file top to bottom; each section only uses what is above it.

1. **A package and the rules.** `defpackage` / `in-package` give the program its own namespace instead of dumping symbols into `CL-USER`. The rules of the game are named: `+min-hours+`, `+max-hours+`, `+limit+` (constants wear `+plus+` signs by convention; specials wear `*earmuffs*`).
2. **A structure.** `defstruct card` gives a typed record with a constructor, accessors (`card-hours`) and a printer for free. The slot types are checked by SBCL.
3. **The challenge.**
   ```lisp
   (loop for number from 1
         for hours = (+ +min-hours+ (random (1+ (- +max-hours+ +min-hours+)) state))
         sum hours into total
         collect (make-card number (category-for number) hours total)
         until (> total +limit+))
   ```
   `LOOP` is a small language of its own. `for number from 1` counts; `for hours = ...` re-evaluates its expression on every pass; `sum ... into total` keeps a running total in a variable the loop owns; `collect` builds the result list; `until` ends the loop. Clauses run **in the order written**, so putting `until` *after* `collect` is what keeps the crossing card. Move it above and the last card is silently dropped.
4. **Categories** repeat through `(aref *categories* (mod (1- number) 4))`: a vector and `mod`, the plain way. (The weird version does it with a circular list.)
5. **The calendar.** SQLite and `date(1)` are not needed to know the ISO week; Common Lisp has `decode-universal-time`, which returns day of week and year, and the rest is arithmetic (`iso-week`, `weeks-in-year`). `check.sh` compares it with `date(1)` on awkward dates (and a one-off sweep of 1,139 dates around year boundaries matched Python's `isocalendar()`). The optional date argument exists so that this arithmetic can be tested on awkward dates such as 2021-01-03 (which is in week 53 of **2020**).
6. **SQLite.** SBCL has no database library in its core, so the program builds one SQL script as a string (`with-output-to-string`, `format` with a `~A` per value, `sql-quote` doubling quotes) and hands it to the `sqlite3` command line tool with `sb-ext:run-program`. The `DEMO ONLY` rule is in the table: `CHECK(demo_only=1)`.
7. **`main`.** It seeds a fresh `random-state` from the OS (`(make-random-state t)`), draws, saves and prints.

## Why this is idiomatic

- **Data and functions, not objects.** A struct for the data, small functions over it, and one function (`draw-cards`) that is pure apart from consuming random numbers from a state it is *given*, rather than touching a global.
- **`LOOP` with accumulation clauses** instead of hand-rolled recursion or a `setf` counter. That is how experienced Lisp programmers write "walk, accumulate, stop".
- **Docstrings on everything**, which `(describe 'draw-cards)` shows at the REPL.
- **Output through `format` directives** (`~A ~D ~C ~%`), and string building with `with-output-to-string` rather than repeated concatenation.
- **No clever macros.** A macro is the right tool when a function can't do the job; none of these needed one.
- **Warnings are errors.** The file compiles with no warnings and no style warnings, and `check.sh` enforces it.

## What you can learn

- `LOOP` clause order and `sum ... into`.
- `defstruct` slot types and `#.` (read-time evaluation) to use a constant inside a type.
- Why `defconstant` is for numbers and `defparameter` is for vectors (a vector is not `eql` to itself after reloading, and `defconstant` would complain).
- How SBCL runs scripts: `--script` implies `--disable-debugger` and ends the runtime options, so `sb-ext:*posix-argv*` is `("sbcl" "2026-01-01")` with no `--script file` in it.
- ISO weeks: week 1 is the week with the year's first Thursday; a year has 53 weeks when it starts or ends on a Thursday.

## Gotchas worth knowing

- **SBCL only.** `sb-ext:run-program`, `sb-ext:posix-getenv` and `sb-ext:parse-native-namestring` are SBCL's. Other implementations have equivalents (`uiop:run-program`, `uiop:getenv`) but they are not the same functions.
- **Pathnames are not strings.** `*` and `[` in a path mean something to a Lisp pathname, so the program converts with `parse-native-namestring` and back with `native-namestring`. A home directory with a `[` in its name would otherwise be treated as a wildcard.
- **`random` is not cryptographic** and SBCL's default state is the same every start; `(make-random-state t)` is what makes runs differ.
- **SQL by string building** is safe here only because every value is a number we computed or one of four fixed words. `sql-quote` is there anyway; do not copy this to untrusted input.
- **Formatting.** Common Lisp has no standard formatter. The layout is the usual hand-made one (two-space bodies, `LOOP` clauses aligned, docstring first), as Emacs's `lisp-mode` would indent it; no formatter was run.

## What `check.sh` enforces

The `DEMO ONLY` marker is there and nothing looks like network code; `draw-cards` is a `LOOP` ending in `until (> total +limit+)`; the file compiles with **no** warnings; `iso-week` agrees with `date(1)` on 22 edge-case dates; and 25 runs each print a sane record set (hours 10-19, categories in order, running totals right, stopping exactly when the total passes 40) with SQLite agreeing with the output. A non-demo row is refused by the table.

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker). The `cc-rt-sbcl` base image comes from `sandbox/container/build-bases.sh`.

```bash
sandbox/container/run-image.sh src/lisp
```

It builds this folder's [`Dockerfile`](Dockerfile) and runs the result with no network, a read-only file system and user `nobody`, then prints the output and a read-only look at the rows it wrote. The image holds SBCL and sqlite3 on a minimal Ubuntu.
