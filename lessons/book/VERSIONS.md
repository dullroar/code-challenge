# Book versions

*Learn Programming the Weird Way!* is numbered from **v3** on, so you can see which edition added what. Earlier editions were not numbered. Each release adds a section here, newest first. The edition number lives in [`metadata.yaml`](metadata.yaml) (`book-version`) and on the title page; `build.py` checks that they agree with this file.

## v4

A picture of how every program runs, one new entry and one new chapter, on events.

- **A `## Program Flow` section in every entry's README.** One Mermaid diagram and a few sentences answer "what is the runtime really doing?". The diagram type is chosen to fit the machine: flowcharts for loops and branches, sequence diagrams for callbacks and dispatch, state diagrams for a changing jump target, and dataflow and demand graphs for lazy evaluation. They are not all flowcharts on purpose. The build copies each section to the lesson page of the entry's language, under **How each program runs**, renders it, and checks that it fits a printed page at a legible size.
- **What the challenge does.** One shared picture in the intro says *what* every entry does. The Program Flow pictures say *how*.
- **Fourteen teaching figures for the concepts and the patterns.** Ten sit in the chapters "By computer science concept" (what a machine is, computation versus orchestration, continuations, eager, lazy and deferred evaluation, referential transparency, closures, four kinds of round-trip "sameness", the commit boundary, idempotence and backpressure) and four in "By solution patterns" (fold against demand, where control state lives, what backtracking rewinds and programs stored as data). They compare an idea *across* languages. The Program Flow figures still show each program.
- **Twenty-three more concept figures.** Each of these concept sections now has one diagram of the *idea*, drawn in the family that fits it: stack machines, register and counter machines, Markov algorithms, recursion, fixed-point iteration, coroutines, lazy evaluation, short-circuit evaluation, iterators and generators, array programming, dataflow programming, macros and text expansion, build automation, the call stack, the stack as a data structure, scope and binding, dependency graphs, database triggers, side effects, exception handling, exit status, backtracking and the cut. Sequence diagrams show hand-offs (coroutines, generators, exceptions), snapshots show state (stacks), and trees show search (backtracking against the cut). All pass the same 70% print gate.
- **New entry:** [`javascript-events`](../../src/javascript-events/README.md): ten listeners on one `EventEmitter` are the whole program, and `setImmediate` gives the event loop a turn between cards.
- **New chapter 10, "Events, callbacks and reactive control flow".** Who chooses what runs next, a synchronous `emit()` against the event loop, a trace you can read, state machines, backpressure, and a table that separates real events from look-alikes such as a window's own loop. It adds the concepts callbacks, publish and subscribe, the event loop and scheduling turns, and backpressure, and moves event-driven programming here from chapter 3.
- **New exercise:** B22 (predict the event trace, then remove the scheduling boundary), checked by `lessons/tools/verify-exercises.sh`.
- **A faster PDF.** The figures no longer put thousands of transparency groups into the PDF, which made Edge and Chrome show white pages for a long time. The Mermaid look is now flat (`classic`), and each SVG is post-processed (`flatten-text.mjs`). The PDF has about 400 objects instead of 7,500 and is half the size. The figures look the same.
- **Build:** `python lessons/book/build.py` renders the diagrams with a pinned Mermaid CLI (see [`README.md`](README.md)); `--check-diagrams` is the full render gate.

## v3

Six new entries, a new way to ground the computer-science concepts, and a dozen new concepts.

- **New entries:**
  - [`tar-gnu`](../../src/tar-gnu/README.md): a tar archive as a serialized program, with a passive inspector and a fail-closed interpreter.
  - [`tar-gnu-weird`](../../src/tar-gnu-weird/README.md): tar's checkpoints as the clock of a state machine.
  - [`ed-weird`](../../src/ed-weird/README.md): a line editor's buffer as the machine; a failed substitution as an `if`.
  - [`ex-weird`](../../src/ex-weird/README.md): a register that runs itself; marks as registers.
  - [`javascript`](../../src/javascript/README.md): the original's bodiless `for`, in Node.js.
  - [`javascript-weird`](../../src/javascript-weird/README.md): closures and a lazy iterator, with no loop statement.
- **New computer-science concepts:** serialization, deserialization and object pickling; closures and lexical environments; first-class and higher-order functions; functors and mapping; monoids and folds; category theory; dataflow programming; operational semantics; interpreters and virtual machines; event-driven programming; logical clocks and event ordering; computation versus orchestration; capability and authority; reproducibility and deterministic builds.
- **Every concept is now grounded.** An entry can relate to a concept as a demonstration (`tags`), an `analogy` or a `counterexample`, and the "In this repo" tables say which. Some facts are stated once for all entries (`sandbox`, `code-review`, `model-of-computation`). Trojan Source has an exercise instead of an entry. `build.py --orphans` reports it, and `build.py --check` fails if a concept has nothing behind it.
- **A new chapter 9 section** compares where each program lives and what makes its next step run, and a second one separates serialization, deserialization, interpretation and execution, with the round-trip promise each entry makes.
- **New exercises:** B16 to B21 (one for each new entry; B16 and B17 are the two tar entries) and F2 (Trojan Source). All are checked by `lessons/tools/verify-exercises.sh`.
- **Sandbox:** the images gain `ed`, nvi and Node 24 (pinned by SHA-256).
- **The book is numbered.** This page, the title page and `metadata.yaml` must agree, and the build checks it.
