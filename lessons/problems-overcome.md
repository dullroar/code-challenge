# Problems overcome

What stood in each approach's way, and how it got around it. Each row came from a wall someone actually hit; most are written up in the entry's "Gotchas worth knowing" section.

The rows are grouped by the *kind* of obstacle, so you can read one theme across many languages. The order goes from the outside in: first the shape of the program, then where its state lives, then its control flow, then when things run, then the limits of the host, and last how failure is made visible. Inside each group, rows follow the order in which they were found.

## Squeezing the program into one statement

The challenge allows one statement. These rows are about fitting a whole program into the shape a language allows.

| Approach | The obstacle | How it was overcome | What it teaches |
| --- | --- | --- | --- |
| **C#** (`ModernChallenge1`) | A `for` initializer allows only one declaration, but the loop needs seven kinds of state | One anonymous object with a field per piece of state | Anonymous types are an expression-level record |
| **C#** | `void` methods (`Add`, `Show`, `Close`) do not fit where a value is needed | `new Func<T>(() => { effect(); return value; }).Invoke()` in place | Statements can be lifted into expressions |
| **LINQ** | A statement must end in an invocation, so `x is var r && ...` cannot bind intermediate results | Nest `Enumerable.Repeat(x, 1)` calls to turn a value back into a one-element sequence | Know which expression shapes are legal as statements |
| **Rust** | No `;`, `let` or `return` in `main` | `successors(...)`; `match x { name => ... }` as `let`; tuple projection as the comma operator | Iterators and closures as control flow |
| **Go** | A three-clause `for` cannot hold statements | Helper functions (`Seq`, `After`) in a separate file | Cost of the constraint made explicit |
| **Python** | No `;` loops and no statement expressions | `iter(<lambda>, False)` plus tuple-and-`[-1]` | Expressions standing in for statements |
| **Kotlin** | No `for(;;)` | `generateSequence`, ending on null | A sequence is a loop |
| **JavaScript** (`javascript`) | After `let i = ...` in a `for` header, a comma starts the next *declarator*; it is not the comma operator, so the initializer cannot also run statements | The state object goes through an arrow function that finishes it with the comma operator | Know which comma you have |
| **JavaScript** (`javascript-events`) | `emit()` runs its listeners before it returns, so a chain of events is a recursion with one more level for every card, and a throw in a listener goes to the caller | `setImmediate` between cards, so the stack unwinds, and a `try` in every listener that turns a throw into one `failed` event | Know which calls return before the next one starts |

## No variables? Find somewhere else to keep state

Some languages have no variables, or have a place for them that does not fit the job. The state went into a stack, a pile of captures, a text line, a list of letters or a database.

| Approach | The obstacle | How it was overcome | What it teaches |
| --- | --- | --- | --- |
| **XAML** | Markup has no variables | "Carrier" arrays filled in place by successive `ObjectDataProvider` calls | Mutable buffers as variables |
| **Forth** | Stack values must be shared between printing and SQL | `dup .row` keeps a copy; `outfile-execute` points output at the pipe | Output redirection as a language feature |
| **Forth weird** | No variables, no loop words | State on the stack; `>in` rewound as a program counter; the flag (-1/0) as a mask | The interpreter's own state is reachable |
| **GNU Make** | No arithmetic, no loop, no `$(shell)` | Numbers as lists of `x`; re-execution via `include` of generated makefiles | Restart is a loop |
| **Perl regex** | Statements cannot live in a pattern | `(?{ })` code blocks and `(??{ })`; package variables with `local` | Backtrack-aware state |
| **pcre2grep** | No variables in the pattern, and callouts do not search `PATH` | State lives in SQLite; absolute program paths | Externalize state |
| **.NET regex** | A regex has no counter | Balancing groups: a stack of captures | A stack is a counter |
| **sed** | No arithmetic and no variables | Tally marks, a text-encoded shift register, substitution rules | A Markov algorithm computes |
| **m4** | A string that grows, in a language with no variables | `defn` returns a macro's text, so a macro redefines itself as itself plus more | State can be text that rewrites itself |
| **find** | No variables, no arithmetic and no counter | Names and paths carry the state: a directory is an hour, and its name is the last digit or the hours left. `-path` patterns count by matching `/0/` as often as needed | The file system is memory |
| **ed weird** | `ed` has no arithmetic and no numbers | Numbers are rows of `x` marks: adding is joining two lines, and rewrite rules turn marks into digits | Choose the representation that your operations can change |
| **Ex weird** | Ex has no arithmetic either | A mark is a register, and an address (`'t+17k t`) is the addition. A tape of numbered lines holds the decimal totals | The editor's own state (marks, the current line) is memory |
| **tar weird** | A command that tar runs for each checkpoint has no memory between calls | One SQLite row holds the registers, and one transaction is one transition | Persist the machine's state outside the callback |
| **JavaScript weird** | There should be no variable that other code can change | Three closures: each one keeps its state in captured variables that only it can reach | A closure is private state with a function attached |

