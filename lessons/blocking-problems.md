# Blocking problems

What each approach has **not** solved, measured against a baseline.

## The baseline: the modern C# challenge

[`ModernChallenge1`](../src/ModernChallenge1/README.md) is the canonical successful challenge. Inside a single bodiless `for` it does **all** of this:

| Capability | In `ModernChallenge1` |
| --- | --- |
| Random hours (10 to 19) | `Random.Shared.Next(10, 20)` in the iterator |
| Running total and stop rule | LINQ `Sum() <= 40d` in the condition |
| Persistence | EF Core to SQLite, `SaveChanges` |
| Concurrency | A background `Thread` plus a `Mutex` |
| A real UI | A WPF window built from runtime XAML |
| Animation | A `DoubleAnimation` fade |
| One statement | Exactly one `for`, empty body |

The comparison is not "who is better". It is "which pieces of that list can this approach still not reach?" Each gap below is an open challenge for the exercises.

## Capability matrix

`yes` = done inside the stunt itself; `host` = done, but by the host script or helper, not the stunt; `no` = not done. Pulled from each entry's own README. Blank-ish cells are noted in the per-entry list instead of guessed.

| Entry | Random | Persist | Window / pulse | Thread | Fail on purpose / one statement |
| --- | --- | --- | --- | --- | --- |
| C# `ModernChallenge1` | yes | yes | yes | yes | one `for` |
| LINQ 1 / 2 | **no** (fixed five 8-hour days week) | yes | yes | no | one statement |
| XAML | **no** (`Random(42)`, same every run) | yes (`strict`: XML only) | yes | yes | no loop (unrolled x4) |
| `regex-perl` | yes | yes | terminal pulse | no | one match, returns false |
| `regex-pcre2` | yes | TSV file | terminal pulse | no | one match, returns false |
| `regex-pcre2grep` | yes | yes (no transaction) | terminal pulse | no | returns false; host not nothing |
| `regex-dotnet` | **no** (host seeds) | **no** | **no** | no | **must return true** |
| `regex-sed` | toy LFSR | yes | terminal pulse | no | exit 1 on purpose |
| `make-gnu` | yes | host (`sqlite3`) | terminal glow | no | restart is the loop |
| `cmake` | host (digit tape) | host | terminal glow | no | host reports |
| Java / Kotlin / Python / Go / Rust | yes | yes | yes (window or page) | yes | one `for`/iterator; Go needs helpers |
| `lisp`, `lisp-weird` | yes | via `sqlite3` pipe | terminal only | no | `or` stops the method chain; one-statement not the rule |
| `m4` | yes (own Park-Miller; host seeds it) | host (`syscmd` + `sqlite3`) | terminal only | no | self-expansion ends when `ifelse` says so |
| `tcl`, `tcl-weird` | yes | yes (in-process `sqlite3` package) | optional Tk window (`--gui`) | no | recursive trigger stops on an empty `INSERT ... SELECT` |
| `awk` | yes (`rand`, seeded from the host) | via `sqlite3` pipe | terminal only | no | one `while`; not a one-statement entry |
| `awk-weird` | yes (the dice are `RT` from `/dev/urandom`) | via `sqlite3` pipe | terminal only | no | `t > 40 { exit }`; **gawk only** |
| `find-posix` | yes (`mktemp -d` names; the last character picks the hours) | via `sqlite3` pipe | terminal only | no | one `find`; the walk runs out of tree. Not run on BSD or macOS |
| `find-gnu` | yes (same dice) | via `sqlite3` on fd 3 | terminal only | no | one GNU `find`; `-O0` to `-O3` must agree. **GNU find only** |
| `apl`, `apl-weird`, `cobol`, `cobol-weird`, `forth`, `forth-weird`, `haskell`, `haskell-weird` | yes | via `sqlite3` pipe or script | terminal only | no | one-statement not the rule |

The Linux script entries share a reporting shape (rows, a committed total, a stunt note) and do not open windows. Treat "Window / pulse" in this table as "terminal output" for them.

## Per-approach walls

### C# and LINQ

- **LINQ entries do not draw random hours.** They fold a fixed five-day, 8-hour work week into 40 hours. The stop rule is still a prefix cap, but the "random 10 to 19" requirement is not met.
- **Every `void` call needs a `Func<T>` wrapper.** Readable code would use a statement.
- **Some eagerness is unavoidable.** `Aggregate` is eager by definition, and `SaveChanges()` is called once, eagerly, at the point where the outer `Repeat(...)` evaluates its argument.
- **Mutable accumulators** (`list.Add`) are a shortcut rather than LINQ purity.
- **Query syntax cannot express** `Aggregate`, `Repeat`, `ToList`, `Sum`, `Single` or `AsEnumerable` ([LinqChallenge2 README](../src/LinqChallenge2/README.md)).
- **`DbContext` is not thread-safe**; the `Mutex` papers over it.
- **Windows only** (WPF).

