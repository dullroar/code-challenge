# Regex challenge, Track 2: PCRE2 callouts as a tiny DSL

One `pcre2_match` call runs the whole timecard demo, then reports **no match**. Follows [`plans/regex.md`](../../plans/regex.md). **DEMO ONLY**: the records are fictional and go to a scratch file, with no connection to any real time-reporting system.

## Install and run on Ubuntu under WSL 2

```bash
sudo apt install -y build-essential pkg-config libpcre2-dev
cd src/regex-pcre2
make run          # build and run the demo
make check        # 25 runs, asserts the rules below
```

Records are appended to `$XDG_DATA_HOME/RegexPCRE2/demo-timecards.tsv` (default `~/.local/share/RegexPCRE2/`). Delete that directory to start over. A run looks like:

```text
pcre2_match returned -1 (no match)
records at ~/.local/share/RegexPCRE2/demo-timecards.tsv (latest run below)
# DEMO ONLY 1794612149
Meetings	19	19	DEMO ONLY
Coding	10	29	DEMO ONLY
Debugging	15	44	DEMO ONLY
# committed total=44 entries=3 DEMO ONLY
```

## How the stunt works

The pattern is the whole program:

```text
^(?C"init")(?:(?C"gate")(Meetings|Coding|Debugging|Learning)(?C"book"))*(*COMMIT)(?C"commit")(*FAIL)
```

The C host (`timecards.c`) compiles it, registers one callout dispatcher, calls `pcre2_match` once against `MeetingsCodingDebuggingLearning`, and prints the file. It has no `for`, `while`, `do`, `goto`, or recursion (`check.sh` greps for them). The callout strings are opcodes:

| Opcode | Does | Return value to the engine |
| --- | --- | --- |
| `init` | opens the scratch file, writes the header | 0 (carry on) |
| `gate` | the stop rule | 1 (fail this branch) once the total is over 40, which ends the `*` loop; else 0 |
| `book` | draws 10-19 hours, adds to the total, writes the record for the category that was just matched (read from capture group 1) | 0 |
| `commit` | writes the summary line, closes the file | 0 |

PCRE2 supplies the iteration (`*`), the category walk (the subject string and the alternation), and the backtracking. `(*COMMIT)` keeps a failed match from retrying shorter loops, so `commit` runs exactly once. `(*FAIL)` then makes the whole match lose, after everything was written. That is the signature move.

## The optimizer caveat, as the plan asks

Callouts only mean something if the engine actually visits them. This program compiles with `PCRE2_NO_AUTO_POSSESS | PCRE2_NO_START_OPTIMIZE | PCRE2_NO_DOTSTAR_ANCHOR`, so the optimizer cannot skip or reorder the callout points. It also does **not** use the PCRE2 JIT, which does not support callouts at all. `check.sh` verifies that every run's committed total and entry count agree with the rows actually written, which is the evidence that no callout was silently skipped. This was tested with the system PCRE2 (10.42 on Ubuntu 24.04); I did not test with those flags removed to see which callouts the optimizer would elide.

## Fine print

- The `*` loop ends because `gate` fails the next iteration (or the four category names run out), not because anything in C decides to stop. The C only answers the question "is the total over 40?" when the engine asks.
- The state (`total`, `entries`, the file) lives in a C struct that the callouts share, so, unlike Perl's `local`, none of it rewinds on backtracking. That suits this program: nothing is ever un-done.
- The dispatcher is a ternary chain, not a table, to keep the host free of loops and function-pointer tricks. Unknown opcodes (and I/O errors) abort the match with `PCRE2_ERROR_CALLOUT`, which is deliberately not the `-1` that means "no match", and the host reports success only if `commit` actually ran.
