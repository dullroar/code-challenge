# Formal languages and weird machines study guide

## What this guide is for

A notation is built for one job. A regular expression matches text, a Makefile orders a build, XAML describes a window, `ed` edits a buffer, tar packs files. The recurring surprise of the repository is that each of these also turns out to be a computer. This guide asks: **when does a notation become an executable substrate, and how much machine does each one need?**

When you finish, you should be able to:

1. Place a notation on the Chomsky hierarchy and say what extra power turns a matcher into a computer: a stack, a counter, code blocks, callouts, a rewrite loop or a restart.
2. Explain why one regex match always finishes while a loop of substitutions may not, and why that matters for what the entries can claim.
3. Describe the *substrate* of each entry: what its alphabet is, what its rules are, and what plays memory.
4. Explain "weird machine" and "language-theoretic security" with an example from the entries, and say what a defender should do.
5. Say what each machine cannot do, with evidence: the old four-name ceiling, the missing counted repetition, the failed .NET `Match` that exposes nothing.
6. Label claims as guaranteed, implementation-permitted, or accidentally exploited.

Scope limits. The guide is about the *relationship between a notation and the machine it can express*. It is not a course in automata theory: it names the levels and uses them. Its source chapter is [Formal languages as computational substrates](../../cs/05-formal-languages-as-computational-substrates.md).

## Before you begin

