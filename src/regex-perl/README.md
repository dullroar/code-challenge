# Regex challenge, Track 1: Perl (the regex is the program)

One `=~` match runs the whole timecard demo, then **returns false**. Follows [`plans/regex.md`](../../plans/regex.md). **DEMO ONLY**: the records are fictional and go to a scratch file, with no connection to any real time-reporting system.

## Run it

Perl 5 is all you need (Ubuntu ships it; `POSIX` and `File::Path` are core modules).

```bash
cd src/regex-perl
perl timecards.pl          # run the demo
./check.sh                 # 25 runs, asserts the rules below
```

Records are appended to `$XDG_DATA_HOME/RegexPerl/demo-timecards.tsv` (default `~/.local/share/RegexPerl/`). Delete that directory to start over. A run looks like:

```text
match returned: false
records at ~/.local/share/RegexPerl/demo-timecards.tsv (latest run below)
# DEMO ONLY 2026-11-13T16:21:50
Meetings	10	10	2026-W46	DEMO ONLY
Coding	10	20	2026-W46	DEMO ONLY
Debugging	18	38	2026-W46	DEMO ONLY
Learning	17	55	2026-W46	DEMO ONLY
# committed total=55 entries=4 DEMO ONLY
```

## How the stunt works

The host seeds four category names and a counter, fires one match against the scaffold string `MeetingsCodingDebuggingLearning`, and prints the file. It has no `for`, `while`, `foreach`, or recursion (`check.sh` greps for them). The pattern does the rest:

| Piece | Job |
| --- | --- |
| `^(?{ ... })` | Initializer: creates the scratch directory, opens the file, writes the header |
| `(?:  ...  )*` | The loop. Perl's greedy quantifier is the iteration; the scaffold string gives each pass something to eat |
| `(??{ $t<=40 ? $c[$n] // '(*FAIL)' : '(*FAIL)' })` | The stop rule and the category chooser in one: it hands the engine the *next category name as a pattern*, or `(*FAIL)` once the total passes 40 or the categories run out. A failed pass is what ends the quantifier |
| `(?{ local $t = $t + ...; local $n = $n + 1; print ... })` | One timecard: draws 10-19, adds it to the total, advances the category, appends the record |
| `(*COMMIT)` | Once the loop ends, backtracking may not retry shorter loops (or the finalizer would run more than once) |
| `(?{ print "# committed ..."; close })` | Finalizer |
| `(*FAIL)` | The signature move: the match gives up after doing all the work |

`local` is the interesting bit. Perl unwinds `local` assignments when the engine backtracks, so the running total and category counter are properly backtrack-aware, but the `print` calls are not and cannot be un-done. That is the "transaction engine without rollback" idea: the engine abandons the branch, and the side effects stay written.

## The pulse

On a real terminal, the match finishes the records, then pulses a **DEMO ONLY** banner through a grey ramp for about three seconds (60 frames, 50 ms each), then clears it. It is also done inside the regex: the scaffold string gets 60 `~` characters appended, and `[A-Za-z]*(?:~(?{ frame }))*` draws one frame per tick. The host still has no loop. A second `(*COMMIT)` stops the final `(*FAIL)` from backtracking into shorter tick counts and re-running the cleanup. Nothing is appended when stdout is not a terminal, so pipes and `check.sh` skip it.

## Fine print

- The pattern is not formatted. `/x` is on only so the scaffold is parsed sanely; there are no comments, no named groups, and no helper functions inside it. That is deliberate.
- The null-iteration warning Perl would otherwise raise about the loop body is silenced with `no warnings 'regexp'`, since the body is dynamic and Perl cannot prove it consumes input. It always does: it only proceeds after matching a category name.
- The ISO week is computed with `strftime('%G-W%V')`. As in the other versions, the ISO year can differ from the calendar year near New Year.
- Code in patterns is run by Perl as ordinary Perl. Nothing here shells out; the only I/O is the scratch file.