## No loop? Build control flow out of something else

A loop is only one way to repeat. These rows turn a computed prefix, a rewritten jump, a restarting build or a class hierarchy into the repetition.

| Approach | The obstacle | How it was overcome | What it teaches |
| --- | --- | --- | --- |
| **XAML** | Markup has no loop or `if` | Four unrolled passes; SQL or `DataTable` expressions do the branching | Borrow an expression engine |
| **APL** | A loop with a data-dependent stop | Draw five (a bound that can never be too small), then take a computed prefix | Compute the answer, then trim it |
| **APL weird** | A function cannot copy itself... | `⎕CR` reads its source, `⎕FX` defines the rewritten copy | Code is a character matrix |
| **APL weird** | Dynamic scope clobbers the parent's variables | Each generated header redeclares locals (`Locals`) | Scope rules shape metaprogramming |
| **COBOL** | The loop condition must not be a comparison | `88`-level condition name on the total | Rules can be data |
| **COBOL weird** | No `IF`, `PERFORM`, `EVALUATE` or modulo | `ALTER` rewires one `GO TO`; a 2-digit overflow is the stop | Mutable control flow, overflow as decision |
| **Haskell** | A stop rule without a loop | `span` over lazy infinite lists | Laziness as control |
| **GNU Make** | A recipe expanding to nothing does not count as remaking a file | A trailing `@:` (shell no-op) | Expansion time vs. execution time |
| **Lisp weird** | A class must exist before another can inherit from it, and five near-identical classes and methods are tedious | A `defcard` macro writes each pair, tail first; the name-building code runs at compile time inside `eval-when` | Macros are programs that run before yours |
| **Tcl weird** | SQL cannot call Tcl, and Tcl cannot be given a library of code that is in a table | `db function tcl call` and an `unknown` override that defines procs from rows | The library path is yours to redefine |
| **find** | A search tool has no loop | The walk descends into the directory that `-exec mkdir` just made; each directory makes the next | A traversal that changes its own tree is a loop |
| **find GNU** | The portable line spells out every digit of the total | `%d` (depth) is the total and `%T` is the week, so the tables vanish | Use the tool's own measurements as values |
| **Tcl weird** | Widget rows with fragments (`pack -fill ...`) failed without a widget path | Each `ui` row is a whole command, run through `uplevel #0` | A table of strings, evaluated at the right scope |
| **tar** | tar must run the program, and the archive cannot ask for that | The operator's `--to-command` attaches the interpreter; tar's walk over the members is the loop | Authority comes from the command line, and not from the data |
| **ed weird** | `ed` has no `if` and no loop, and it refuses a global command inside a global command | One global command is the loop. A substitution that does not match is silently skipped inside it, so every `s` is an `if` | Find what the tool does on failure; it may be a conditional |
| **Ex weird** | A register can run itself, but the loop must also stop, and a failed search would end nvi | The tape's row for each total holds the next instruction: `@a` to go on, a comment to stop. The limit is data | A jump table makes the stop rule data |
| **JavaScript weird** | A fold (`reduce`) cannot stop early | The machine says `done` after the crossing card, and an iterator consumer stops there. `reduce` runs over the finished list | Pick the operation that can stop |

## When does it actually run? Order of evaluation

Lazy values, expanded recipes, quoted text and global separators all change *when* a piece of code runs. Each of these rows was a bug before it was a lesson.