**Safety model.** Every entry writes fictional **DEMO ONLY** data to a local scratch file or database, and the programs run code from inside notations (Perl in a pattern, C in a callout, Tcl from a table, Tcl-like text from XAML). Read the source first and run it in the sandbox first, for example `sandbox/container/run-image.sh src/regex-sed`. Work on copies, and run any sed or regex experiment in a scratch folder ([Running things safely](../../exercises.md#running-things-safely)).

**Prediction rule.** Before each run, write what the notation can *represent* and what it cannot, then see whether the program ran into that limit.

**Vocabulary.**

| Term | Meaning here |
| --- | --- |
| Formal language | A set of strings defined by strict rules that a machine can process. |
| Chomsky hierarchy | A ladder of language classes by the machine they need: regular, context-free, context-sensitive, recursively enumerable. |
| Substrate | The notation plus its engine, used as a machine. |
| Weird machine | The computation that an input processor performs *beyond* what its authors intended. |
| Language-theoretic security | The idea that an input language more powerful than its authors realized makes reading the input the same as running a program. |

## The shared challenge

A *card* is a category and a whole number of hours from 10 to 19; categories cycle through Meetings, Coding, Debugging and Learning; the running total rises until it passes 40; the run **retains the first card that takes the total above 40**; a total of exactly 40 does *not* stop it, and four 10-hour cards need a fifth. Final totals are 41 to 59, with 3 to 5 cards.

For a formal-language reader the challenge needs two capabilities: *counting* (compare a total with 40) and *repetition with memory* (carry the total from one card to the next). A pure regular expression has neither. Every entry in this guide supplies them by borrowing a mechanism: a stack, tally marks, a restart, a host. The boundary is exact: a total of 40 must *continue*, so the machine must tell 40 from 41.

## The machine to identify

For each entry, ask what plays each role.

**What repeats.** In a *searching* substrate (Perl, PCRE2, pcre2grep, .NET), a quantifier over a pattern; the engine explores paths. In a *rewriting* substrate (sed, m4, ed), a loop that applies rules until none matches. In a *restarting* substrate (Make), the engine reruns itself. In a *parsing* substrate (XAML), a walk over the document.

**Where state lives.** In a captured stack (.NET: `b` is the budget, `s` is the total), in the text itself (sed: `#` marks; ed: `x` marks), in captures rebuilt every pass (CMake), in the host (a C struct for PCRE2, SQLite for pcre2grep), or in files (Make).

**What advances the next step.** The engine's own control: backtracking, the rewrite loop, the restart, the parser.

**What stops it.** A pattern that fails (`(?!)`), a pattern that stops matching (`/ tot:#{41}/`), a rule that writes nothing (Make), a literal of a given length (CMake), a finite supply (four names, five dice).

**What commits.** In a substrate that cannot write, nothing commits inside it: the .NET entry must return a match and let the *host* write the file. In a substrate with hooks (PCRE2 callouts, Perl code blocks), the effects commit as the match proceeds, and survive its failure.

## Trace one run

Here is how three cards, 15, 19 and 12, look in four substrates. Each was verified by running a scratch copy.

| Substrate | Representation of the total after card 2 | Stop test on card 3 | What the engine does at the end |
| --- | --- | --- | --- |
| .NET regex | 7 tokens left on the budget stack `b`, 34 on the total stack `s` | `(?(b)...\|(?!))`: `b` is empty after card 3, so `(?!)` fails the pass | the match *succeeds*; the host reads the captures |
| PCRE2 callouts | `total=34` in a C struct | the `gate` callout returns 1 for `total=46` | `(*COMMIT)`, then `(*FAIL)`: the match returns "no match" after all the work |
| sed | `tot:` followed by 34 `#` marks in one line | `/ tot:#{41}/` matches (43 marks in the seed-based run) | `b done`; sed exits 1 on purpose |
| CMake | `M1`: 15 `x`, `M5`: 19 `x` | `NOT` (46 `x` matches the 41-`x` literal) | the loop ends, but the main match still ran |

Read the second row: a PCRE2 pattern that "fails" is the program's *success*, because the effects survived. In the first row the opposite holds: the pattern must succeed, because a failed .NET match exposes nothing.

**What the notation cannot do.** The .NET entry cannot draw random numbers or write a file, so the host seeds four unary strings and writes the result. The sed entry has no numbers at all, so a random generator is a 16-character string of `0` and `1`. The CMake regex has no counted repetition, no lookahead and no backreferences, so the stop test is a literal of 41 `x`s, and a pattern parameterized by a register is the only way to look something up.

**Exactly 40.** A substrate can express "continue at 40" only if it can tell 40 from 41. A budget of 41 tokens, a literal of 41 marks and a tape line for 40 all do. But the *supply* is finite in several: the category names in a subject, a `cats:` list, the unrolled XAML passes. With four names, a run of four 10-hour cards ended at exactly 40, which the shared checker rejects. The notation was powerful enough to *count* to 41 and not powerful enough to *supply* a fifth name. The regex entries now carry five names and prove it in their checks; `xaml`, with four unrolled passes, still has the limit.

## Compare the ordinary and weird designs

| Dimension | Notation used as intended | Notation used as a machine |
| --- | --- | --- |
| **Representation** | A pattern, a build graph, a UI tree | The same text, plus the engine's side effects |
| **Observability** | Match, build, render | The state is in captures, marks or files: `TRACE=1` in sed prints the whole machine |
| **Tests** | Test against inputs | A second implementation predicts it (tar's awk simulation), or a mutation proves the rule is real (the 41-`x` literal changed to 51) |
| **Debugging** | The tool's own diagnostics | A silent no-op: a failed `s`, a failed match, a recipe that expands to nothing |
| **Portability** | A standard notation | An engine's extension: PCRE2 callouts, Perl `(?{ })`, GNU sed's `T` and `-E` intervals, gawk's `RT` |
| **Cost** | Normal | Backtracking can be catastrophic; the sed entry uses that as a clock |

**One match against a loop of substitutions.** A single regex match, with a fixed input and no code hooks, always finishes: the engine tries a bounded number of paths. The entries that use *backtracking search* are exploring, and abandon branches. A sed program that rewrites a string over and over is a different model: it is a rewriting system, and a loop of substitutions can run forever. That is why the sed entry's stop rule must be real, and why the ed and Ex scripts keep a bound (five dice, a 60-line tape).

## What the exercises demonstrate

| Exercise | Predict first | What the evidence shows |
| --- | --- | --- |
| [B8. Regex: what survives a failed match](../../exercises.md#b8-regex-what-survives-a-failed-match-verified) | Append `(?!)` to the .NET pattern. | `match returned: false`, `total=0 entries=0`: the notation's only output is its captures. |
| [B9. sed: watch a computation](../../exercises.md#b9-sed-watch-a-computation-verified) | How many state lines per card? | Many, not constant: a rejected draw repeats a step. A rewriting machine shows its whole state. |
| [B5. CMake: mutate the literal](../../exercises.md#b5-cmake-mutate-the-literal-verified) | Shorten the 41-`x` literal to 31. | The stop rule moves: the literal is the rule. |
| [B11. m4: quote the recursion](../../exercises.md#b11-m4-quote-the-recursion-verified) | Remove the brackets. | A runaway: the macro processor expands arguments before it calls the macro. |
| [B18. ed: move the stop rule and break the cleanup](../../exercises.md#b18-ed-move-the-stop-rule-and-break-the-cleanup-verified) | Change `x\{41,\}` to `x\{31,\}`. | The run stops after the first total over 30. One repeat count in a regex is the rule. |
| [C2. Make the constraint real](../../exercises.md#c2-make-the-constraint-real-verified) | Write a check that bans loop words in Forth. | It must strip comments and strings first: a constraint check is itself a parser. |

## Failure modes, costs, and boundaries

| Behavior | Label | Why |
| --- | --- | --- |
| .NET balancing groups pop one capture stack and push another | **Guaranteed** | Documented .NET regex behavior. A stack takes the engine beyond regular languages. |
| A failed .NET `Match` exposes no captures | **Guaranteed** | Verified in B8. |
| PCRE2 callouts call host code, and a positive return fails the path | **Guaranteed** | Documented API. |
| Callouts are only visited if the optimizer does not skip them | **Implementation-permitted** | The entry sets flags and avoids the JIT; it did not test what the optimizer would elide without them. |
| Perl code blocks run during a match, and `local` is undone on backtracking | **Guaranteed** | Documented Perl. |
| A failed `MATCHES` clears CMake's registers | **Implementation-permitted** | Observed, not promised in so many words. |
| CMake evaluates both operands of `AND` | **Accidentally exploited** | Observed, and needed to log the last card. |
| gawk's `RS` as a regular expression, with `RT` | **Implementation-permitted** | gawk only. mawk silently gives zero cards (B13). |
| A sed backtracking regex takes about 50 ms per frame | **Accidentally exploited** | A performance cliff used as a clock. It varies by machine. |
| The `XamlReader` runs `ObjectDataProvider` methods when parsing | **Accidentally exploited** | A UI language used as an interpreter. |

**Costs to state.**

- **Language-theoretic security.** If an input language is more powerful than its authors realized, reading the input is running a program. XAML's parser is the case in this repository. The defense is the *rule of least power*: accept the weakest language that does the job, and parse it before acting on it ([Language-theoretic security](../../cs/05-formal-languages-as-computational-substrates.md#language-theoretic-security)).
- **A weird machine is made of unintended states.** The entries do it deliberately, in a sandbox, to teach. The defender's task is to find the weird machine before an attacker does ([Weird machines](../../cs/05-formal-languages-as-computational-substrates.md#weird-machines)).
- **Hidden limits.** A finite tape or list is a design limit that behaves like a semantic one at the boundary.
- **Where this is legitimate.** Using a regex to *tokenize*, a build tool to *generate* sources, a macro processor to *configure* are all ordinary. The stunt is demanding a whole program from the notation.

## Connections across the repository

- **The language guides.** [Regex engines and sed](../languages/regex-engines-and-sed.md), [Make and CMake](../languages/make-and-cmake.md), [m4](../languages/m4.md), [ed and Ex](../languages/ed-and-ex.md), [tar](../languages/tar.md) and [C#, LINQ, XAML, and ports](../languages/csharp-linq-xaml-and-ports.md) each trace one substrate.
- **State and control.** [State and control beyond variables](state-and-control-beyond-variables.md) says where each substrate keeps its program counter.
- **Reading safely.** [Reading adversarial programs](reading-adversarial-programs.md) takes "an input language is a program" as its main example.
- **Cost.** [Portability, abstraction, and cost](portability-abstraction-and-cost.md) covers the backtracking cliff and the implementation extensions.
- **In the book.** [The Chomsky hierarchy](../../cs/05-formal-languages-as-computational-substrates.md#the-chomsky-hierarchy), [Regular expressions](../../cs/05-formal-languages-as-computational-substrates.md#regular-expressions), [Term and string rewriting](../../cs/05-formal-languages-as-computational-substrates.md#term-and-string-rewriting), [Macros and text expansion](../../cs/05-formal-languages-as-computational-substrates.md#macros-and-text-expansion) and [Build automation](../../cs/05-formal-languages-as-computational-substrates.md#build-automation).

## Self-check

Answer before you read the italic text after each question.

1. **Trace.** In the .NET entry the draws are 15, 19, 12, 17. Give the budget tokens left after each pass and say which pass ends the loop. *(26, then 7, then 0. After the third pass `b` is empty, so the next pass takes `(?!)` and the loop ends. The fourth draw is ignored.)*
2. **Explain.** Why does the PCRE2 pattern end in `(*COMMIT)` and `(*FAIL)`, and what does each do? *(`(*COMMIT)` stops the engine from retrying shorter loops, so the `commit` callout runs once. `(*FAIL)` makes the whole match lose after the work is done, which is the signature move.)*
3. **Transfer.** Name an input language in a system you use that is more powerful than it looks, and say how you would apply the rule of least power. *(For example a template language, a spreadsheet formula or a config format with `include`. Replace it with a weaker declared format, or parse it with a strict grammar before acting.)*
4. **Evidence.** A reviewer says "the .NET entry cannot write anything." Design a test that could fail. *(Check that `Program.cs` has exactly one `Regex.Match`, no `MatchEvaluator` or `Replace`, and that every file write is in host code after the match, which the entry's `check.sh` does. The negative control is a copy with a `MatchEvaluator`, which the check must reject.)*

## Further reading

- [Chomsky hierarchy](https://en.wikipedia.org/wiki/Chomsky_hierarchy) (Wikipedia): the ladder of language classes.
- [Pushdown automaton](https://en.wikipedia.org/wiki/Pushdown_automaton) (Wikipedia): the machine a stack adds to a regular language.
- [Weird machine](https://en.wikipedia.org/wiki/Weird_machine) (Wikipedia): unintended computation in input handling.
- [Rule of least power](https://en.wikipedia.org/wiki/Rule_of_least_power) (Wikipedia): why a weaker input language is safer.
- [Markov algorithm](https://en.wikipedia.org/wiki/Markov_algorithm) (Wikipedia): the formal model behind sed's find-and-replace machine.
