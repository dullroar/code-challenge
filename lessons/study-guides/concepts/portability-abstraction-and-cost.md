# Portability, abstraction, and cost study guide

## What this guide is for

Every abstraction hides something, and sooner or later the hidden thing shows. A language standard promises some behavior, allows more, and says nothing about the rest. This guide asks: **what is promised, what is host-dependent, and what is a performance cliff?** The book tags every lesson with one of three labels, and this guide teaches you to *choose* the label, by the evidence you can produce.

When you finish, you should be able to:

1. Define guaranteed, implementation-permitted and accidentally exploited behavior, and give an example of each from the entries.
2. Say what evidence supports each label: a specification, a tested implementation, an observation.
3. Predict what happens when a program that depends on one implementation runs on another, and say whether the failure will be loud or silent.
4. Recognize a performance cliff (backtracking, re-enumeration, repeated copying) and say what input triggers it.
5. Explain what a reproducibility check can prove, and what it cannot.
6. Apply Hyrum's law to a feature nobody promised and say what you would write down.

Scope limits. The guide is about *claims*: how to word them and test them. It does not teach compiler internals or complexity theory. Its source chapter is [Abstraction leaks and implementation dependence](../../cs/08-abstraction-leaks-and-implementation-dependence.md).

## Before you begin

**Safety model.** Every entry writes fictional **DEMO ONLY** data to a local scratch file or database, and the programs start processes. Read the source first and run it in the sandbox first, for example `sandbox/container/run-image.sh src/awk-weird`. Work on copies ([Running things safely](../../exercises.md#running-things-safely)). Never run a runaway experiment outside a timeout: use `SANDBOX_TIMEOUT=30`, and do not run `awk-weird` under mawk on `/dev/urandom`.

**Prediction rule.** For each claim you make, write the evidence that would show it is *false*. A claim with no such evidence is a hope.

**Vocabulary.**

| Term | Meaning here |
| --- | --- |
| Guaranteed | A specification or documented semantics promises it. |
| Implementation-permitted | One implementation, platform or version allows it. |
| Accidentally exploited | It works, and nobody promised it. |
| Hyrum's law | With enough users, every observable behavior of a system will be depended on by somebody. |
| Performance cliff | An input at which cost jumps from small to enormous. |

## The shared challenge

A *card* is a category and a whole number of hours from 10 to 19; categories cycle through Meetings, Coding, Debugging and Learning; the running total rises until it passes 40; the run **retains the first card that takes the total above 40**; a total of exactly 40 does *not* stop it, and four 10-hour cards need a fifth. Final totals are 41 to 59, with 3 to 5 cards. Rows are saved to SQLite with the ISO week (`2026-W47`) and a `DEMO ONLY` marker.

For a portability reader, the challenge has four *host dependencies* hidden inside it: a random source, a clock and the ISO week, a database, and the platform's tools. Each entry takes them from somewhere different, and each choice is a portability decision. The shared checker `lessons/tools/check-demo.sh` tests the *result* the same way for all.

## The machine to identify

For portability, the five questions become questions about *dependencies*.

**What repeats.** The same dependency, many times: the random source and the clock. Most entries call `date +%G-W%V` or an equivalent, so the ISO week is a repeated host lookup. The Make entry reads `/proc` instead of calling `date`, and the COBOL and JavaScript entries compute it by arithmetic.

**Where state lives.** In the host: environment variables (`XDG_DATA_HOME`, `HOME`), the clock, `/dev/urandom`, the filesystem. A pinned seed (`SEED`, `-Dtc_seed`, `--seed`, `DICE`) moves the randomness into the caller.

**What advances the next step.** In a portable program, the language. In a host-dependent one, a *feature of one implementation*: GNU Make's restart, GNU tar's checkpoint, gawk's `RT`, GnuCOBOL's `ALTER`, PCRE2 callouts.

**What stops it.** The stop rule is usually portable. The failure modes are not: a missing feature may stop the program loudly, or let it succeed with the wrong answer.

**What commits.** Each entry commits through `sqlite3` or a SQLite library. A missing `sqlite3` is a loud failure, which is the good kind.

## Trace one run

Here are the same three cards, 15, 19 and 12, made by *different implementations of the same algorithm*, to show what a name does and does not promise.

| Entry | Generator | Pinned input | Hours |
| --- | --- | --- | --- |
| `javascript`, `javascript-weird`, `javascript-events` | Park-Miller (48271), hours `10 + state % 10` | `SEED=1105` | 15, 19, 12 |
| `tar-gnu-weird` | Park-Miller (48271), same extraction | `--seed 1105` | 15, 19, 12 |
| `m4` | Park-Miller (16807), Schrage's trick, hours `10 + seed / 1024 % 10` | `-Dtc_seed=230` | 15, 19, 12 |
| `ed-weird`, `ex-weird` | none: the launcher supplies five digits | `DICE="5 9 2 0 0"` | 15, 19, 12, 10, 10 |
| `tar-gnu` | the builder writes the hours | `--hours "15 19 12 10 10"` | 15, 19, 12 |
| `regex-sed` | a 16-bit shift register | the README's seed gives 15, 14, 14 | not 15, 19, 12 |

Every row was run in the sandbox or in a scratch folder. Two of them name "Park-Miller" and are *not* the same: the multiplier differs (48271 against 16807) and so does the way a digit is taken from the state. The m4 seed that gives 15, 19, 12 is 230 and the JavaScript seed is 1105. "The same generator" is a claim about a *name*. The only portable promise is the one you test: the same seed gives the same cards *in the same program*.

**Where portability fails silently.** Three facts, from a verified exercise and from the entries' own READMEs:

- Run `awk-weird` under **mawk** on a finite digit file: `# committed total=0 entries=0`, no error, exit 0 (B13). mawk has no `RT`, so every record is skipped.
- Run the ed script under **busybox ed**: it cannot run it, and the entry's check says so. That is the *loud* kind.
- Run `tar-gnu` on **BSD or macOS tar**: there is no `--to-command`, so it fails. Also loud.

**Exactly 40.** The boundary is a portability test of the *specification*. An entry that ignores it (four names) agrees with the other entries 9,999 runs in 10,000. A claim of "the same challenge" holds for most runs and fails at the edge. A test suite that samples random runs will almost never find it.

## Compare the ordinary and weird designs

| Dimension | Idiomatic entries | Weird entries |
| --- | --- | --- |
| **Representation** | Standard language features | A feature of one implementation, or a use nobody promised |
| **Observability** | The standard's diagnostics | The README's own measurements: "tested on GNU tar 1.34 and 1.35" |
| **Tests** | Check the result | Check the result *and* the constraint (banned words, one `ALTER` count, a mutation that must change behavior) |
| **Debugging** | Standard | The question "does this fail loud or silent?" |
| **Portability** | Broad | Narrow, and the README says how narrow |
| **Cost** | Normal | A cliff may be the point |

The repository's own tally of how strong each entry's promise is, taken from the `assurance` key of the READMEs: **17** entries are guaranteed (the ports, the LINQ entries, the JavaScript entries, plain COBOL, Haskell, Forth, Lisp and awk, and `regex-dotnet`), **15** are implementation-permitted (APL, `awk-weird`, `cobol-weird`, `forth-weird`, `haskell-weird`, `lisp-weird`, `m4`, the other regex entries, both tar entries, Tcl and `ex-weird`), and **8** are accidentally exploited (`cmake`, `ed-weird`, `find-gnu`, `find-posix`, `make-gnu`, `regex-sed`, `tcl-weird` and `xaml`). Idiomatic entries tend to be guaranteed, and the weird entries are not.

## What the exercises demonstrate

| Exercise | Predict first | What the evidence shows |
| --- | --- | --- |
| [B13. AWK: the missing RT](../../exercises.md#b13-awk-the-missing-rt-verified) | Run under mawk on a finite file. | Zero cards, exit 0: a silent failure of "portable-looking" code. `RT` is implementation-permitted. |
| [B4. Make: remove the no-op, and override the clock](../../exercises.md#b4-make-remove-the-no-op-and-override-the-clock-verified), step 2 | `make NOW=1700000000`: which ISO week? | `2023-W46`, which agrees with `date -u`. A clock that can be fixed can be tested. |
| [B20. JavaScript](../../exercises.md#b20-javascript-read-the-clauses-move-the-limit-and-fail-the-structure-check-verified), step 4 | `NOW=2026-12-31` and `NOW=2024-12-30`: which week? | `2026-W53` and `2025-W01`. The ISO year can differ from the calendar year near New Year. |
| [B15. GNU find: move the stop rule, read the profile](../../exercises.md#b15-gnu-find-move-the-stop-rule-read-the-profile-verified) | `FIND_D=rates`: what does find print? | A real success rate for each test, and find's own guess is far off. An optimizer's estimate is not the behavior. |
| [B17. tar, weirder: predict the clock](../../exercises.md#b17-tar-weirder-predict-the-clock-verified) | Predict the ticks for `--interval 2`. | `floor(records / K)`. A rule measured on GNU tar, then predicted by a simulation. |
| [F. Prove a README claim](../../exercises.md#f-prove-a-readme-claim-verified) | Can you make the claim fail? | A negative control separates a claim from an observation. |

## Failure modes, costs, and boundaries

| Behavior | Label | Why |
| --- | --- | --- |
| `Word64` wraps on overflow (Haskell's generator) | **Guaranteed** | Documented. |
| COBOL's size error leaves the field unchanged | **Guaranteed** | Specified. |
| COBOL's unhandled overflow drops the leading digit | **Implementation-permitted** | The tested build; the standard promises no usable result. |
| `ALTER` | **Implementation-permitted** | Deleted from the standard in 2002; GnuCOBOL still runs it. |
| m4's `eval` is 32-bit | **Implementation-permitted** | GNU m4 1.4.x. `2147483647*4` gives `-4` silently. |
| GNU tar's checkpoint callbacks and record counting | **Implementation-permitted** | Documented GNU options. The counts were measured on 1.34 and 1.35. |
| Listing a tar archive gives a different tick count from creating it | **Accidentally exploited** knowledge | Tar skips data it need not read. Nobody promises it. |
| The `pcre2grep` callout script feature | **Implementation-permitted** | A build option. Ubuntu's own `pcre2grep` lacks it. |
| Make's restart used as a loop | **Accidentally exploited** | Hyrum's law: a feature used for what it was not for. |
| A sed regex used as a clock | **Accidentally exploited** | A performance cliff, and it varies by CPU. |

**Costs to state.**

- **Performance cliffs.** A regex that is fast on every test can take a year on one bad input. The sed entry uses a catastrophic pattern as a 50 ms clock. CMake's regex has no counted repetition, so "at most 40" written as forty optional groups would backtrack exponentially on failure. LINQ re-enumeration multiplies effects. m4 copies its growing SQL script at each card. See [Regular-expression denial of service](../../cs/08-abstraction-leaks-and-implementation-dependence.md#regular-expression-denial-of-service) and [Performance cliffs and time complexity](../../cs/08-abstraction-leaks-and-implementation-dependence.md#performance-cliffs-and-time-complexity).
- **Reproducibility has limits.** A fixed clock and a fixed seed make a run repeatable. They prove nothing about a different host. Make's `NOW`, the JavaScript `NOW` and `SEED`, and `SOURCE_DATE_EPOCH` for the book's build each fix one input. The book's PDF and EPUB are byte-reproducible for the same pandoc and WeasyPrint versions.
- **Hyrum's law.** If the README does not say which behavior is promised, users will depend on the observed one. The READMEs name what they measured, and the labels are the discipline.
- **Where this is legitimate.** Using an implementation's extension is ordinary engineering if you write down that you did. The risk is not the extension, it is the silence.

## Connections across the repository

- **Language guides.** [COBOL](../languages/cobol.md), [Make and CMake](../languages/make-and-cmake.md), [Regex engines and sed](../languages/regex-engines-and-sed.md), [m4](../languages/m4.md), [tar](../languages/tar.md) and [ed and Ex](../languages/ed-and-ex.md) give the evidence behind each label.
- **Reading safely.** [Reading adversarial programs](reading-adversarial-programs.md): a missing feature that fails silently is also a security question.
- **Effects.** [Effects, errors, and commitment](effects-errors-and-commitment.md) asks which failure semantics are promised.
- **The comparison.** [Comparative machine design](comparative-machine-design.md) lists every entry with its label.
- **In the book.** [Leaky abstractions](../../cs/08-abstraction-leaks-and-implementation-dependence.md#leaky-abstractions), [Undefined, unspecified and implementation-defined behavior](../../cs/08-abstraction-leaks-and-implementation-dependence.md#undefined-unspecified-and-implementation-defined-behavior), [Portability](../../cs/08-abstraction-leaks-and-implementation-dependence.md#portability), [Hyrum's law](../../cs/08-abstraction-leaks-and-implementation-dependence.md#hyrums-law) and [Reproducibility and deterministic builds](../../cs/08-abstraction-leaks-and-implementation-dependence.md#reproducibility-and-deterministic-builds).

## Self-check

Answer before you read the italic text after each question.

1. **Trace.** `m4 -Dtc_seed=230` and `SEED=1105 node ...` both give hours 15, 19, 12. Does it follow that the two programs share a generator? *(No. Both use a Park-Miller recurrence, but with different multipliers and different digit extraction. The seeds were found separately. Equal output on one seed is a coincidence of the search.)*
2. **Explain.** Why is a loud portability failure better than a silent one, and which does mawk give for `awk-weird`? *(A loud failure stops you before you trust a wrong result. mawk gives a silent one: zero cards, exit 0.)*
3. **Transfer.** You depend on `date +%G-W%V` in a script. Which label do you give that dependency, and what would you write down? *(Implementation-permitted: GNU `date` and compatible. Write down the tool, the minimum version and what the ISO year does near New Year.)*
4. **Evidence.** A README says "GNU tar counts 21 ticks when creating a 21-block archive." Design a test that could fail and say how you would label it. *(Create archives of several sizes, blocking factors and intervals, and compare tar's tick count with `floor(ceil(blocks / b) / K)`. The negative control is listing the archive, which gives a different count. The claim is implementation-permitted, and the listing behavior is accidentally exploited knowledge.)*

## Further reading

- [Software portability](https://en.wikipedia.org/wiki/Software_portability) (Wikipedia): what makes software move between platforms.
- [Undefined behavior](https://en.wikipedia.org/wiki/Undefined_behavior) (Wikipedia): the strongest case of "nobody promised".
- [Hyrum's law](https://en.wikipedia.org/wiki/Hyrum%27s_law) (Wikipedia): why observable behavior becomes a contract.
- [Reproducible builds](https://en.wikipedia.org/wiki/Reproducible_builds) (Wikipedia): what a fixed input can prove.
- [Regular expression denial of service](https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS) (OWASP): how a cliff becomes an attack.
