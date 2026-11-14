# CMake: `for (seed; test; iterate) ;`, with `while()` and a regex

> **DEMO ONLY.** Fictional time cards, written to a scratch SQLite file under `$XDG_DATA_HOME/CmakeChallenge/`.
> Nothing here touches real time reporting.

```bash
cmake -P timecards.cmake            # one run (glows if stdout is a terminal, silent in a pipe)
cmake -DPOP=1 -P timecards.cmake    # same, in a new Windows Terminal window that closes itself
./check.sh                          # needs cmake 3.19+ on PATH (`uv tool install cmake` works without root)
```

```
# DEMO ONLY run 1
Meetings	16	16	2026-W46	DEMO ONLY
Coding	18	34	2026-W46	DEMO ONLY
Debugging	13	47	2026-W46	DEMO ONLY
Runtime error near line 4: CHECK constraint failed: stop rule fired: total exceeds 40 (19)
# committed total=47 entries=3 DEMO ONLY
# an empty while() went round 3 times, once per card
```

## The stunt

An earlier version of this file was a normal script: `while()`, `math(EXPR)`, `list(GET)`. That is `RunEverything()`
in CMake's accent, so it was thrown away. The program is now **one `while()` with an empty body**. Everything that
decides anything lives in its condition:

```cmake
while(NOT "${CMAKE_MATCH_1}${CMAKE_MATCH_5}" MATCHES "^xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      AND "${CMAKE_MATCH_1}${CMAKE_MATCH_5}|${CMAKE_MATCH_3}|${CMAKE_MATCH_4}${CMAKE_MATCH_5}-||\
0:xxxxxxxxxx|\
1:xxxxxxxxxxx|
   ...
9:xxxxxxxxxxxxxxxxxxx|"
          MATCHES "^(x*)\\|([0-9])([0-9]*)\\|([^|]*)\\|.*\\|${CMAKE_MATCH_2}:(x*)\\|")
endwhile()
```

CMake's `if()`/`while()` `MATCHES` stores its capture groups in the ordinary variables `CMAKE_MATCH_1..`, and a
`while()` **re-expands its condition on every pass**. So the condition can build its subject string and its pattern out
of the previous pass's captures. That is a register machine, and the match is the program:

| Piece | What it is |
|---|---|
| State | numbers are runs of `x`: 1 = total so far, 2 = the digit peeked last pass, 3 = rest of the digit tape, 4 = the log of finished cards, 5 = hours of the card added last pass |
| Hours 10-19 | the table `0:xxxxxxxxxx|1:xxxxxxxxxxx|...` is *in the subject*; the pattern splices the previous pass's digit in (`${CMAKE_MATCH_2}:`) and captures that row. The staircase is the 10-19 |
| Running total | the next subject starts with `${CMAKE_MATCH_1}${CMAKE_MATCH_5}`: string concatenation of unary numbers |
| Stop rule | the first test: `NOT` (total so far + last card matches a **41-character literal**). Exactly 40 continues. Mutating the literal changes the behaviour (`check.sh` does) |
| Loop control | the loop ends when the match says no. The regex stunt entries' "return no match, on purpose" is simply what stops this one |
| Order of tests | the stop test goes **first**: a match that fails clears every register and one that succeeds rewrites them, so the main match must run last for its captures to be the ones that survive |

The host is deliberately small, like the other entries' hosts: before the loop it draws a tape of 9 random digits and
puts them in the registers (`set(CMAKE_MATCH_n ...)`); after the loop it reads the log (lengths of `x` runs are the
hours), picks the ISO week, writes SQLite and plays the glow. `check.sh` fails if the file has a `function()`,
`macro()`, `include()` or `cmake_language()`, anything between `while()` and `endwhile()`, or any computation
(`math`, `list`, `foreach`, `string` surgery) before the loop.

## Walls and fine print

- **CMake's regex has no counted repetition** (`x{41}` is not supported; the test is literally 41 x's). It also has no
  lookahead and no backreferences, so a pattern parameterised by a *register* (`${CMAKE_MATCH_2}:`) is the only way to
  do a lookup. A tempting `(x?x?x?...)` x 40 for "at most 40" would backtrack exponentially on failure, hence the
  separate literal test.
- **The hours are looked up one pass late.** Pass *j* peeks the digit for card *j+1* and looks up the hours of card
  *j* (peeked in pass *j-1*), so the very first digit is part of the seed.
- **The tape has 9 digits** so it can never run dry (at most 5 cards, 6 digits used). Four 10-hour cards total exactly
  40, which continues, so the fifth card wraps its category to Meetings.
- **The host still reports.** Printing the rows, the SQLite writes, the ISO week and the glow are ordinary CMake
  after the loop (`string(TIMESTAMP)` knows `%V` but not `%G`, so the ISO year is patched by hand from the month and
  week). Output cannot happen from inside a condition. This is the "tiny host reports a result" allowance.
- **Local time**, like the SQLite-based entries (the Make entry is UTC). `check.sh` sweeps year boundaries against
  `date -u` using `SOURCE_DATE_EPOCH`.
- **`message()` goes to stderr**, hence the `/dev/stdout` writes. `execute_process` inherits stdout, so SQLite's
  header and CHECK error arrive in order.
- **`wt.exe` treats `;` as its own subcommand separator**, so the `POP` command line contains none (CMake lists are
  `;`-separated, so this needs care).
- The only programs started are `sqlite3`, `wt.exe` (POP) and CMake itself (for its own `-E sleep`); `check.sh`
  asserts that.
