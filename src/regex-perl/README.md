# Regex challenge, Track 1: Perl (the whole program is one match)

The file's only statement is a single `=~` match. Seeding, the random draws, the SQLite transaction, the terminal pulse and all the printing happen *inside* that match, and then the match **returns false**. Follows [`plans/regex.md`](../../plans/regex.md). **DEMO ONLY**: the records are fictional and go to a scratch SQLite file, with no connection to any real time-reporting system.

## Run it

Perl 5 and the `sqlite3` command-line tool (`sudo apt install sqlite3`). `POSIX` and `File::Path` are core Perl modules.

```bash
cd src/regex-perl
perl timecards.pl          # run the demo
./check.sh                 # 25 runs, asserts the rules below
```

Records go to `$XDG_DATA_HOME/RegexPerl/demo-timecards.db` (default `~/.local/share/RegexPerl/`). Delete that directory to start over. A run looks like this, followed by a three-second pulse on a real terminal:

```text
# DEMO ONLY run 1794613174-17683
Meetings	10	10	2026-W46	DEMO ONLY
Coding	19	29	2026-W46	DEMO ONLY
Debugging	16	45	2026-W46	DEMO ONLY
# committed total=45 entries=3 DEMO ONLY
# the match now returns false, on purpose
```

```bash
sqlite3 -header -column ~/.local/share/RegexPerl/demo-timecards.db 'select * from demo_timecards'
```

## How the stunt works

Below the `use` lines, `timecards.pl` is one line: a constant scaffold string `=~` one pattern. No host code seeds, loops, or prints. `check.sh` enforces that the file is a single statement, with exactly one match and no loop keywords.

| Piece | Job |
| --- | --- |
| `^(?{ ... })` | Initializer: seeds the state, makes the scratch directory, starts `sqlite3` on a pipe, creates the table (with a `CHECK(demo_only=1)` constraint) and opens a transaction |
| `(?:  ...  )*` | The loop. Perl's greedy quantifier is the iteration; the scaffold string gives each pass something to eat |
| `(??{ $::t<=40 ? $::c[$::n] // '(*FAIL)' : '(*FAIL)' })` | The stop rule and the category chooser in one: it hands the engine the *next category name as a pattern*, or `(*FAIL)` once the total passes 40 or the categories run out. A failed pass is what ends the quantifier |
| `(?{ local $::t = ...; local $::n = ...; print ... })` | One timecard: draws 10-19, adds it to the total, advances the category, sends an `INSERT` to SQLite and prints the row |
| `(*COMMIT)` | Once the loop ends, backtracking may not retry shorter loops (or the finalizer would run more than once) |
| `(?{ COMMIT; close; print ... })` | Finalizer: commits the SQLite transaction, closes the pipe (which waits for `sqlite3` to finish), prints the summary |
| `[A-Za-z]*(?:(?(?{-t STDOUT})~(?{ frame }) \| (?!)))*` | The pulse: one frame per `~` at the end of the scaffold, but only if stdout is a terminal (the conditional is a code block), so pipes and `check.sh` skip it |
| `(*COMMIT)(?{ settle })(*FAIL)` | Clears the banner, then the signature move: the match gives up after doing all the work |

`local` is the interesting bit. Perl unwinds `local` assignments when the engine backtracks, so the running total and category counter are properly backtrack-aware, but the `INSERT`s and `print`s are not and cannot be un-done. The engine abandons the branch, and the side effects stay written. The SQLite transaction is real and commits; the *match* is what lies.

## Fine print

- The pattern is not formatted. `/x` is on only so the scaffold is parsed sanely; there are no comments, no named groups, and no helper functions inside it. That is deliberate.
- State lives in package variables (`$::t`, `$::n`, ...) because code in a pattern runs with the file's `strict` rules and `local` only works on globals. They are all initialised inside the match.
- The null-iteration warning Perl would otherwise raise about the loop body is silenced with `no warnings 'regexp'`, since the body is dynamic and Perl cannot prove it consumes input. It always does: it only proceeds after matching a category name or a `~`.
- SQL is built by interpolating values into strings. That is safe here only because every value is either a number the match computed or one of four fixed category names; do not copy the habit.
- Code in patterns is run by Perl as ordinary Perl. The only external program is `sqlite3`, started without a shell with a fixed argument list, and the only I/O is the scratch database and the terminal.
- The ISO week is computed with `strftime('%G-W%V')`. As in the other versions, the ISO year can differ from the calendar year near New Year.
