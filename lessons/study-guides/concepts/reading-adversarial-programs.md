# Reading adversarial programs study guide

## What this guide is for

This guide teaches a reading habit. The book's programs are *adversarial on purpose*: a regex runs Perl code, a markup file calls methods while it is parsed, a tar archive carries a program, a table row holds Tcl source, `find` digs the directory it is walking. The core question is: **what can this program cause before I run it?** The habit is to answer that from the source and from the runner, and to know which of the two you are reading.

When you finish, you should be able to:

1. Write down, for any unfamiliar program, the *authority* it will run with: files, processes, network and environment.
2. Separate four acts that are often blurred: writing data down, reading it back, interpreting it and executing it. Say which act each entry performs.
3. Find the *interpreter* of a data format in a program: the component that turns bytes into effects.
4. Name the trust boundary in `xaml`, `tar-gnu`, `tcl-weird`, `regex-perl` and `find-gnu`, and say what would break it.
5. Explain why reading the program next to its ordinary sibling shows the cost of the stunt.
6. Label each claim you make about a program as guaranteed, implementation-permitted, or accidentally exploited, and say what evidence supports it.

Scope limits. This guide is about *reading and running safely*. It is not a security course: it does not teach exploit development, threat modeling in depth, or sandbox internals. Its source chapter is [How to read an adversarial program](../../cs/01-reading-an-adversarial-program.md). For each entry's details, follow the links to the language guides.

## Before you begin

**Safety model.** Every entry writes fictional **DEMO ONLY** data to a local scratch file or database, and nothing connects to a real time-reporting system. That is a promise about the *data*. It is not a promise about the *code*, which starts processes, runs shells and parses its own input. So every entry is treated as untrusted until someone has read and understood it, and it is run in the sandbox first. From the repository root, with [`SANDBOX-SETUP.md`](../../../SANDBOX-SETUP.md) done:

```bash
sandbox/container/run-image.sh src/tar-gnu
```

