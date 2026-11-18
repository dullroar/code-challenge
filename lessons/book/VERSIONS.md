# Book versions

*Learn Programming the Weird Way!* is numbered from **v3** on, so you can see which edition added what. Earlier editions were not numbered. Each release adds a section here, newest first. The edition number lives in [`metadata.yaml`](metadata.yaml) (`book-version`) and on the title page; `build.py` checks that they agree with this file.

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
