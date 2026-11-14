# APL

**Teaches you:** that five rolls and a take-while can replace a loop.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

The whole challenge ("add 10-19 hour cards until the total passes 40") is three array expressions. There is no loop and no `if`. The rest of [`timecards.apl`](timecards.apl) is plumbing: seeding, a pipe to `sqlite3`, and printing.

## Run it

GNU APL (`apl`, built from [gnu.org/software/apl](https://www.gnu.org/software/apl/)) and `sqlite3`.

```bash
cd src/apl
apl --script -f timecards.apl
./check.sh                  # set APL=/path/to/apl if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/Apl/demo-timecards.db` (default `~/.local/share/Apl/`). A run looks like this:

```text
# DEMO ONLY run 2026-11-14-9-38-27-440
Meetings	19	19	2026-W46	DEMO ONLY
Coding	17	36	2026-W46	DEMO ONLY
Debugging	16	52	2026-W46	DEMO ONLY
# committed total=52 entries=3 DEMO ONLY
```

## How it works

Read the three lines under "The challenge" in the source with this walk-through beside them.

1. **Draw everything up front.** `Drawn←(10-⎕IO)+?5⍴10`. `5⍴10` is five tens, `?` rolls each one (`?10` gives a number from the first ten integers), and the `10-⎕IO` shift turns those into 10..19. Why five? Every card is at least 10 hours, so five cards always total at least 50. Five is a *bound that can never be too small*, not a loop count.
2. **Apply the stop rule as data.** `Hours←Drawn↑⍨1++/40≥+\Drawn`. Read it right to left:
   - `+\Drawn` is the running total after each card, for example `15 26 41 51 …`;
   - `40≥` turns that into 1s and 0s: `1 1 0 0 …`. Totals only ever grow, so the 1s are always a prefix;
   - `+/` counts the 1s, which is how many cards fit under the line;
   - `1+` adds the one card that crosses it, and `↑⍨` ("take, arguments swapped") keeps that many.
3. **Derive the rest.** `Totals←+\Hours` is the running total again. `Kinds←(≢Hours)⍴Categories` uses a quiet property of reshape: `⍴` *recycles* its right argument when it is shorter than the target, so four category names reshaped to seven slots come out `Meetings Coding Debugging Learning Meetings Coding Debugging`. No modulo needed.

After that, `SaveRow¨⍳≢Hours` and `ShowRow¨⍳≢Hours` apply a small function (a *dfn*, `{ … }`) to each row number (`¨` is "each"). That is APL's `for`, and it is not the stop rule: it just visits the rows that are already decided.

### The plumbing, in the order it appears

| Piece | What it does |
| --- | --- |
| `⎕RL←+/⎕TS×1 12 …` | Seeds the random generator from the clock. GNU APL starts every session with `⎕RL` at 16807, so without this every run would draw the same "random" cards |
| `⎕FIO[24]` / `⎕FIO[8]` / `⎕FIO[25]` | `popen`, read a line, `pclose`. Used to ask `date +%G-W%V` for the ISO week |
| `'w' ⎕FIO[24] '…sqlite3…'` | `popen` for writing: APL sends SQL down a pipe to a real `sqlite3` |
| `⎕FIO[23]` / `⎕FIO[22]` | `fwrite` and `fprintf`. The left argument of `⎕FIO[22]` is a format string followed by its values; the right is the file handle (`1` is stdout) |
| `CHECK(demo_only=1)` | Makes a non-demo row unrepresentable in the table. `check.sh` tries to insert one and expects SQLite to refuse |
| `)OFF` | A *system command*, not APL code. It ends the script. Without it `--script` would sit at the prompt |

## Gotchas worth knowing

- **Origin.** `⎕IO` is the index origin (1 by default in GNU APL, 0 in some code). The file never assumes it: `?` is the only primitive whose results depend on it, and the draw subtracts `⎕IO` back out. `check.sh` runs with the default; try putting `⎕IO←0` on the first line and see that the cards are still 10-19.
- **`⊃` is not "first".** In APL2-family interpreters (GNU APL, APL2) `⊃` *discloses* (it is "mix") and `↑` is "first". Dyalog reverses that: `⊃` is first/pick. `⊃Kinds[⍵]` here is a disclose of one selected string back to a plain character vector.
- **`_←` is a throwaway.** Primitives such as `⎕FIO` return a value; a bare expression would print it. Assigning to `_` swallows it.
- **No formatter exists.** There is no `gofmt` for GNU APL source. The layout rules applied by hand are: one statement per line (`⋄` is for the REPL), CamelCase names for things you define, and comments aligned in a column.
- **SQL by string formatting is a bad habit.** It is safe here only because every value is a number computed by the program or one of four fixed words. Do not copy it.