| Approach | The obstacle | How it was overcome | What it teaches |
| --- | --- | --- | --- |
| **LINQ** | Effects must run in order inside lazy stages | Tuple left-to-right evaluation sequences `SaveChanges`; a final eager `Aggregate` forces the tail | Eager vs. lazy operators |
| **Haskell weird** | Effects must fire per cell, in order, on an infinite list | `fixIO` knot plus `unsafeInterleaveIO` around each cell | Evaluation order as program meaning |
| **Haskell weird** | A lazy `let` forced the cards after the pipe closed | `evaluate (length cards)` before commit | Laziness bites twice |
| **GNU Make** | `$(info)` output came out before SQLite's header | The report is a chain of phony targets | Make expands a recipe before it runs it |
| **CMake** | A failed `MATCHES` clears every register | Put the stop test first so the main match's captures survive | Order of side-effecting conditions |
| **m4** | Quoting: a loop that must not evaluate its own call early | `[tc_card()]` in brackets, so the call is only expanded after `ifelse` has chosen it | Eager arguments, lazy quotes |
| **find** | `*` in `-path` crosses `/`, so `*/1/b*` matched an earlier `1/b...` in the same path and the digit stuck at 2 | End every pattern on a fixed-width name (`b00` to `b18`), so the last segment is exactly where you think | Anchor the end of a pattern |
| **AWK weird** | `RS` applies to every read, so `getline` from `date` returned an empty week | Fetch the week before setting `RS`, then `close` the command | State that is global affects every reader |
| **tar weird** | tar does not stop when the stop rule fires, and keeps calling the command | A `done` flag makes every later tick change only an `idle` counter | Make the work after the end harmless, because you cannot make it not happen |
| **tar weird** | What one checkpoint counts depends on the mode (21 when creating, 10 when listing, 21 when extracting the same archive) | Only creation is used, and `check.sh` predicts the tick count from the layout | Say what a count counts |
| **Ex weird** | nvi runs a register of several lines from last to first; Vim runs it first to last | The program is **one line**, with bars | When two implementations differ, write what both agree on |
| **JavaScript** | An animation must not delay or change the computation | The timer starts in the condition's false branch, after everything is saved, and only on a terminal | A side effect that comes last cannot disturb the work |

## The host has limits: portability and implementation details

Integer width, timestamp precision, optimizer behavior, event loops and differences between implementations. None of this is in the clever part, and all of it can break the clever part.

| Approach | The obstacle | How it was overcome | What it teaches |
| --- | --- | --- | --- |
| **GNU Make** | WSL's coarse timestamps made a rewritten state file look unchanged | One new file per pass: "missing to present" is unambiguous | Don't trust mtime for state |
| **GNU Make / CMake** | `wt.exe` treats `;` as its own subcommand separator | Command lines contain no `;` | Know the host's separator rules |
| **CMake** | No `{n}` quantifier, lookahead or backreference | Literal 41-`x` test; subject and pattern rebuilt from the last pass's captures | Work within the weakest regex |
| **PCRE2** | The optimizer might skip callouts; the JIT does not support them | `PCRE2_NO_AUTO_POSSESS`, `_NO_START_OPTIMIZE`, `_NO_DOTSTAR_ANCHOR`; no JIT | Know what the optimizer may elide |
| **sed** | A timer without a clock | A catastrophic-backtracking regex calibrated to about 50 ms per frame | Performance cliffs are a resource |
| **Lisp** | SBCL has no ISO-week function, and a hand-written one can be wrong near New Year | The calendar arithmetic was written by hand and checked against `date(1)` on 22 edge dates, then against Python's `isocalendar` on 1,139 dates | Verify an algorithm against an independent oracle |
| **m4** | `eval` is 32-bit, so a generator's `16807 * seed` overflows silently (`2147483647*4` is `-4`) | Park-Miller with Schrage's trick keeps every intermediate value in 32 bits; checked against Python over 20,000 draws | Know the width of your integers |
| **m4** | `ifelse` with eight arguments warned "excess arguments": after the first group it continues in threes | `tc_pick` repeats the value under test in every group | Read the arity rules, not just the example |
| **Tcl** | A `tclsh` that has loaded Tk never exits at the end of the script | End with `catch {destroy .}` | Event loops outlive scripts |
| **Tcl weird** | A trigger cannot use a qualified table name in `INSERT` | The unqualified name inside the trigger | Know what each SQL clause lets you qualify |
| **AWK** | Function parameters that share a name with a global are flagged by `--lint` | Rename them; extra parameters are the locals | Scope in awk is by convention |
| **AWK** | `close()` returns different values in each awk (status, status x 256, always 0) | The entry only tests for non-zero; the READMEs say so, after testing all four awks | Test every implementation you claim to support |
| **AWK weird** | mawk has no `RT`, so the program reads forever | Documented as gawk-only; never run it without a memory limit and a timeout | A portable-looking failure is the worst kind |
| **find** | `mktemp -d` prints the path it made, and the path lands in the middle of the SQL | The line prints ` -- ` first, so the path becomes an SQL comment | Make the noise part of the language |
| **find** | Dice made by the first of several candidates to claim a directory print `mkdir` errors for the losers | One die per card; 62 characters do not divide by ten, so `Y` and `Z` are re-rolled on the character before | Prefer a design that cannot fail noisily |
| **find GNU** | `-quit` stops find before it prints the `-D rates` profile | Drop `-quit`; the stop rule digs nothing more and find runs out of tree | An early exit can skip the end-of-run report |
| **ed weird** | busybox `ed` has no `g`, `t`, `j` or `#` comments and cannot substitute on `^` | The check asserts that it cannot run the program, and the README says GNU ed only | A standard does not make two implementations equal |
| **Ex weird** | nvi will not start if it cannot write `/var/tmp/vi.recover`, and the sandbox root is read-only | The sandbox images link that folder to `/tmp` | A tool's startup needs are part of its interface |
| **Ex weird** | nvi writes its messages, and a note about having no terminal, to standard output | The launcher drops that one known line and fails on any other line that is not a card row | Check every line a tool prints |
| **JavaScript** | `crypto.randomInt` is a module function, and the global `crypto` is Web Crypto | `crypto.getRandomValues` for the default seed | Same name, different object |
| **JavaScript** | `mkdirSync(path, { recursive: true })` under `/proc` never returned (Node 24.15, Linux) | The error test uses a plain file as the parent folder | A negative test must not hang |