The supported runners are `sandbox/container/run-image.sh <folder>`, `sandbox/run.sh <folder>` and `lessons/tools/run-in-sandbox.sh [-e NAME=VALUE] <folder> <command...>`, and on Windows `sandbox\windows\run.ps1`. See [Running things safely](../../exercises.md#running-things-safely).

Work on a copy for any experiment. Output is random, so compare properties, not numbers.

**Prediction rule.** Before running anything, write: what files will it touch, what processes will it start, and what in its *input* can make it do something it would not do otherwise. Then run it and compare.

**Vocabulary.**

| Term | Meaning here |
| --- | --- |
| Authority | What a program is *allowed* to do: the files, processes and network it can reach as the user who ran it. |
| Interpreter | The component that turns data into effects. A parser can be one without anyone calling it that. |
| Trust boundary | The line between data you control and data an attacker can influence. |
| Passive inspection | Reading and checking a format without running any of it. |

## The shared challenge

Every entry builds the same fictional data. A *card* is a category and a whole number of hours from 10 to 19. Categories cycle through Meetings, Coding, Debugging and Learning. The running total rises until it passes 40, and the run **retains the first card that takes the total above 40**. A total of exactly 40 does *not* stop it. Final totals are 41 to 59, with 3 to 5 cards, saved in one local SQLite transaction.

That shared, harmless outcome is what makes the hostile mechanisms safe to *study*: you always know what a correct run looks like (the shared checker `lessons/tools/check-demo.sh` tests it), so a run that does anything else is evidence. The entries' own checks add a second kind of evidence: they refuse unexpected files, processes and unknown records.

## The machine to identify

Here the machine is not one program but a *reader*, and you identify it with the five questions asked about *what a program can cause*.

**What repeats.** Ask what the program repeats and *who starts each repetition*. In `regex-perl`, a quantifier repeats a pattern whose pieces are Perl code. In `tar-gnu`, tar repeats a dispatcher over archive members. In `xaml`, nothing repeats: the parser reaches each `ObjectDataProvider` once. In `find-gnu`, `find` repeats because `-exec` creates a directory that `find` then visits.

**Where state lives.** Ask where the program keeps *its inputs and its memory*, because that is where an attacker writes. In `tcl-weird`, procedure bodies are rows in a table. In `xaml`, the document. In `tar-gnu`, the archive. In `find-gnu`, the path. In every case, whoever can change that store can change the program.

**What advances the next step.** Ask who decides the next step. In `tar-gnu` it is the operator's command line (`--to-command`), not the archive. In `tcl-weird` it is the lookup of an unknown command name. In `xaml` it is the parser. A format that can name its own next step is more dangerous than one that cannot.

**What stops it.** Ask what limits the damage. `tar-gnu`'s dispatcher refuses unknown record types and runs exactly one SQL statement per member. `tcl-weird` is safe only because its table is private to one connection. The sandbox adds an outer limit: no network, a read-only root and an unprivileged user.

**What commits.** Ask which effects are real and which are not. All entries write to a scratch database inside a transaction. The `DEMO ONLY` rule is enforced by a `CHECK(demo_only=1)` constraint, so a non-demo row cannot be stored even by a program that tries. That is data-level authority: the *database* refuses.

## Trace one run

A reading trace is not a program trace. Here is the same three-card run (hours 15, 19, 12) read as *what each entry could have done*, using only facts the language guides verified:

| Entry | Who ran the data | What the data could have named | What the entry did instead |
| --- | --- | --- | --- |
| `tar-gnu` | Operator's `--execute`, then tar | Any member name | `inspect.sh` vetted all 12 members and ran nothing. The dispatcher accepts five names and refuses the rest. |
| `xaml` | The XAML parser | Any constructor and method on the type list | Calls `Random.Next` and EF Core `Add` (read from the source, not run here). |
| `tcl-weird` | `unknown`, from a table | Any Tcl text | Ran `born`, `category`, `hours`, `init`, `runid`, `week`: the six procedures the program itself stored. |
| `regex-perl` | Perl, during a match | Any Perl | Starts `sqlite3` without a shell, with a fixed argument list. |
| `find-gnu` | `find`, via `-exec` and `-fprintf` | Any command | `mkdir`, `mktemp` and `-fprintf` to fd 3. |
| `awk-weird` | `gawk`, reading a byte stream | Whatever `RS` matches | Cuts `/dev/urandom` at digits, so the data is random bytes. |

The tar column of the verified run: the inspector decoded 12 members (`# 12 member(s); 0 the interpreter would refuse`), and the run printed `Meetings 15 15`, `Coding 19 34`, `Debugging 12 46`. The step that *read* the program was separate from the step that *ran* it, and the second needed an extra flag.

**A trace of a mistake.** While this guide was prepared, a test harness ran the `regex-sed` script directly, from a checkout, without the wrapper that connects file descriptor 3. The script writes its SQL with `w /dev/fd/3`. With fd 3 closed, sed's own script file had taken that descriptor, so `w` opened the script file and overwrote it with SQL. The program's author had read the source and tested it through its wrapper. The failure came from running it a way the author did not intend. The script was restored from Git, and the sed README now carries a warning to run it only through its wrapper or with an explicit `3>` target. That is the whole subject in one incident: authority comes from how you run the program.

**Exactly 40.** For reading, the boundary is another test of understanding. If a program claims "a total of exactly 40 continues", the *evidence* is a run in which it does. The regex and `for`-header entries cannot make one: they stop at four cards (see the [comparative guide](comparative-machine-design.md)). A claim you cannot demonstrate is a claim you have only read.

## Compare the ordinary and weird designs

Read the weird program next to its ordinary sibling. The difference shows exactly what the stunt costs, and *where the authority moved*.

| Pair | Ordinary design | Weird design | Where the authority moved |
| --- | --- | --- | --- |
| `cobol` / `cobol-weird` | A named condition on data | A rewritten jump | Control flow moved into data the program edits. |
| `haskell` / `haskell-weird` | A pure function, then I/O | Effects inside a lazy list | The order of effects moved to the consumer. |
| `tcl` / `tcl-weird` | A loop in a procedure | Source in table rows, fetched by `unknown` | *Code* moved into a table. |
| `tar-gnu` / `tar-gnu-weird` | Members as instructions | Layout as a clock | The program moved into an archive; then into its size. |
| `find-posix` / `find-gnu` | Counting with names | GNU extras do the arithmetic | The state moved into the directory path. |

| Dimension | What to ask |
| --- | --- |
| **Representation** | Is the program text, a file, a table, a document or a layout? |
| **Observability** | Can you read it *without running it*? `tar-gnu` has an inspector, `xaml` does not. |
| **Tests** | Does the entry's `check.sh` enforce its own constraint (banned words, one `ALTER` count, one `Regex.Match`)? A constraint with no check is a hope. |
| **Debugging** | Does a mistake fail loudly (a compile error) or silently (a no-op, an empty run)? |
| **Portability** | Does it depend on one implementation's feature (GNU `RT`, GNU tar's `--to-command`)? |
| **Cost** | What does the stunt cost in reviewability? |