### XAML

- No loop: four unrolled copy-pasted passes.
- No branching from WPF itself; SQL or `DataTable` expressions decide.
- `strict.xaml` saves XML rather than a database.
- The same "random" numbers on every run.

### `regex-dotnet`

- **A regex cannot draw random numbers**, so the host seeds five unary strings.
- **A regex cannot write**, so there are no side effects.
- **The signature move is impossible.** Append `(?!)` and the match fails, and a failed `Match` exposes no captures. The entry must return true.
- **No pulse.** It needs side effects during the match.
- **Unrolled randomness**: the tape always holds five draws even when three are needed.
- **The host still reports**, with a `Zip` over captures.

### `regex-pcre2grep`

- State cannot live in the pattern; the total lives in SQLite and callouts reread it.
- No transaction: each helper commits immediately, so nothing can be rolled back.
- Callouts need absolute program paths.
- Needs a callout-capable `pcre2grep` build (Ubuntu's lacks it).
- Not concurrency-safe: a run is identified by `max(id)`.
- Only PCRE2 10.49 tested.

### `regex-perl` and `regex-pcre2`

- Perl: code blocks need package variables; the ISO year can differ near New Year.
- PCRE2: callouts need the optimizer disabled and no JIT; the author did not test with the flags removed. A C host is still required.

### `regex-sed`

- **A toy RNG**: a 16-bit LFSR. Same seed, same cards.
- **sed has `b` and `t` jumps**, so its loop is "a machine with a program counter", not a single match.
- **"Returns false" is weaker**: the process exit status, not the match.
- **GNU only.**
- **Pulse speed depends on the machine** (calibrated on one WSL 2 box).
- `check.sh` scans for `e`/`r`/`R`/`w`, but a grep is not a sandbox.

### GNU Make

- A shell is needed for `mkdir -p`, `sqlite3`, `rm` and the `@:` no-op; there is no pure-Make way to create a directory or a SQLite file.
- UTC only; the calendar is good through 2134.
- A crashed run leaves `.tc-*.mk` behind and the next `make` refuses until `make clean`.
- Linux-only: the clock, entropy and terminal detection read `/proc`.
- Windows Terminal's pop-up needs `wt.exe`.

### CMake

- **No counted repetition, lookahead or backreferences** in CMake regex.
- **Output cannot happen from inside a condition**, so the host prints, writes and animates after the loop.
- The random draws are a host-made nine-digit tape.
- The ISO year is patched by hand.

### COBOL, Forth, Haskell and APL

- `cobol-weird`: `ON SIZE ERROR` is still a conditional, and the data-folder choice relies on a table index computed from a length. The program is not independent of a shell (`CALL "SYSTEM"` for `mkdir` and `sqlite3`).
- `forth-weird`: works only at the top level or in `evaluate`d text, and the loop and its state must stay on one line.
- `haskell-weird`: has not been run through `ormolu` or `hlint`; relies on `unsafeInterleaveIO` ordering; no random package ships with GHC.
- `apl-weird`: relies on `⎕IO←0`; a bad rewrite fails by recursing forever; `⎕FIO` and `⊃`/`↑` are interpreter-specific. The straight entry needs a pinned GNU APL build.
- **None of these open a window or run a thread.**

### Lisp, m4, Tcl and AWK

- **Lisp (both)**: SBCL only (`sb-ext:run-program` and friends; the `or` combination and `defcard` are standard). No formatter exists. **`lisp-weird`**: the limit is baked into the design (five classes handle "10 to 19 hours, stop over 40"; a rule needing more cards needs more classes), and its method count uses the MOP.
- **m4**: needs GNU m4 for `esyscmd` and `format`. The clock, the entropy and SQLite all come through the shell; m4 has no I/O of its own. `eval` is 32-bit, so the generator is built around that. Recursion deepens with every card, fine for 3-5 cards and not a pattern for thousands. A missing quote makes a runaway, not an error. There is no `m4-weird` by design.
- **Tcl**: the `sqlite3` package is separate from Tcl. A `tclsh` that has loaded Tk does not exit at the end of a script unless the script destroys the window, and `DISPLAY=:0` under WSL hangs Tk (the checks use Xvfb). **`tcl-weird`**: relies on SQLite evaluating `tcl('hours')` once per trigger run, which SQLite does not promise (`check.sh` would notice); `unknown` runs whatever is in the table, so it is not a pattern for tables others can edit; SQLite caps trigger recursion (1000 by default).
- **AWK**: `close()` of a pipe returns different values in different awks, and the one-true-awk build tested returns 0, so a failing `sqlite3` would pass unnoticed there. **`awk-weird`**: gawk only (`RT`); mawk quietly runs forever or reports zero cards. A directory name containing a single quote breaks the shell command that makes the data folder.
- **None of the four** opens a thread; only the Tcl entries open a window (optional `--gui`).

### find

- **`find-posix`**: relies on find reading a directory after it visits it (unspecified by POSIX; works on GNU find 4.9, bfs 3.1.2 and busybox 1.36.1) and on `{}` inside a longer argument (`{}/b09`; also unspecified). `mktemp` is not POSIX. **Not run on BSD or macOS.** busybox runs `mktemp` in-process, so the forced-dice tests are skipped for it. The line is about 5.7 KB because find has no variables.
- **`find-gnu`**: GNU find only (`-fprintf`, `%d`, `%T`, `-regex`, `-D`). `-quit` is avoided because it skips the `-D rates` profile. `/dev/fd/3` must be a pipe, or find truncates it.
- **Neither** opens a window or a thread, and neither has a glow or pulse.

### tar, ed, Ex and JavaScript

- **`tar-gnu`**: GNU tar only (`--to-command`, `--occurrence`); tested on 1.34 and 1.35. The dice are rolled when the archive is written, and the dispatcher does the one addition (in SQL). It does **not** capture live execution state: a stopped run cannot be resumed, only replayed. tar does not stop when its command fails, so the halt is the interpreter's own.
- **`tar-gnu-weird`**: one transition, in SQL, does all the arithmetic, and only tar's checkpoints decide *when*. What a checkpoint counts depends on the mode, so only creating an archive is used. Not run on BSD or macOS tar.
- **`ed-weird`**: GNU ed only (busybox ed cannot run it). That a failed `s` inside a global command is silent is GNU behavior that its manual does not promise. Totals are rows of marks, so the program does not scale past a few dozen. The launcher supplies the dice, since `ed` has no randomness.
- **`ex-weird`**: the tape is sixty lines of data, one per possible total, and nothing computes a different limit. We ran it on nvi 1.81.6 and Vim 9.1; we did not run a conformance suite. nvi needs its recovery folder to be writable.
- **`javascript`**: needs Node 24 or newer for `node:sqlite`. No thread, mutex or reflection (the C# had them as a 2008 time capsule). The categories repeat, where the C# stopped after four. The year is the ISO year, where the C# stored the calendar year.
- **`javascript-weird`**: the lifetime test relies on a forced garbage collection (`WeakRef`), and is the one test that depends on the engine. `map` with effects is a trick. An iterator is spent after one pass.
- **`javascript-events`**: needs Node 24 or newer, to keep the three Node entries in step. `emit()` is synchronous, so the program must schedule each card with `setImmediate` or the stack grows with every card. A throw in a listener goes to the caller of `emit()`, so every listener catches its own. An emitter has no backpressure: this program is safe only because each card waits for the one before it.

### The ports

- Java, Kotlin and Go **Windows Sandbox** profiles are not yet tested on real hardware; Rust has no Windows Sandbox profile; the GUI ports have no check script and the gate does not cover them yet ([`sandbox/README.md`](../sandbox/README.md)).
- Go's statement-only operations live in a helper file, which is the stated cost of that version.

## Open challenges

Each of these is an [exercise](exercises.md#g-open-challenges-not-verified-may-be-impossible):

1. Give the LINQ entries random 10 to 19 hour cards while staying in one statement.
2. Make `regex-dotnet` fail on purpose without losing its captures.
3. Give `regex-dotnet` a side effect (a pulse) through a `MatchEvaluator`-free route.
4. Make `cmake` do its output from the condition, or replace the host's digit tape.
5. Give Make a pure-Make random source and calendar that does not read `/proc`.
6. Add a thread to any Linux script entry.
7. Run the Windows entries on Linux, or add a Windows Sandbox profile for Rust.
8. Make `awk-weird` work under mawk (or any non-GNU awk): get a die roll without `RT`.
9. Give m4 its seed and week without `esyscmd`.
10. Port `lisp-weird` to a second Common Lisp (ECL or CCL) by replacing only the SBCL-specific calls.
11. Run `find-posix`'s `check.sh` on a BSD or macOS `find`, and write down exactly what breaks (`{}` in `{}/b09`, `-path`, `mktemp`, `date +%G-W%V`).

> **THERE ARE NO BLOCKERS, JUST NOT ENOUGH IMAGINATION.** The list above is the imagination budget.
