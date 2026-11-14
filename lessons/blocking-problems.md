# Blocking problems

What each approach has **not** solved, measured against a baseline.

## The baseline: the modern C# challenge

[`ModernChallenge1`](../src/ModernChallenge1/README.md) is the canonical successful challenge. Inside a single bodiless `for` it does **all** of this:

| Capability | In `ModernChallenge1` |
| --- | --- |
| Random hours (10-19) | `Random.Shared.Next(10, 20)` in the iterator |
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
| LINQ 1 / 2 | **no** (fixed 5×8h week) | yes | yes | no | one statement |
| XAML | **no** (`Random(42)`, same every run) | yes (`strict`: XML only) | yes | yes | no loop (unrolled x4) |
| `regex-perl` | yes | yes | terminal pulse | no | one match, returns false |
| `regex-pcre2` | yes | TSV file | terminal pulse | no | one match, returns false |
| `regex-pcre2grep` | yes | yes (no transaction) | terminal pulse | no | returns false; host not nothing |
| `regex-dotnet` | **no** (host seeds) | **no** | **no** | no | **must return true** |
| `regex-sed` | toy LFSR | yes | terminal pulse | no | exit 1 on purpose |
| `make-gnu` | yes | host (`sqlite3`) | terminal glow | no | restart is the loop |
| `cmake` | host (digit tape) | host | terminal glow | no | host reports |
| Java / Kotlin / Python / Go / Rust | yes | yes | yes (window or page) | yes | one `for`/iterator; Go needs helpers |
| `apl`, `apl-weird`, `cobol`, `cobol-weird`, `forth`, `forth-weird`, `haskell`, `haskell-weird` | yes | via `sqlite3` pipe or script | terminal only | no | one-statement not the rule |

The Linux script entries share a reporting shape (rows, a committed total, a stunt note) and do not open windows. Treat "Window / pulse" in this table as "terminal output" for them.

## Per-approach walls

### C# and LINQ

- **LINQ entries do not draw random hours.** They fold a fixed five-day, 8-hour work week into 40h. The stop rule is still a prefix cap, but the "random 10-19" requirement is not met.
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

### regex.dotnet

- **A regex cannot draw random numbers**, so the host seeds four unary strings.
- **A regex cannot write**, so there are no side effects.
- **The signature move is impossible.** Append `(?!)` and the match fails, and a failed `Match` exposes no captures. The entry must return true.
- **No pulse.** It needs side effects during the match.
- **Unrolled randomness**: the tape always holds four draws even when three are needed.
- **The host still reports**, with a `Zip` over captures.

### regex.pcre2grep

- State cannot live in the pattern; the total lives in SQLite and callouts re-read it.
- No transaction: each helper commits immediately, so nothing can be rolled back.
- Callouts need absolute program paths.
- Needs a callout-capable `pcre2grep` build (Ubuntu's lacks it).
- Not concurrency-safe: a run is identified by `max(id)`.
- Only PCRE2 10.49 tested.

### regex.perl and regex.pcre2

- Perl: code blocks need package variables; the ISO year can differ near New Year.
- PCRE2: callouts need the optimizer disabled and no JIT; the author did not test with the flags removed. A C host is still required.

### regex.sed

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

### COBOL, Forth, Haskell, APL

- **COBOL weird**: `ON SIZE ERROR` is still a conditional, and the data-folder choice relies on a table index computed from a length. The program is not independent of a shell (`CALL "SYSTEM"` for `mkdir` and `sqlite3`).
- **Forth weird**: works only at the top level or in `evaluate`d text, and the loop and its state must stay on one line.
- **Haskell weird**: has not been run through `ormolu` or `hlint`; relies on `unsafeInterleaveIO` ordering; no random package ships with GHC.
- **APL weird**: relies on `⎕IO←0`; a bad rewrite fails by recursing forever; `⎕FIO` and `⊃`/`↑` are interpreter-specific. The straight entry needs a pinned GNU APL build.
- **None of these open a window or run a thread.**

### The ports

- Java, Kotlin and Go **Windows Sandbox** profiles are not yet tested on real hardware; Rust has no Windows Sandbox profile; the GUI ports have no check script and the gate does not cover them yet ([`sandbox/README.md`](../sandbox/README.md)).
- Go's statement-only operations live in a helper file, which is the stated cost of that version.

## Open challenges

Each of these is an [exercise](exercises.md#g-open-challenges-not-verified-may-be-impossible):

1. Give the LINQ entries random 10-19 hour cards while staying in one statement.
2. Make `regex-dotnet` fail on purpose without losing its captures.
3. Give `regex-dotnet` a side effect (a pulse) through a `MatchEvaluator`-free route.
4. Make `cmake` do its output from the condition, or replace the host's digit tape.
5. Give Make a pure-Make random source and calendar that does not read `/proc`.
6. Add a thread to any Linux script entry.
7. Run the Windows entries on Linux, or add a Windows Sandbox profile for Rust.

> **THERE ARE NO BLOCKERS, JUST NOT ENOUGH IMAGINATION.** The list above is the imagination budget.
