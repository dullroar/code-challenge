# ed and Ex

Entry: [`src/ed-weird`](../../src/ed-weird/README.md). `ed` is the original Unix line editor, from 1969 to 1971. You tell it which lines (an *address*) and what to do to them (a *command*). It has no screen. Everything it does to a file, it does to a **buffer** of lines in memory, one command at a time. The commands are so general that the program in this book is made of nothing else.

## What makes ed special

| Feature | What it teaches |
| --- | --- |
| Addresses: `3`, `.`, `$`, `.-1`, `/re/` | A line is reached by number, by position or by pattern. An address is a reference into the data, as a pointer or an index is. |
| `s/re/text/` | Substitution is a conditional rewrite. If the pattern matches, the text changes. If not, nothing happens. |
| `g/re/command-list` | The global command marks every line that matches, then runs the commands for each one, in order. It is the only loop ed has. |
| `t`, `m`, `j`, `d` | Copy, move, join and delete whole lines: ed's way to build and tear down data. |
| No arithmetic and no variables | Numbers must be written as text. In the entry they are rows of marks. |

## The buffer is the machine

### 1. Behold the monstrosity

```bash
sandbox/container/run-image.sh src/ed-weird
```

Seventy lines of ed commands. A launcher that supplies five random digits and stores the answer. All the computing is the editor changing text.

### 2. How the hell does that work?

- **The category order is addressing.** `1s/^/Meetings /` puts a name on line 1, `2s/^/Coding /` on line 2.
- **A rewrite table does the lookup.** There are ten rules, `g/x7$/s/7$/xxxxxxx/` and nine more. A digit becomes that many marks.
- **Adding is writing marks side by side.** `-t.` copies the line above (the total so far), `-,.j` joins it to the card, and one `s` puts the two sets of marks together.
- **A failed `s` is an `if`.** Inside a global command it does nothing, and does not stop the list. So each substitution means "if the line looks like this, rewrite it".
- **The stop rule is a regular expression.** `x\{41,\}` is "41 or more marks". The bar before the marks becomes a bang, and the next card sees the bang and turns into a `Dead` line.

The [README](../../src/ed-weird/README.md#how-the-stunt-works) has the full table.

**A rewrite system with a different control.** [`regex-sed`](regex.md#gnu-sed) also rewrites text, but sed has a branch command and can loop until no rule applies. ed cannot. Its only repeat is `g`, and its only choice is a substitution that may not match.

### 3. What did we just learn?

- **Numbers can be text.** Unary marks make addition a matter of concatenation. The price is the length of the string.
- **A guard is a conditional.** "Rewrite only if it matches" is `if` in a language that has none.
- **Data can carry control.** A bar or a bang in a line says whether the machine is still running. The state travels with the data.
- **Standards and implementations differ.** busybox ed is an `ed`, and it cannot run this program: no `g`, no `t`, no `j`, no `#`, and no empty match.
- **A wall is a result.** Nested `g` is refused. A blank line is a command. We kept a test for each.

Tags: the commands `s`, `g`, `t`, `j`, `d` and `0a` are in POSIX. That a failed `s` inside `g` is silent is **accidentally exploited** knowledge: GNU ed 1.20.1 does it, and its manual does not say so. `#` comments are a GNU extension.

### 4. Do this in production and you're fired

- **Unary does not scale.** One million is a million characters.
- **The program depends on positions.** One extra line between a card and its ledger breaks every total.
- **Nobody can debug ten rewrite rules by eye.** The entry has a test that compares it with a short model.

Legitimate uses: `ed` and `ex` in scripts for exact, scriptable edits (`ed -s file < commands`), such as a build step that must change one line of a config file.

### 5. Now break it yourself

See [exercise B18](../exercises.md#b18-ed-move-the-stop-rule-and-break-the-cleanup-verified).

## Computer science behind this page

<!-- BEGIN GENERATED concepts:languages/editors.md -->
The computer-science ideas behind this page: [Specification versus implementation](../cs/01-reading-an-adversarial-program.md#specification-versus-implementation), [Transition systems and state machines](../cs/02-what-counts-as-a-machine.md#transition-systems-and-state-machines), [Representing state](../cs/02-what-counts-as-a-machine.md#representing-state), [Markov algorithms](../cs/02-what-counts-as-a-machine.md#markov-algorithms), [Regular expressions](../cs/05-formal-languages-as-computational-substrates.md#regular-expressions), [Term and string rewriting](../cs/05-formal-languages-as-computational-substrates.md#term-and-string-rewriting), [Weird machines](../cs/05-formal-languages-as-computational-substrates.md#weird-machines), [State](../cs/06-state-beyond-variables.md#state), [Portability](../cs/08-abstraction-leaks-and-implementation-dependence.md#portability), [Hyrum's law](../cs/08-abstraction-leaks-and-implementation-dependence.md#hyrums-law).
<!-- END GENERATED concepts:languages/editors.md -->
