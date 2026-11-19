# Study guides

*Traces, predictions and evidence for advanced readers of* Learn Programming the Weird Way!

**WEIRD** stands for **Weird Execution, Indirect Results and Data**. The W is recursive. The rest gives you something to trace: what executes, where the result turns up and what the program gets away with treating as data.

Many language chapters pair an idiomatic program with a weird one. These guides take the next step. For each language family and for each big idea, a guide asks you to **identify the machine, trace one fixed run, predict before you execute and prove the claim with evidence**. They are written for a senior undergraduate or a graduate reader. They do not teach what a loop is. They teach why *this* loop-like mechanism has particular consequences.

The guides are hand-written. They began with a COBOL study guide by the book's co-author Ken Astl, and keep its method.

## How every guide works

Every guide has the same eleven sections, so you can find the same thing in the same place:

1. **What this guide is for**: three to six learning outcomes, and what is out of scope.
2. **Before you begin**: the safety model (fictional **DEMO ONLY** data, source review and a sandbox run first), the prediction rule and the vocabulary.
3. **The shared challenge**: the [time-card specification](../intro.md#what-the-challenge-does) and how the entries in this guide behave. A conforming run keeps the **first card that takes the total over 40**, so exactly 40 continues. Check stop, storage and output separately.
4. **The machine to identify**: what repeats, where state lives, what advances the next step, what stops it and which effects commit.
5. **Trace one run**: a fixed run, normally hours 15, 19, 12, with the decisive state before and after each step.
6. **Compare the ordinary and weird designs**: by representation, observability, tests, debugging, portability and cost, not by line count.
7. **What the exercises demonstrate**: links to the verified exercises, each with the prediction you make first.
8. **Failure modes, costs and boundaries**: specific behavior claims labeled **guaranteed**, **implementation-permitted** or **accidentally exploited**, with evidence for each (see [Three kinds of knowledge](../intro.md#three-kinds-of-knowledge)).
9. **Connections across the repository**: other guides and book chapters.
10. **Self-check**: a trace question, an explanation question, a transfer question and an evidence question.
11. **Further reading**: short and annotated.

**How the traces were checked.** A trace is only useful if it is true. For most guides a scratch copy of the real entry was run in the sandbox with the random draws pinned (for example `SEED=1105`, `DICE="5 9 2 0 0"`, `-Dtc_seed=230`, `--hours "15 19 12 10 10"`), and a few lines of logging were added to show the state. A guide says so when a trace was only read from the source, as for the Windows-only WPF entries.

## Language-family guides

| Guide | Entries | What it asks |
| --- | --- | --- |
| [C#, LINQ, XAML and ports](languages/csharp-linq-xaml-and-ports.md) | `ModernChallenge1`, `LinqChallenge1`, `LinqChallenge2`, `xaml` and the Go, Java, Kotlin, Python and Rust ports | What does each slot of the `for` header do, when does a query run and who owns the thread? |
| [COBOL](languages/cobol.md) | `cobol`, `cobol-weird` | Where does a program keep "what happens next" and "when to stop"? |
| [Haskell](languages/haskell.md) | `haskell`, `haskell-weird` | Who demands work, and what happens when a forcing point moves? |
| [Forth](languages/forth.md) | `forth`, `forth-weird` | What can serve as a program counter, and what can serve as memory? |
| [Make and CMake](languages/make-and-cmake.md) | `make-gnu`, `cmake` | When the tool decides what runs next, where does the program's state live? |
| [Regex engines and sed](languages/regex-engines-and-sed.md) | `regex-perl`, `regex-pcre2`, `regex-pcre2grep`, `regex-dotnet`, `regex-sed` | Which engines preserve effects after failure, and which need a successful match? |
| [APL](languages/apl.md) | `apl`, `apl-weird` | What replaces the loop when the program works on whole arrays, or on its own source? |
| [JavaScript](languages/javascript.md) | `javascript`, `javascript-weird`, `javascript-events` | Who owns the next step: the loop header, the consumer or the event loop? |
| [Common Lisp](languages/common-lisp.md) | `lisp`, `lisp-weird` | Can the object system's dispatch rules serve as the loop and the stop rule? |
| [m4](languages/m4.md) | `m4` | What do quoting, expansion order and rescanning each decide? |
| [Tcl](languages/tcl.md) | `tcl`, `tcl-weird` | If code is just a string, who may write it, and which engine runs next? |
| [ed and Ex](languages/ed-and-ex.md) | `ed-weird`, `ex-weird` | When the program is a buffer being edited, what are the addresses, registers and program counter? |
| [tar](languages/tar.md) | `tar-gnu`, `tar-gnu-weird` | An archive is data. What gives it an effect, and what makes it safe to read? |

## Concept guides

| Guide | Book chapters | Core question |
| --- | --- | --- |
| [Reading adversarial programs](concepts/reading-adversarial-programs.md) | [1](../cs/01-reading-an-adversarial-program.md) | What can this program cause before I run it? |
| [State and control beyond variables](concepts/state-and-control-beyond-variables.md) | [2](../cs/02-what-counts-as-a-machine.md), [3](../cs/03-control-flow-and-continuations.md), [6](../cs/06-state-beyond-variables.md) | Where are the next step and the remembered state stored? |
| [Evaluation, demand and laziness](concepts/evaluation-demand-and-laziness.md) | [4](../cs/04-evaluation-and-demand.md) | Who demands work, and when? |
| [Formal languages and weird machines](concepts/formal-languages-and-weird-machines.md) | [5](../cs/05-formal-languages-as-computational-substrates.md) | When does a notation become an executable substrate? |
| [Effects, errors and commitment](concepts/effects-errors-and-commitment.md) | [7](../cs/07-effects-errors-and-commitment.md) | Which effects survive failure, and what truly commits? |
| [Portability, abstraction and cost](concepts/portability-abstraction-and-cost.md) | [8](../cs/08-abstraction-leaks-and-implementation-dependence.md) | What is promised, host-dependent or a performance cliff? |
| [Events, callbacks and reactive control](concepts/events-callbacks-and-reactive-control.md) | [10](../cs/10-events-callbacks-and-reactive-control-flow.md) | Who owns the next turn, and what does reentrancy change? |
| [Comparative machine design](concepts/comparative-machine-design.md) | [9](../cs/09-comparative-case-studies.md), [patterns](../patterns.md) | What plays loop, state, clock, decision and commit? |

`find` and AWK have no guide of their own. They appear in the guides on [reading adversarial programs](concepts/reading-adversarial-programs.md), [state and control](concepts/state-and-control-beyond-variables.md) and [comparative machine design](concepts/comparative-machine-design.md).

## Suggested paths

- **From a language you know.** Open its guide, trace the fixed run, make your predictions, then run the linked exercise. Return to the book page of the same name.
- **From an idea.** Start with a concept guide. Its trace tables compare several languages at once, and each row links to the guide that checked it.
- **In order.** Read [Reading adversarial programs](concepts/reading-adversarial-programs.md) first. It is the safety model for everything else.

Back to the [lessons](../README.md) and the [challenge](../../README.md).