## Making failure visible and the rules enforceable

A stunt is only a lesson if you can tell when it fails, and if a test can try to break its rules.

| Approach | The obstacle | How it was overcome | What it teaches |
| --- | --- | --- | --- |
| **PCRE2** | A callout error could be mistaken for "no match" | Return `PCRE2_ERROR_CALLOUT`, not `-1` | Make failure distinguishable from success-by-failure |
| **sed** | The all-zero seed would stick the register | Replaced inside the script | Special-case your fixed points |
| **Lisp weird** | The closing note first said "6 methods", counting the `:around` method | Count only methods whose qualifiers are `(or)` | Introspection reports what you ask, not what you meant |
| **AWK weird** | A finite file leaves an empty last record, which would count as a card | `RT == "" { next }` | Guard the edge of a stream |
| **All the script entries** | Real data could leak into a demo | `CHECK(demo_only=1)` makes a non-demo row unrepresentable, and `check.sh` tries to violate it | Enforce invariants in the schema |
| **All the script entries** | Proving the constraint is real | Each `check.sh` greps the source for banned constructs and runs 25 times; Rust has a test scanning for `;` | A test is how a stunt becomes a lesson |
| **tar** | tar goes on after a command fails, so a bad record would be followed by good ones | The dispatcher writes `faulted` to the database and refuses every later member. A passive inspector vets the whole archive first | Fail closed, and do not rely on the host to stop |
| **tar** | Proving that a hostile archive is inert | Canary files, shim programs that fail if they are called, and an archive with `$(touch ...)` as its hours | Test the absence of an effect with something that would show it |
| **JavaScript** | Proving that the loop body is really empty and that nothing hides the program | A small scanner blanks comments and strings, then insists on one `for` with two semicolons and an empty body. Six mutants must be rejected | A test of a constraint needs mutants that break it |

## Patterns in the overcoming

- **The obstacle is usually "the language has no X."** The answer is almost always "find where the language already does X by another name": a stack, a stack of captures, a file that gets remade.
- **The host is allowed to be small, not absent.** Many entries need a little help (seed the random digits, create a directory, print the rows). The honest fine print in each README says exactly how much.
- **Bugs in these entries are instructive.** The off-by-one in APL's rewrite, the lazy `let` in Haskell, the coarse timestamps in Make and the misleading `-1` in PCRE2 are the best material in the repo.

What is *still* stuck: [blocking problems](blocking-problems.md).
