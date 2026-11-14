# By overall goals

Three goals sit under everything in [Learn Programming the Weird Way!](README.md). Each one is a different answer to "why would anyone do this?"

## 1. Teach computation, not just computational tricks

A trick is "this incantation makes the loop stop". Computation is "here is the machine that is running, and here is where its state lives."

Every weird entry forces you to name the machine hiding inside a language. Once you can name it, the trick is just one program for that machine.

| Language / tool | The machine it really is | Where the program's state lives | Lesson |
| --- | --- | --- | --- |
| GNU sed | A string-rewriting system (a [Markov algorithm](../src/regex-sed/README.md#markov-algorithms-computing-by-find-and-replace)) | One line of text, rewritten until no rule applies | [regex](languages/regex.md#gnu-sed) |
| .NET regex | A counter built from a stack | Balancing-group capture stacks | [regex](languages/regex.md#net-balancing-groups) |
| PCRE2 / Perl | A backtracking search with hooks | A C struct, or `local` variables that unwind | [regex](languages/regex.md) |
| GNU Make | A dependency graph that can restart itself | Which `.tc-N.mk` files exist, and `MAKE_RESTARTS` | [make-cmake](languages/make-cmake.md#gnu-make) |
| CMake | A register machine | `CMAKE_MATCH_1`..`5`, rebuilt every pass | [make-cmake](languages/make-cmake.md#cmake) |
| Forth | A stack machine with a movable instruction pointer | The data stack and the parse position `>in` | [forth](languages/forth.md) |
| COBOL (`ALTER`) | A program whose jump targets are mutable | The target of one `GO TO` | [cobol](languages/cobol.md#alter) |
| Haskell | A lazy graph reducer | Thunks: which parts of a list have been demanded | [haskell](languages/haskell.md) |
| APL | An array machine, with code that is also an array | Arrays, and the source text of functions | [apl](languages/apl.md) |
| XAML | An object-graph constructor that runs methods as it parses | Document order, plus "carrier" arrays | [csharp-linq-xaml](languages/csharp-linq-xaml.md#xaml) |
| C# `for` | Three expression slots | Fields of one anonymous object | [csharp-linq-xaml](languages/csharp-linq-xaml.md#the-original-modernchallenge1) |

Once you have seen four different homes for "where am I in the program?", you stop treating the call stack and the loop counter as laws of nature. That is the first goal: separate *control flow*, *state*, *evaluation order* and *side effects*, which most languages weld together, and watch them come apart.

See [patterns](patterns.md) for the same material organized by mechanism instead.

## 2. Different ways to solve problems, limited only by imagination

The repo's motto is **THERE ARE NO BLOCKERS, JUST NOT ENOUGH IMAGINATION.** The same ten lines of requirements have now been solved by a loop with no body, a regex that returns false on purpose, a Makefile that re-runs itself, a list whose elements write to a database when you look at them, and a function that writes its own successor.

Three habits to take from that:

- **Ask where the work is allowed to happen.** The rule was one statement, so the loop's clauses, a LINQ pipeline, a parser, an iterator and a regex engine's backtracking all became places for work. Which parts of your usual stack are "just the way it's done" and which are actually required?
- **Compare the weird with the ordinary.** [`apl`](../src/apl/README.md) uses five rolls and a take-while; [`apl-weird`](../src/apl-weird/README.md) uses a function that copies and rewrites itself. [`haskell`](../src/haskell/README.md) uses one `span`; [`haskell-weird`](../src/haskell-weird/README.md) puts the effects inside the list. The pair shows what each approach buys and what it costs.
- **Document walls honestly.** [`CHALLENGE.md`](../CHALLENGE.md) says "A well-demonstrated limitation is more interesting than cheating around it." The [blocking problems](blocking-problems.md) page is built from those walls.

Think outside the box, then write down where the box turned out to be load-bearing. See [problems overcome](problems-overcome.md).

## 3. Understand your language(s): strengths and weaknesses

You do not know what a feature is for until you know what happens when you push on it.

| Language | Strength the weird version reveals | Weakness it reveals |
| --- | --- | --- |
| C# | Expression-rich: LINQ, anonymous types, reflection and runtime XAML can all sit in one `for` header | `void` does not compose; `DbContext` is not thread-safe; statements, not expressions, are required at the top level |
| COBOL | Decimal arithmetic and field pictures that do rounding and range checks as data | Control flow that `ALTER` can make unreadable; fixed columns; a vocabulary that is hard to extend |
| Haskell | Laziness makes "how much to read" the stop rule | Laziness makes "when does this run?" part of the meaning once effects are involved |
| Forth | Tiny, total control: you can reach the interpreter's own parse position | No guard rails: stack effects are by convention only |
| GNU Make | Dependency tracking and restart are free | It is a build tool: no integers, no real I/O, and timestamp granularity matters |
| CMake | `while()` re-expands its condition, and `MATCHES` leaves captures in variables | Its regex has no counted repetition, lookahead or backreferences |
| Regex engines | Backtracking is a general search; callouts and code blocks make it a program | Performance cliffs; engine differences; failure discards captures (in .NET) |
| APL | Array thinking replaces most loops; code is data | Hard to read, hard to type, and hard to whiteboard (see [APL](languages/apl.md)) |
| XAML | A declarative format, so tools can read and write it | The parser can run arbitrary methods, which declarative formats are not meant to do |

Every language page also tags each trick as **guaranteed**, **implementation-permitted** or **accidentally exploited**, as explained in the [intro](intro.md#three-kinds-of-knowledge). A strength you rely on is only as strong as the tag next to it.

Continue to [languages](languages/README.md).
