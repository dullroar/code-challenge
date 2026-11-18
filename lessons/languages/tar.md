# tar

Entry: [`src/tar-gnu`](../../src/tar-gnu/README.md). `tar` ("tape archive") packs many files into one stream of bytes. It was made for magnetic tape, where you cannot jump around, so an archive is a *sequence*: a header, the file's bytes, the next header, and so on. That one fact is why a tar archive can be a program. Order is already part of the format.

## What makes tar special

| Feature | What it teaches |
| --- | --- |
| An archive is a sequence of 512-byte blocks: a header block, then the data blocks, then the next header | There is no index and no directory. To find a member you read from the start. That is a stream, and a stream is a natural tape for an interpreter. |
| `tar -xf` writes the members as files | Extraction is passive. An archive cannot make tar run anything. |
| GNU `--to-command=CMD` starts `CMD` for each regular member and pipes the member to it | The *operator* attaches an interpreter. The command line carries the power, and the archive does not. |
| `TAR_FILENAME`, `TAR_SIZE` and more are set for each command | The member's metadata becomes the command's input, next to its bytes. |
| tar keeps going when the command fails | There is no built-in "stop". A control rule must be the interpreter's own. |

## A program that is an archive

### 1. Behold the monstrosity

```bash
sandbox/container/run-image.sh src/tar-gnu
```

A tar archive of twelve tiny files. A dispatcher of about 80 lines. No loop in the dispatcher, no random numbers, no number 40.

### 2. How the hell does that work?

- **The members are the instructions.** `010.card` is "add a card". Its body is `category=Meetings` and `hours=13`. The name carries the order, and the body carries the operands.
- **tar is the loop.** It reads the next member and starts the dispatcher, until the archive ends.
- **The dice are rolled when the program is written.** A builder draws the five hours from a seeded generator and stores the seed in the first member. The same seed gives the same bytes.
- **The stop rule is data.** Each card is followed by a `011.stop-over` member that holds `limit=40`. The dispatcher only knows what `stop-over` *means*: halt if the total is over the limit.
- **Reading is not running.** `inspect.sh` lists and decodes every member with `tar -t` and `tar -xO`. `interpret.sh --execute` is the only place where `--to-command` appears.

The [README](../../src/tar-gnu/README.md#its-just-a-tar-file-serialization-deserialization-and-execution) has the full table of who does what.

### 3. What did we just learn?

- **Serialization, deserialization and execution are three acts.** You can write a program down, parse it, and run it. Most formats let you do the first two without the third. Python's `pickle` does not.
- **The trust boundary is the command line.** A plain extraction runs nothing. Adding `--to-command` is a decision, and it is the operator's decision.
- **Fail closed.** The dispatcher refuses an unknown record, and then it refuses every record after it, because tar will not stop on its own.
- **Four kinds of "the same".** Same bytes, same structure, same behavior and same live process are four different claims. This entry makes the first three and says plainly that it does not make the fourth.
- **A format is a contract.** `tarprog/1` is not part of tar. Two programs agree on it.

Tags: `--to-command` and `--occurrence` are **GNU extensions** (**implementation-permitted**). The `ustar` format and the order of members are in POSIX. That tar keeps going after a failed command is what GNU tar 1.35 does today, and the manual does not promise it: it is **accidentally exploited**, and the entry does not depend on it, because it writes its own halt.

### 4. Do this in production and you're fired

- **An archive that runs is a program that arrived as data.** If the operator runs `--to-command` on an archive from a stranger, the stranger's records decide what happens. Here the dispatcher is strict. A careless one is a remote command runner.
- **Your own format has no tooling.** Nothing but a test keeps the builder and the dispatcher in step.
- **tar was not built for this.** Real tar jobs are backup, packaging and transport.

Legitimate uses: `--to-command` as a filter, such as checksumming each member while you extract. A tar archive as a *container* for a program's data, with a manifest.

### 5. Now break it yourself

See [exercise B16](../exercises.md#b16-tar-read-the-program-then-run-it-verified).

## Computer science behind this page

<!-- BEGIN GENERATED concepts:languages/tar.md -->
The computer-science ideas behind this page: [Threat model](../cs/01-reading-an-adversarial-program.md#threat-model), [Arbitrary code execution](../cs/01-reading-an-adversarial-program.md#arbitrary-code-execution), [Principle of least privilege](../cs/01-reading-an-adversarial-program.md#principle-of-least-privilege), [Transition systems and state machines](../cs/02-what-counts-as-a-machine.md#transition-systems-and-state-machines), [Representing state](../cs/02-what-counts-as-a-machine.md#representing-state), [Observability](../cs/02-what-counts-as-a-machine.md#observability), [Parsing](../cs/05-formal-languages-as-computational-substrates.md#parsing), [Domain-specific languages](../cs/05-formal-languages-as-computational-substrates.md#domain-specific-languages), [Language-theoretic security](../cs/05-formal-languages-as-computational-substrates.md#language-theoretic-security), [Serialization, deserialization and object pickling](../cs/06-state-beyond-variables.md#serialization-deserialization-and-object-pickling), [Exit status](../cs/07-effects-errors-and-commitment.md#exit-status), [Integrity constraints](../cs/07-effects-errors-and-commitment.md#integrity-constraints), [Idempotence](../cs/07-effects-errors-and-commitment.md#idempotence).
<!-- END GENERATED concepts:languages/tar.md -->
