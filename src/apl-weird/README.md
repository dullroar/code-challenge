# APL, weirder

**Teaches you:** that `⎕CR`, `⎕FX` and compress make "if" and "loop" optional, and that a function can be its own successor.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

This is weird, even for APL folk.

The host defines exactly one function, `Card0`. Every other card is a function that the card before it **wrote**: it reads its own source, rewrites four lines of it, defines the copy with `⎕FX`, and calls it. The stop rule is a compress (`/`) over the child's source text. When the total passes 40 the child's source is empty, `⎕FX` defines nothing, and there is nothing left to call. The state of the program is not in variables; it is in the program text.

## Run it

GNU APL (`apl`, from [gnu.org/software/apl](https://www.gnu.org/software/apl/)) and `sqlite3`.

```bash
cd src/apl-weird
apl --script -f timecards.apl
./check.sh                  # set APL=/path/to/apl if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/AplWeird/demo-timecards.db` (default `~/.local/share/AplWeird/`). A run looks like this:

```text
# DEMO ONLY run 2026-11-14-9-42-57-197
Meetings	18	18	2026-W46	DEMO ONLY
Coding	12	30	2026-W46	DEMO ONLY
Debugging	15	45	2026-W46	DEMO ONLY
# Card0 ⇐ H←10+?10
# Card1 ⇐ H←12
# Card2 ⇐ H←15
# committed total=45 entries=3 DEMO ONLY
# the host wrote Card0 and nothing else; each later card was written by the one before it
```

The three `# CardN ⇐` lines are read back from the workspace *after* the run (`⎕NL 3` lists its functions). `Card1` and `Card2` exist only because `Card0` and `Card1` wrote them, and their hours are literals in their own source.

## How it works

A function in GNU APL is a block of text between two `∇` marks. Its first line is the header. Here is `Card0`, with the lines numbered the way `⎕CR` (which returns a function's source as a character matrix) numbers them:

| Line | Source | Role |
| --- | --- | --- |
| 0 | `Card0;N;C;H;T;D;Alive;Kid;Genes` | Header: the name, then local variables |
| 1-4 | `N←0`, `C←0`, `H←10+?10`, `T←H` | The **genes**: card number, category, hours, running total |
| 5-… | the body | Prints the row, saves it, and **writes and calls the next card** |

1. **Print and save.** The body uses the genes to print one row and `INSERT` one row into SQLite.
2. **Draw the next card.** `D←10+?10` is the next card's hours. `Genes←('N←',⍕N+1) ('C←',⍕4|C+1) ('H←',⍕D) ('T←',⍕T+D)` builds four replacement gene lines *as text*: `⍕` formats a number as characters, so `N` of 1 becomes the line `N←2`.
3. **The stop rule.** `Alive←40≥T` is 1 while the total is 40 or less, else 0.
4. **Write the child.** `Kid←⎕FX Alive/(⊂'Card',(⍕N+1),Locals),Genes,5↓⊂[1]⎕CR 'Card',⍕N`. Read it from the right:
   - `⎕CR 'Card',⍕N` is *this function's own source* as a matrix;
   - `⊂[1]` cuts that matrix into a list of its rows, and `5↓` throws away the header and four gene lines, leaving the body;
   - the new header and the four new gene lines are put in front;
   - `Alive/` is the stop rule. A scalar 1 keeps every line and a scalar 0 keeps none: **the whole child is compressed away**;
   - `⎕FX` "fixes" (defines) a function from that list of lines, or does nothing for an empty list.
5. **Call the child.** `⍎Alive/'Card',⍕N+1`. `⍎` (execute) runs text as APL; `Alive/` over the name leaves either the name or the empty string; executing the empty string is a no-op. So the same boolean controls both the writing and the calling.

The recursion is therefore a chain of different functions rather than a function calling itself: `Card0` calls `Card1`, which was *written by* `Card0`, which calls `Card2`, and so on. At most five cards are ever needed (five cards of ten hours reach 50).

### What this version refuses to use

`check.sh` enforces the rules by reading the source: no `⍣` (power operator), no `→` (branch), exactly one `∇ … ∇` block, exactly one `⎕FX`, and the generated-card count in the output must equal the number of entries. It also runs the program under `timeout`, because a broken stop rule does not fail, it recurses forever (see below).

## Gotchas worth knowing

- **Dynamic scope.** APL local variables are visible to everything *called* from the function, not just to its own text. Every card must declare `N;C;H;T;…` in its header (that is what `Locals` is for) or a child's genes would overwrite its parent's.
- **Off-by-one in a rewrite.** The first draft of this program dropped four lines instead of five when copying the body, so every child kept its parent's `T←H` gene line and reset the running total to one card. The total could never pass 40, the stop rule never fired, and the program recursed until killed. Self-modifying code fails silently and structurally; that is why the check script has a timeout.
- **`⊃` vs `↑`.** In GNU APL `⊃` is *disclose* and `↑` is *first* (Dyalog swaps them). The report picks the last card with `↑⌽`.
- **`Card0` is slightly different.** It is the only card whose hours come from `H←10+?10` in its own text; later cards have a literal. That is the honest price of having something to start from.
- **No `⎕IO` independence here.** The weird version sets `⎕IO←0` and relies on it.
- **Not a pattern.** Rewriting your own source to avoid a `while` is a stunt, not a technique.
