# By overall goals

Three goals sit under everything in [Learn Programming the Weird Way!](README.md). Each one is a different answer to "why would anyone do this?"

## 1. Teach computation, not just computational tricks

A trick is "this incantation makes the loop stop". Computation is "here is the machine that is running, and here is where its state lives."

Every weird entry forces you to name the machine hiding inside a language. Once you can name it, the trick is just one program for that machine.

<!-- BEGIN GENERATED machines -->
| Language / tool | The machine it really is | Where the program's state lives | Lesson |
| --- | --- | --- | --- |
| .NET regex | A counter built from a stack | Balancing-group capture stacks | [regex](languages/regex.md#net-balancing-groups) |
| APL | An array machine, with code that is also an array | Arrays, and the source text of functions | [apl](languages/apl.md#2-self-modifying-functions-apl-weird) |
| AWK | A record-processing loop that you can aim at any byte stream | The input stream and the record separator `RS` | [awk](languages/awk.md#2-records-from-a-random-byte-stream-awk-weird) |
| C# `for` | Three expression slots | Fields of one anonymous object | [csharp-linq-xaml](languages/csharp-linq-xaml.md#the-original-modernchallenge1) |
| CMake | A register machine | `CMAKE_MATCH_1`..`5`, rebuilt every pass | [make-cmake](languages/make-cmake.md#cmake) |
| COBOL | A program whose jump targets are mutable | The target of one `GO TO` | [cobol](languages/cobol.md#alter) |
| Common Lisp | A method dispatcher with a pluggable combination rule | The class precedence list, and each method's return value | [lisp](languages/lisp.md#method-combination-as-control-flow) |
| ed | A string-rewriting machine with line addresses | The editor buffer: one line per card, and marks (x) that are added by joining lines | [editors](languages/editors.md#the-buffer-is-the-machine) |
| Ex | A register machine whose registers are editor marks, and whose program is a register that runs itself | The marks (where we are on a tape of numbered lines), the first line of the buffer (the next card), and registers a, d and n | [editors](languages/editors.md#a-program-you-can-edit) |
| Forth | A stack machine with a movable instruction pointer | The data stack and the parse position `>in` | [forth](languages/forth.md) |
| GNU find | A tree walk that grows the tree it is walking, with find itself reading the depth and the clock | The path from the start directory to the directory being visited; its depth is the running total | [find](languages/find.md) |
| GNU Make | A dependency graph that can restart itself | Which `.tc-N.mk` files exist, and `MAKE_RESTARTS` | [make-cmake](languages/make-cmake.md#gnu-make) |
| GNU sed | A string-rewriting system (a Markov algorithm) | One line of text, rewritten until no rule applies | [regex](languages/regex.md#gnu-sed) |
| GNU tar | A tape reader (tar) feeding a five-word interpreter | The archive's members, which are the program, plus one SQLite row that says whether the run has halted or faulted | [tar](languages/tar.md#a-program-that-is-an-archive) |
| GNU tar | A finite-state machine, driven by a logical clock that tar supplies | One SQLite row (the machine's registers) and the number of records tar has written | [tar](languages/tar.md#the-archive-is-the-clock) |
| Haskell | A lazy graph reducer | Thunks: which parts of a list have been demanded | [haskell](languages/haskell.md#lazy-io-as-control-flow) |
| JavaScript | Three expression slots | Properties of one object literal | [javascript](languages/javascript.md#the-bodiless-for-in-node) |
| m4 | A text-rescanning machine | The input stream: whatever macro text has not been read yet | [m4](languages/m4.md#a-loop-made-of-rescanning) |
| PCRE2 | A backtracking search with hooks | A C struct that never rewinds | [regex](languages/regex.md#pcre2-callouts-as-an-instruction-set) |
| pcre2grep | A backtracking search that runs one program per callout | SQLite rows, and the exit code of each callout | [regex](languages/regex.md#pcre2grep-exit-codes-as-control-flow) |
| Perl | A backtracking search with hooks | `local` variables that unwind (effects do not) | [regex](languages/regex.md#perl-code-inside-the-match) |
| POSIX find | A tree walk that grows the tree it is walking | The path from the start directory to the directory being visited | [find](languages/find.md) |
| Tcl | A string-command interpreter whose command lookup can be hooked | A TEMP table of proc source, and the depth of trigger recursion | [tcl](languages/tcl.md#sqlite-as-the-program) |
| XAML | An object-graph constructor that runs methods as it parses | Document order, plus "carrier" arrays | [csharp-linq-xaml](languages/csharp-linq-xaml.md#xaml) |
<!-- END GENERATED machines -->

Once you have seen four different homes for "where am I in the program?", you stop treating the call stack and the loop counter as laws of nature. That is the first goal: separate *control flow*, *state*, *evaluation order* and *side effects*, which most languages weld together, and watch them come apart.

See [patterns](patterns.md) for the same material organized by mechanism instead.

## 2. Different ways to solve problems, limited only by imagination

The repo's motto is **THERE ARE NO BLOCKERS, JUST NOT ENOUGH IMAGINATION.** The same ten lines of requirements have now been solved by a loop with no body, a regex that returns false on purpose, a Makefile that re-runs itself, a list whose elements write to a database when you look at them, and a function that writes its own successor.

Three habits to take from that:

- **Ask where the work is allowed to happen.** The rule was one statement, so the loop's clauses, a LINQ pipeline, a parser, an iterator and a regex engine's backtracking all became places for work. Which parts of your usual stack are "just the way it's done" and which are actually required?
- **Compare the weird with the ordinary.** [`apl`](../src/apl/README.md) uses five rolls and a take-while; [`apl-weird`](../src/apl-weird/README.md) uses a function that copies and rewrites itself. [`haskell`](../src/haskell/README.md) uses one `span`; [`haskell-weird`](../src/haskell-weird/README.md) puts the effects inside the list. [`lisp`](../src/lisp/README.md) is one `LOOP`; [`lisp-weird`](../src/lisp-weird/README.md) has no loop at all and lets a class hierarchy do the counting. [`tcl`](../src/tcl/README.md) is a `while`; [`tcl-weird`](../src/tcl-weird/README.md) keeps its code in a database table. The pair shows what each approach buys and what it costs.
- **Document walls honestly.** [`CHALLENGE.md`](../CHALLENGE.md) says "A well-demonstrated limitation is more interesting than cheating around it." The [blocking problems](blocking-problems.md) page is built from those walls.

Think outside the box, then write down where the box turned out to be load-bearing. See [problems overcome](problems-overcome.md).

## 3. Understand your language(s): strengths and weaknesses

You do not know what a feature is for until you know what happens when you push on it.

| Language | Strength the weird version reveals | Weakness it reveals |
| --- | --- | --- |
| APL | Array thinking replaces most loops; code is data | Hard to read, hard to type, and hard to whiteboard (see [APL](languages/apl.md)) |
| AWK | The record loop and pattern-action rules make parsing and filtering tiny | The portable subset is small, and the standard stops short of regex `RS` and `RT`, which are gawk extensions |
| C# | Expression-rich: LINQ, anonymous types, reflection and runtime XAML can all sit in one `for` header | `void` does not compose; `DbContext` is not thread-safe; statements, not expressions, are required at the top level |
| CMake | `while()` re-expands its condition, and `MATCHES` leaves captures in variables | Its regex has no counted repetition, lookahead or backreferences |
| COBOL | Decimal arithmetic and field pictures that do rounding and range checks as data | Control flow that `ALTER` can make unreadable; fixed columns; a vocabulary that is hard to extend |
| Common Lisp | The reader, macros and the object system are all programmable, so control flow can be rebuilt from types | The result is invisible: nothing in the code says "loop", and tools show only generic-function calls |
| Forth | Tiny, total control: you can reach the interpreter's own parse position | No guard rails: stack effects are by convention only |
| GNU Make | Dependency tracking and restart are free | It is a build tool: no integers, no real I/O, and timestamp granularity matters |
| Haskell | Laziness makes "how much to read" the stop rule | Laziness makes "when does this run?" part of the meaning once effects are involved |
| m4 | Quoting gives lazy evaluation in a language with nothing else; ideal for generating text | Everything is global text: no scope, no types, and one missing bracket is infinite recursion |
| Regex engines | Backtracking is a general search; callouts and code blocks make it a program | Performance cliffs; engine differences; failure discards captures (in .NET) |
| Tcl | Everything is a string command, so code can be loaded, hooked and generated from anywhere (even a database row) | Two levels of quoting, and strings all the way down: errors surface late |
| XAML | A declarative format, so tools can read and write it | The parser can run arbitrary methods, which declarative formats are not meant to do |

Every language page also tags each trick as **guaranteed**, **implementation-permitted** or **accidentally exploited**, as explained in the [intro](intro.md#three-kinds-of-knowledge). A strength you rely on is only as strong as the tag next to it.

Continue to the [computer science behind it all](cs/README.md): the same ideas, one concept at a time, with a paragraph on why each exists and when to use it. Then see the [languages](languages/README.md).
