# By solution patterns

The same ideas show up in different languages. This page organizes the entries by *mechanism*, for readers who want to explore an unfamiliar way of computing rather than deepen one language.

## Formal languages

A formal language is a notation with strict rules that a machine can process. The recurring surprise: a notation built for one job turns out to be a computer.

| Formal language | What it was for | What it becomes | Entry |
| --- | --- | --- | --- |
| **RegEx** | Matching text | A search machine with state and I/O hooks ([Perl](languages/regex.md#perl-code-inside-the-match), [PCRE2](languages/regex.md#pcre2-callouts-as-an-instruction-set)), a counter ([.NET](languages/regex.md#net-balancing-groups)), a rewriting system ([sed](languages/regex.md#gnu-sed)) | `regex-*` |
| **Make** | Ordering builds | A dependency engine that restarts itself, giving a loop | [`make-gnu`](../src/make-gnu/README.md) |
| **CMake** | Configuring builds | A register machine in a `while()` condition | [`cmake`](../src/cmake/README.md) |
| **XAML** | Describing a UI tree | An interpreter that runs methods as it parses | [`xaml`](../src/xaml/README.md) |
| **LINQ query expressions** | Querying collections | An execution pipeline with lazy and eager stages and provider boundaries | [`LinqChallenge2`](../src/LinqChallenge2/README.md) |

What to take away:

- **Declarative does not mean inert.** Any notation that lets you name a function and its arguments is one step from being a program (`ObjectDataProvider`, callouts, `include`).
- **The cheapest way to find what a notation can really do is to give it a job it was not designed for**, then document where it fails: the [blocking problems](blocking-problems.md).
- **Performance cliffs are semantics.** sed's pulse *uses* catastrophic backtracking as a clock; in production the same property is a denial-of-service bug.

## Map/reduce and other transformations

Several entries replace "loop with an accumulator" with a transformation of a whole sequence.

| Idea | Where | In plain words |
| --- | --- | --- |
| **Running sum, then split** | [Haskell](../src/haskell/timecards.hs#L56-L59) `span ((<= 40) . runningTotal)` over `scanl1 (+)` | Build every possible answer lazily; choose where to stop reading |
| **Running sum, then count the prefix** | [APL](../src/apl/timecards.apl#L35) `Drawn↑⍨1++/40≥+\Drawn` | Draw more than enough up front, compute the prefix that fits |
| **Fold** | [LINQ `Aggregate`](../src/LinqChallenge1/Program.cs#L45) | A reduce that carries state through the pipeline |
| **Iterator/closure chain** | [Rust `successors`](../src/RustChallenge1/src/main.rs#L19) | A generator whose "next" is the whole program |
| **Sequence generator** | Kotlin `generateSequence` | The sequence ends when the generator yields null |
| **Rewrite to a fixed point** | [sed](languages/regex.md#gnu-sed) | Apply substitutions until none applies; the final text is the answer |
| **Reshape and recycle** | [APL](../src/apl/timecards.apl#L39) `(≢Hours)⍴Categories` | A modulo you get for free |

The common shape: *describe the full answer, then say how much of it you want.* The differences are about **when** the work happens (eager `Aggregate` and APL arrays vs. lazy Haskell lists and LINQ `Select`) and **where** state lives. Compare how LINQ and Haskell answer "when does it run?" in [C#](languages/csharp-linq-xaml.md#deferred-execution-and-the-void-to-value-trick) and [Haskell](languages/haskell.md#lazy-io-as-control-flow).

## Control state outside variables

Where does "where am I in the program?" live when you have no loop counter?

| Place | Entry |
| --- | --- |
| The target of a `GO TO` | [COBOL `ALTER`](languages/cobol.md#alter) |
| The text interpreter's parse position | [Forth `>in`](languages/forth.md) |
| Which files exist, plus `MAKE_RESTARTS` | [Make](languages/make-cmake.md#gnu-make) |
| Regex captures rebuilt every pass | [CMake](languages/make-cmake.md#cmake) |
| The source text of functions | [APL `⎕CR`/`⎕FX`](languages/apl.md#2-self-modifying-functions-apl-weird) |
| Document order in a markup file | [XAML](languages/csharp-linq-xaml.md#xaml) |
| One line of text | [sed](languages/regex.md#gnu-sed) |
| The data stack | [Forth](languages/forth.md) |

A reader who arrives for one meets the rest. That is the point.

## Backtracking, side effects and error handling

### Backtracking as a program

A backtracking engine tries a choice, and if later steps fail it goes back and tries another. The entries turn that around: *do the work in side effects, then fail on purpose.*

- **Perl, PCRE2 and pcre2grep** run the whole demo inside one match and end with `(*COMMIT)(*FAIL)`, so the match returns false after every row is written.
- **What survives a failed branch is the whole lesson.** Perl's `local` variables unwind; its `INSERT`s and `print`s do not. PCRE2's C struct does not rewind at all. `pcre2grep`'s statements have already committed. **.NET** cannot do it: a failed `Match` discards captures, so that entry *must* return true.
- **`(*COMMIT)`** stops the engine retrying shorter loops, which would run the finalizer more than once.

### Side effects in pipelines

LINQ, Haskell and XAML each put an effect inside something that looks like a pure description. The rule that falls out: **if an effect lives in a lazy structure, whoever reads the structure decides whether and when the effect happens.** Haskell's `evaluate (length cards)` and LINQ's final `Aggregate` are both "force it now".

### Errors as control flow

| Technique | Entry |
| --- | --- |
| A constraint violation *is* the stop rule: `CHECK(ok=1)` fires and the named error is announced | [Make](../src/make-gnu/README.md), [CMake](../src/cmake/README.md), [pcre2grep](../src/regex-pcre2grep/README.md) |
| Arithmetic overflow *is* the stop rule: `ON SIZE ERROR` | [COBOL](languages/cobol.md#alter) |
| A program's exit code steers the match | [pcre2grep](languages/regex.md#pcre2grep-exit-codes-as-control-flow) |
| A process exits 1 on purpose, and the wrapper maps it back to 0 | [sed](languages/regex.md#gnu-sed) |
| A runaway program is caught by a timeout, not an error | [APL weird](languages/apl.md#2-self-modifying-functions-apl-weird) |
| An unexpected failure code is deliberately *not* "no match" (`PCRE2_ERROR_CALLOUT`, not `-1`) | [PCRE2](languages/regex.md#pcre2-callouts-as-an-instruction-set) |

Notice that **`CHECK(demo_only=1)` appears in nearly every entry**: a table that makes a non-demo row unrepresentable, which each `check.sh` tries to violate. That is error handling used as a *guarantee* rather than a control flow, and a pattern worth keeping.

## Read next

[Problems overcome](problems-overcome.md), [blocking problems](blocking-problems.md), [exercises](exercises.md).
