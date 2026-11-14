# Problems overcome

What stood in each approach's way, and how it got around it. Each row came from a wall someone actually hit; most are written up in the entry's "Walls and fine print" or "Gotchas" section.

| Approach | The obstacle | How it was overcome | What it teaches |
| --- | --- | --- | --- |
| **C#** (`ModernChallenge1`) | A `for` initializer allows only one declaration, but the loop needs seven kinds of state | One anonymous object with a field per piece of state | Anonymous types are an expression-level record |
| **C#** | `void` methods (`Add`, `Show`, `Close`) do not fit where a value is needed | `new Func<T>(() => { effect(); return value; }).Invoke()` in place | Statements can be lifted into expressions |
| **LINQ** | A statement must end in an invocation, so `x is var r && ...` cannot bind intermediate results | Nest `Enumerable.Repeat(x, 1)` calls to turn a value back into a one-element sequence | Know which expression shapes are legal as statements |
| **LINQ** | Effects must run in order inside lazy stages | Tuple left-to-right evaluation sequences `SaveChanges`; a final eager `Aggregate` forces the tail | Eager vs. lazy operators |
| **XAML** | Markup has no variables | "Carrier" arrays filled in place by successive `ObjectDataProvider` calls | Mutable buffers as variables |
| **XAML** | Markup has no loop or `if` | Four unrolled passes; SQL or `DataTable` expressions do the branching | Borrow an expression engine |
| **APL** | A loop with a data-dependent stop | Draw five (a bound that can never be too small), then take a computed prefix | Compute the answer, then trim it |
| **APL weird** | A function cannot copy itself... | `⎕CR` reads its source, `⎕FX` defines the rewritten copy | Code is a character matrix |
| **APL weird** | Dynamic scope clobbers the parent's variables | Each generated header redeclares locals (`Locals`) | Scope rules shape metaprogramming |
| **COBOL** | The loop condition must not be a comparison | `88`-level condition name on the total | Rules can be data |
| **COBOL weird** | No `IF`, `PERFORM`, `EVALUATE` or modulo | `ALTER` rewires one `GO TO`; a 2-digit overflow is the stop | Mutable control flow, overflow as decision |
| **Forth** | Stack values must be shared between printing and SQL | `dup .row` keeps a copy; `outfile-execute` points output at the pipe | Output redirection as a language feature |
| **Forth weird** | No variables, no loop words | State on the stack; `>in` rewound as a program counter; the flag (-1/0) as a mask | The interpreter's own state is reachable |
| **Haskell** | A stop rule without a loop | `span` over lazy infinite lists | Laziness as control |
| **Haskell weird** | Effects must fire per cell, in order, on an infinite list | `fixIO` knot plus `unsafeInterleaveIO` around each cell | Evaluation order as program meaning |
| **Haskell weird** | A lazy `let` forced the cards after the pipe closed | `evaluate (length cards)` before commit | Laziness bites twice |
| **GNU Make** | No arithmetic, no loop, no `$(shell)` | Numbers as lists of `x`; re-execution via `include` of generated makefiles | Restart is a loop |
| **GNU Make** | A recipe expanding to nothing does not count as remaking a file | A trailing `@:` (shell no-op) | Expansion time vs. execution time |
| **GNU Make** | WSL's coarse timestamps made a rewritten state file look unchanged | One new file per pass: "missing to present" is unambiguous | Don't trust mtime for state |
| **GNU Make** | `$(info)` output came out before SQLite's header | The report is a chain of phony targets | Make expands a recipe before it runs it |
| **GNU Make / CMake** | `wt.exe` treats `;` as its own subcommand separator | Command lines contain no `;` | Know the host's separator rules |
| **CMake** | No `{n}` quantifier, lookahead or backreference | Literal 41-`x` test; subject and pattern rebuilt from the last pass's captures | Work within the weakest regex |
| **CMake** | A failed `MATCHES` clears every register | Put the stop test first so the main match's captures survive | Order of side-effecting conditions |
| **Perl regex** | Statements cannot live in a pattern | `(?{ })` code blocks and `(??{ })`; package variables with `local` | Backtrack-aware state |
| **PCRE2** | The optimizer might skip callouts; the JIT does not support them | `PCRE2_NO_AUTO_POSSESS`, `_NO_START_OPTIMIZE`, `_NO_DOTSTAR_ANCHOR`; no JIT | Know what the optimizer may elide |
| **PCRE2** | A callout error could be mistaken for "no match" | Return `PCRE2_ERROR_CALLOUT`, not `-1` | Make failure distinguishable from success-by-failure |
| **pcre2grep** | No variables in the pattern, and callouts do not search `PATH` | State lives in SQLite; absolute program paths | Externalize state |
| **.NET regex** | A regex has no counter | Balancing groups: a stack of captures | A stack is a counter |
| **sed** | No arithmetic and no variables | Tally marks, a text-encoded shift register, substitution rules | A Markov algorithm computes |
| **sed** | The all-zero seed would stick the register | Replaced inside the script | Special-case your fixed points |
| **sed** | A timer without a clock | A catastrophic-backtracking regex calibrated to about 50 ms per frame | Performance cliffs are a resource |
| **Rust** | No `;`, `let` or `return` in `main` | `successors(...)`; `match x { name => ... }` as `let`; tuple projection as the comma operator | Iterators and closures as control flow |
| **Go** | A three-clause `for` cannot hold statements | Helper functions (`Seq`, `After`) in a separate file | Cost of the constraint made explicit |
| **Python** | No `;` loops and no statement expressions | `iter(<lambda>, False)` plus tuple-and-`[-1]` | Expressions standing in for statements |
| **Kotlin** | No `for(;;)` | `generateSequence`, ending on null | A sequence is a loop |
| **All the script entries** | Real data could leak into a demo | `CHECK(demo_only=1)` makes a non-demo row unrepresentable, and `check.sh` tries to violate it | Enforce invariants in the schema |
| **All the script entries** | Proving the constraint is real | Each `check.sh` greps the source for banned constructs and runs 25 times; Rust has a test scanning for `;` | A test is how a stunt becomes a lesson |

## Patterns in the overcoming

- **The obstacle is usually "the language has no X."** The answer is almost always "find where the language already does X by another name": a stack, a stack of captures, a file that gets remade.
- **The host is allowed to be small, not absent.** Many entries need a little help (seed the random digits, create a directory, print the rows). The honest fine print in each README says exactly how much.
- **Bugs in these entries are instructive.** The off-by-one in APL's rewrite, the lazy `let` in Haskell, the coarse timestamps in Make and the misleading `-1` in PCRE2 are the best material in the repo.

What is *still* stuck: [blocking problems](blocking-problems.md).