## What the exercises demonstrate

| Exercise | Predict first | What the evidence shows |
| --- | --- | --- |
| [B16. tar: read the program, then run it](../../exercises.md#b16-tar-read-the-program-then-run-it-verified) | Add a member that is not in the instruction set. What are the exit statuses, and does a `pwned` file appear? | The inspector refuses (`REFUSE (unknown record type)`, exit 4), the interpreter runs nothing, and no file appears. Reading and running were different acts, and the trust boundary was the operator's decision. |
| [B13. AWK: the missing RT](../../exercises.md#b13-awk-the-missing-rt-verified) | Run the unmodified program under `mawk` on a finite file. | `# committed total=0 entries=0`, no error, exit 0. mawk has no `RT`, so every record is skipped. "Portable-looking" code can fail *silently* on the wrong implementation. |
| [B14. find: rig the dice](../../exercises.md#b14-find-rig-the-dice-verified) | Put a fake `mktemp` first on `PATH`. What changes? | The dice are rigged: with name `xxxxxS`, every card has 19 hours. A program that finds its tools through `PATH` takes whatever is first on it. |
| [F2. Trojan Source](../../exercises.md#f2-trojan-source-hide-a-character-then-find-it-verified) | A zero-width space after `admin`: what does `node` print? | `false`. The string has a character you cannot see. The scan finds it and the bytes show it. |
| [F. Prove a README claim](../../exercises.md#f-prove-a-readme-claim-verified) | What test would fail if the claim were false? | A claim is evidence only with a negative control. |

## Failure modes, costs, and boundaries

| Claim about a program | Label | Why |
| --- | --- | --- |
| Reading an archive with `tar -xf` does not run its contents | **Guaranteed** | An archive is data. Only the command attached gives it an effect. |
| `tar-gnu`'s dispatcher passes no part of a member to a shell | **Guaranteed** by design, tested | The entry's check enforces it. |
| `XamlReader.Load` runs `ObjectDataProvider` methods during parsing | **Accidentally exploited** | A documented UI language, used as an interpreter. The XAML README classifies it so. |
| GNU `awk`'s `RT` holds the text that matched `RS` | **Implementation-permitted** | gawk only. mawk has none, and B13 shows what happens. |
| `unknown` runs whatever text is in the table | **Guaranteed** | Documented Tcl. Safe here only because the table is private. |
| A script that writes to `/dev/fd/3` writes to whatever is on fd 3 | **Guaranteed** | Operating-system behavior. The entry assumes its wrapper opened a pipe there. |

**Costs to state.**

- **A threat model that is not updated describes a system that no longer exists.** "It is just markup" and "it is just a regex" are both false here. See [Threat model](../../cs/01-reading-an-adversarial-program.md#threat-model).
- **Code review does not scale to the unreadable.** `regex-perl`'s program is one very long line. The sandbox exists because "read every line first" is not enough ([Sandbox](../../cs/01-reading-an-adversarial-program.md#sandbox)).
- **Invisible characters defeat reading.** [Trojan Source](../../cs/01-reading-an-adversarial-program.md#trojan-source-characters-you-cannot-see) is why the repository scans for them.
- **A hostile reader is also a risk.** A tool that parses a file format is an interpreter for that format. Treat it as one.
- **Where this habit is legitimate everywhere.** It is the ordinary review habit applied to deserializers, templates, plugin loaders and `eval`.

## Connections across the repository

- **Parsing as running.** [C#, LINQ, XAML, and ports](../languages/csharp-linq-xaml-and-ports.md) shows the XAML case.
- **Authority from the command.** [tar](../languages/tar.md) is the repository's cleanest example.
- **Code in a table.** [Tcl](../languages/tcl.md) and [APL](../languages/apl.md) both store code as text.
- **Code in a pattern.** [Regex engines and sed](../languages/regex-engines-and-sed.md) runs Perl and C inside a match, and includes the `/dev/fd/3` hazard.
- **State and control, and the comparison.** [State and control beyond variables](state-and-control-beyond-variables.md), [Effects, errors, and commitment](effects-errors-and-commitment.md) and [Comparative machine design](comparative-machine-design.md).
- **In the book.** [How to read an adversarial program](../../cs/01-reading-an-adversarial-program.md), including [Arbitrary code execution](../../cs/01-reading-an-adversarial-program.md#arbitrary-code-execution), [Principle of least privilege](../../cs/01-reading-an-adversarial-program.md#principle-of-least-privilege) and [Capability and authority](../../cs/01-reading-an-adversarial-program.md#capability-and-authority).

## Self-check

Answer before you read the italic text after each question.

1. **Trace.** For an archive whose members are `000.begin`, `010.card`, `011.stop-over`, `025.exec`, `990.show`, which acts happen under `inspect.sh`, and which under `interpret.sh --execute`? *(The inspector reads and decodes all five and refuses `025.exec` with exit 4. The interpreter runs the inspector first, sees the refusal, and runs nothing. No member is executed.)*
2. **Explain.** Why is `tcl-weird` safe to run when `unknown` runs table text as code? *(The table is a `TEMP` table, built in memory by the program from literals, so nobody else can write to it. The boundary is the privacy of that table, not any check on the text.)*
3. **Transfer.** You are asked to review a service that renders user-supplied templates. Which entries does it resemble, and what are your first three questions? *(It resembles `xaml` and `regex-perl`: a trusted engine reading attacker-influenced text. Ask: what can the template language call, who can write a template, and what authority does the renderer run with?)*
4. **Evidence.** A colleague says "`tar-gnu` never runs anything from an archive that is not one of five record types." Design a test that could fail, and say what the negative control is. *(Build archives with an unknown member and a malformed body, run `interpret.sh --execute`, and check exit 4 and an untouched database. The control is a valid archive, which must run. The claim is guaranteed by design and tested.)*

## Further reading

- [Arbitrary code execution](https://en.wikipedia.org/wiki/Arbitrary_code_execution) (Wikipedia): the general problem this reading habit defends against.
- [Code injection](https://owasp.org/www-community/attacks/Code_Injection) (OWASP): how text becomes code, with defenses.
- [Threat model](https://en.wikipedia.org/wiki/Threat_model) (Wikipedia): what to write down before you decide what to trust.
- [RFC 3552, section 3: the Internet threat model](https://www.rfc-editor.org/rfc/rfc3552) (IETF): a short, practical example from the standards world.
