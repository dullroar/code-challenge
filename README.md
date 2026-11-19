# Code Challenge - Learn Programming the Weird Way!

> **40 challenges in 29 languages**
<!-- Keep this line current whenever an entry is added: challenges = the folders in src/; languages = the distinct ids that entries list under `languages:` (the same languages as the book's Index of languages). `python lessons/book/build.py --check` prints both numbers and warns when this line is stale. -->

A series of responses to a code challenge that has morphed into a set of educational exercises about programming languages and how to think about programming languages. **New: [Learn Programming the Weird Way!](lessons/README.md)**, a set of lessons built on these examples. The book is numbered from v3 on (v4 adds a picture of how every program runs, and a chapter on events): see [what each version added](lessons/book/VERSIONS.md).

**WEIRD** stands for **Weird Execution, Indirect Results and Data**. The W is recursive. At least the programs have a stop rule.

## Why this exists

The first version was a [2008 classroom exercise](/docs/My%20Code%20Challenge.pdf), built to put new C# 3.0 and .NET 3.x features on display. Keeping the one-statement rule and porting it to new languages turned out to be a great way to learn what those languages actually let you do, once you push past the part the tutorials cover. Each entry answers the same question in its own accent: *how far can this language's own machinery - its iterators, its regex engine, its markup parser, its build tool - be pushed before it starts acting like a general-purpose program?*

It is a joke with a serious job inside it. Underneath every entry is a real lesson in a real language construct - LINQ, XAML, GNU Make, regular expressions, iterators, callouts - taught by pushing that construct until it does something its own documentation would not think to show you. That is why every folder's README has a **How the stunt works** section: read it, and you have learned the construct, not just watched a trick. The entertainment gets you in the door; the "oh, THAT'S how that actually works" is what you leave with. The full curriculum, with exercises, is in **[Learn Programming the Weird Way!](lessons/intro.md)**.

The deeper point, the one worth keeping after the jokes wear off: **THERE ARE NO BLOCKERS, JUST NOT ENOUGH IMAGINATION.**

It has turned into a small, friendly contagion. **Ken caught it too.** What started as one C# program has grown into a collection written by more than one person, and it is still growing.

## Psst, hey kid

**Try this at home!** **Don't tell the boss!**

You've spent years writing clean code: small functions, meaningful names, tests. *Boring.* Over here, there's a `for` loop with an empty body that opens a database, starts a thread, draws a window and fades it in and out. All before the first semicolon is done being weird.

You know you want to write beautifully wrong code. **You know you do.**

## Want to learn from it?

**[Learn Programming the Weird Way!](lessons/README.md)** *Programs you shouldn't write. Language features you should understand.* Lessons by [goals](lessons/goals.md), by [computer science concept](lessons/cs/README.md), by [language](lessons/languages/README.md) (including [COBOL's `ALTER`](lessons/languages/cobol.md#alter) and [APL on the whiteboard](lessons/languages/apl.md)) and by [solution pattern](lessons/patterns.md), plus [problems overcome](lessons/problems-overcome.md), [blocking problems](lessons/blocking-problems.md) and [exercises](lessons/exercises.md) you can run in a container.

## Ready to play?

The rules, the shared demo and the do's and don'ts live in **[`CHALLENGE.md`](CHALLENGE.md)**. Pick a language. Pick a constraint. Make something terrible that works. Sending it in? See **[`CONTRIBUTING.md`](CONTRIBUTING.md)**.

## The results so far

**Want to run one without trusting it?** Every Linux entry (including the Rust/GTK and Go ones) has its own tiny, locked-down **Docker container** that runs it with no network and shows you what it did, and every Windows or GUI entry runs in a throwaway **Windows Sandbox**. See **[`SANDBOX-SETUP.md`](SANDBOX-SETUP.md)** for the one-time setup, then open the folder's README (linked in the table below) and look for its **Run it in a container** or **Run it in Windows Sandbox** section for the one command.

Every entry builds the same small demo: make up some *Meetings / Coding / Debugging / Learning* time-card hours, save them to a local **DEMO ONLY** SQLite file, stop once the total passes 40 (the two LINQ entries use a fixed 40-hour week instead, and a total of exactly 40 continues in every other entry except `xaml`, which can deal at most four cards), and show the result. Nothing here touches a real time-reporting system - see the [disclaimer](#disclaimer).

**ALL OF THESE ARE TESTED AND WORK AS ADVERTISED.** Remember that while reading the code.

## Disclaimer

**DEMO ONLY.** Every record any of these programs writes is flagged as demo data in a throwaway local file/SQLite database. None of it connects to, or should ever be used for, a real time-reporting system. And please do **not** try any of this at work. Waste your own tokens. :)

| Version | By | The stunt | Teaches you | Folder |
| --- | --- | --- | --- | --- |
| **APL** | Jim | Five rolls and one take-while: no loop anywhere | That array thinking can replace control flow | [`src/apl`](src/apl/README.md) |
| **APL, weirder** | Jim | Each timecard is a function that copies its own source with `⎕CR`, rewrites it and defines the copy with `⎕FX`; compress over that source is the stop rule | Self-replicating functions instead of loops and `if` | [`src/apl-weird`](src/apl-weird/README.md) |
| **AWK** | Jim | One `while` in a `BEGIN` block, written to run unchanged on gawk, mawk, the one-true-awk and busybox awk | Portable POSIX awk, and exactly where the four implementations disagree | [`src/awk`](src/awk/README.md) |
| **AWK, weirder** | Jim | gawk reads `/dev/urandom` with `RS="[0-9]"`, so each digit (`RT`) is a die roll and each record a card; `t > 40 { exit }` is the stop rule, with no loop, `if` or random call | A regex record separator, `RT` and awk's implicit main loop | [`src/awk-weird`](src/awk-weird/README.md) |
| **C# (the original)** | Jim | Empty-body `for`; everything else lives in its three clauses | Runtime XAML, LINQ, EF Core, WPF animation | [`src/ModernChallenge1`](src/ModernChallenge1/README.md) |
| **COBOL** | Ken | `PERFORM DRAW-CARD UNTIL OVER-FORTY`: the stop rule is declared as data on the total, not coded in the procedure | A stop rule declared as data, and a number's picture doing your rounding | [`src/cobol`](src/cobol/README.md) |
| **COBOL, weirder** | Ken | No `IF`, `PERFORM` or `UNTIL`: `ALTER` rewires a `GO TO` at run time, and a two-digit field overflowing is the stop rule | Why structured programming won, via self-rewriting control flow | [`src/cobol-weird`](src/cobol-weird/README.md) |
| **ed, weirder** | Jim | GNU `ed` computes the whole program: line addresses order the categories, a rewrite table turns digits into rows of marks, one global command joins each card to the total above it, and a regex over the marks is the stop rule | Text rewriting, state in unary and a failed substitution as an `if` | [`src/ed-weird`](src/ed-weird/README.md) |
| **Ex, weirder** | Jim | A one-line program is copied into a register and run with `@`. Editor marks do the arithmetic, and a tape of numbered lines holds the stop rule. It runs on nvi and Vim | Code as text, state outside the text and where nvi and Vim disagree | [`src/ex-weird`](src/ex-weird/README.md) |
| **Forth** | Jim | One `begin ... until`, and `outfile-execute` points the output at SQLite | A stack language as a whole program | [`src/forth`](src/forth/README.md) |
| **Forth, weirder** | Jim | No control-flow word and no variable: the state rides the data stack while the loop moves the text interpreter's own `>in` backwards | The parse position as a program counter | [`src/forth-weird`](src/forth-weird/README.md) |
| **Go** | Ken | The same challenge, serving a pulsing page in your browser | The same trick, as a one-request web server | [`src/GoChallenge1`](src/GoChallenge1/README.md) |
| **GNU tar** | Jim | The program is a tar archive: members are instructions, tar walks them, and the operator's `--to-command` gives them meaning. A passive inspector reads the same archive and runs nothing | Serialization versus execution, trust boundaries and a fail-closed interpreter | [`src/tar-gnu`](src/tar-gnu/README.md) |
| **GNU tar, weirder** | Jim | tar's checkpoints are the clock: one record written is one hour, and a state machine takes one step per tick. The archive's layout sets the pace | Logical clocks, event-driven control and implementation-dependent counts | [`src/tar-gnu-weird`](src/tar-gnu-weird/README.md) |
| **Haskell** | Jim | One pure function: random hours, `scanl1`, `span` | A lazy list and one `span` as the whole stop rule | [`src/haskell`](src/haskell/README.md) |
| **Haskell, weirder** | Jim | An infinite list of cards whose elements have side effects: each running total is read off the card before it, and forcing a cell writes its row | Lazy IO as control flow, knot-tied with `fix` and `fixIO` | [`src/haskell-weird`](src/haskell-weird/README.md) |
| **Java** | Ken | One bodiless `for`; an anonymous class holds the loop state | The same bodiless-loop trick, Java style | [`src/JavaChallenge1`](src/JavaChallenge1/README.md) |
| **JavaScript** | Jim | The original's bodiless `for`, in Node.js: an object for state, `node:sqlite` and a timer that pulses the DEMO ONLY line on a terminal | The `for` clauses, the comma operator and the event loop | [`src/javascript`](src/javascript/README.md) |
| **JavaScript, weirder** | Jim | No loop statement. Three closures make the cards, and an iterator pipeline pulls them one at a time. `reduce` adds up the finished list, because it cannot stop early | Closures, lazy iteration and why `reduce` cannot stop | [`src/javascript-weird`](src/javascript-weird/README.md) |
| **JavaScript, event-driven** | Jim | No loop statement and no pipeline. Ten listeners on one `EventEmitter` are the whole program, and each emits the event that the next one waits for. `setImmediate` gives the event loop a turn between cards, so the call stack never grows | Events, callbacks, the event loop and why a synchronous `emit()` is not asynchronous | [`src/javascript-events`](src/javascript-events/README.md) |
| **Kotlin** | Ken | The same challenge, built as a sequence | The same trick, with Kotlin's sequence builders | [`src/KotlinChallenge1`](src/KotlinChallenge1/README.md) |
| **LINQ, fluent chain** | Jim | One LINQ method chain is the entire program | LINQ method chains, end to end | [`src/LinqChallenge1`](src/LinqChallenge1/README.md) |
| **LINQ, query expression** | Jim | Nearly every line is `from`/`where`/`let`/`select` | C# query syntax, pushed as far as it goes | [`src/LinqChallenge2`](src/LinqChallenge2/README.md) |
| **Lisp** | Jim | One `LOOP` form that sums, collects and stops, in Common Lisp | `LOOP` clause order, structs and hand-written ISO-week arithmetic | [`src/lisp`](src/lisp/README.md) |
| **Lisp, weirder** | Jim | Each card is a CLOS method chained through a class hierarchy; the built-in `or` method combination stops at the first true result | Method combination as control flow | [`src/lisp-weird`](src/lisp-weird/README.md) |
| **m4** | Jim | A macro whose last word is itself: m4 rescans its own output, and a Park-Miller generator is built from 32-bit `eval` | Quoting as lazy evaluation, in a language that is only text | [`src/m4`](src/m4/README.md) |
| **find, POSIX** | Jim | One `find` with four primaries and no variables: the walk digs the directory tree it is walking, and the path and the names are the counters | A tree walk as a loop, path patterns as lookup tables and what POSIX leaves unspecified | [`src/find-posix`](src/find-posix/README.md) |
| **find, GNU** | Jim | The same digging walk with every GNU extra: `%d` (depth) is the running total, `%T` is the ISO week, `-regex` is the stop rule, `-fprintf` writes the SQL to fd 3, and `-D rates` is find profiling the program | What GNU find's extras replace, and an optimizer that has nothing to reorder | [`src/find-gnu`](src/find-gnu/README.md) |
| **Make, CMake** | Jim | One bodiless `while()`; its condition is a regex machine | `while()` + regex as a tiny register machine | [`src/cmake`](src/cmake/README.md) |
| **Make, GNU** | Jim | No `$(shell)`; Make re-executes itself as the loop | Arithmetic and looping in plain Make syntax | [`src/make-gnu`](src/make-gnu/README.md) |
| **Python** | Ken | The same challenge, Python style | The same trick, in a language with no `;` loops | [`src/PythonChallenge1`](src/PythonChallenge1/README.md) |
| **RegEx, .NET** | Jim | Balancing groups only - no callouts, no code in the pattern | A regex as a stack-based counter | [`src/regex-dotnet`](src/regex-dotnet/README.md) |
| **RegEx, GNU sed** | Ken | The program is one line of text, rewritten until it's done | sed substitutions as a Markov algorithm | [`src/regex-sed`](src/regex-sed/README.md) |
| **RegEx, PCRE2** | Jim | Callout strings become opcodes for a bodiless C dispatcher | Regex callouts as a tiny instruction set | [`src/regex-pcre2`](src/regex-pcre2/README.md) |
| **RegEx, pcre2grep** | Jim | No custom code at all: a stock `pcre2grep`, one command line | Program exit codes as control flow | [`src/regex-pcre2grep`](src/regex-pcre2grep/README.md) |
| **RegEx, Perl** | Jim | One `=~` match does everything, then deliberately returns false | Executable code inside a live regex match | [`src/regex-perl`](src/regex-perl/README.md) |
| **Rust** | Jim | No `;`, `let` or `return` in `main` - a test enforces it | Iterators and closures as control flow | [`src/RustChallenge1`](src/RustChallenge1/README.md) |
| **Tcl** | Jim | A `while` loop over dicts, SQL parameters bound straight from Tcl variables and an optional Tk window that is tested headless | Idiomatic Tcl: braces, dicts, `db eval` bindings and Tk | [`src/tcl`](src/tcl/README.md) |
| **Tcl, weirder** | Jim | The program is text in a SQLite table, fetched by an overridden `unknown`; a recursive trigger is the loop and `INSERT ... WHERE` is the stop rule | Code as data, and a database trigger as control flow | [`src/tcl-weird`](src/tcl-weird/README.md) |
| **XAML** | Jim | The program *is* a `.xaml` file, run by the parser that loads it | XAML as a runtime interpreter, not just markup | [`src/xaml`](src/xaml/README.md) |

Every "Teaches you" cell above is a promise, not just a label: open the folder's README and that is genuinely what you will walk away understanding. For the same material organized by [language](lessons/languages/README.md) and by [mechanism](lessons/patterns.md), with exercises, see [Learn Programming the Weird Way!](lessons/README.md).

## Repository layout

```text
CHALLENGE.md                  # the rules - start here if you want to play
CONTRIBUTING.md               # how to send in an entry, and how it gets reviewed
SANDBOX-SETUP.md              # how to install Docker / Windows Sandbox to run entries safely
lessons/                      # Learn Programming the Weird Way!: lessons, patterns, blockers, exercises
sandbox/                      # where entries get run safely: Docker images, Windows Sandbox, the Actions gate
build.gradle, gradlew*        # root Gradle wrapper: runs the Java, Kotlin, Python, and Go ports
docs/
  My Code Challenge.pdf       # anonymized source presentation
  stacked-bar-charts.md       # the 2013 no-code-behind blog post that inspired the XAML entry
  images/                     # screenshots used in the subfolder READMEs
src/
  ModernChallenge1/           # C#: the original, modernized for .NET 10
  RustChallenge1/             # Rust + GTK 4 companion for WSL
  xaml/                       # XAML: the program is a .xaml file, run at run time
  regex-perl/                 # Perl: one executable-regex match is the program
  regex-pcre2/                # PCRE2: callout strings as opcodes, a C dispatcher
  regex-pcre2grep/            # pcre2grep: callouts run sqlite3, exit codes steer the match
  regex-dotnet/               # .NET: balancing groups only, and the walls it hits
  regex-sed/                  # GNU sed (Ken): the program is one line of text, rewritten by substitutions
  cobol/                      # COBOL (Ken): PERFORM ... UNTIL, with the stop rule declared as data
  cobol-weird/                # COBOL (Ken): no IF or PERFORM; ALTER rewires a GO TO and an overflow stops it
  LinqChallenge1/             # LINQ: one fluent method-chain expression statement
  LinqChallenge2/             # LINQ: one SQL-like query-expression statement
  make-gnu/                   # GNU Make: no $(shell); Make re-executes itself as the loop
  find-posix/                 # POSIX find: one find; the walk digs the tree it walks, names are counters
  find-gnu/                   # GNU find: the same walk, with %d, %T, -regex, -fprintf and -D rates
  cmake/                      # CMake: one bodiless while(), a regex machine in its condition
  apl/                        # APL: five rolls and one take-while
  apl-weird/                  # APL: functions that copy themselves with ⎕CR and ⎕FX
  haskell/                    # Haskell: one pure function, scanl1 and span
  haskell-weird/              # Haskell: an infinite list of cards whose elements write their own rows
  ed-weird/                   # ed: the buffer is the machine; a failed substitution is the if
  ex-weird/                   # Ex: a register that runs itself; marks are registers (nvi and Vim)
  tar-gnu/                    # GNU tar: the archive is a serialized program; tar --to-command runs it
  tar-gnu-weird/              # GNU tar: checkpoints are the clock of a state machine
  javascript/                 # JavaScript (Node.js): the original's bodiless for
  javascript-weird/           # JavaScript (Node.js): closures and a lazy iterator, no loop statement
  javascript-events/          # JavaScript (Node.js): ten listeners on an EventEmitter, no loop statement
  forth/                      # Forth: one begin ... until and a pipe to SQLite
  forth-weird/                # Forth: no control-flow words; the loop rewinds >in
  lisp/                       # Common Lisp: one LOOP form
  lisp-weird/                 # Common Lisp: a class hierarchy is the loop; the or method combination stops it
  m4/                         # m4: a macro that expands itself until ifelse says stop
  tcl/                        # Tcl: a while loop, dicts, bound SQL parameters, optional Tk window
  tcl-weird/                  # Tcl: the program lives in SQLite; a recursive trigger is the loop
  awk/                        # AWK: portable POSIX awk, one while in BEGIN
  awk-weird/                  # AWK (gawk): RS="[0-9]" over /dev/urandom; each digit is a die roll
  JavaChallenge1/             # Java (Ken): the same bodiless-loop trick, Java style
  KotlinChallenge1/           # Kotlin (Ken): the same challenge, built as a sequence
  PythonChallenge1/           # Python (Ken): the same challenge, Python style
  GoChallenge1/               # Go (Ken): the same challenge, serving a pulsing page in your browser
LICENSE
```

Ken's COBOL, Java, Kotlin, Python and Go ports live here too, folded in with full credit intact in each one's README.

Ready to dig into any of them as a lesson? Start at [Learn Programming the Weird Way!](lessons/README.md).
