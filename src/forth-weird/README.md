# Forth, weirder

**Teaches you:** that the text interpreter's parse position is a program counter, if you let it be, and that the data stack can be a program's only memory.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

This is weird, even for Forth folk.

The program is a two-register machine:

- the **memory** is the data stack: there is not one `variable` in the file;
- the **program counter** is `>in`, the text interpreter's parse position within the current line.

There is no `begin`, `until`, `while`, `if`, `do`, `case` or recursion anywhere. The "loop" is a line of source that the interpreter reads, and then reads *again* because a word moved `>in` backwards.

## Run it

Gforth (`gforth`, 0.7.3 or later) and `sqlite3`.

```bash
cd src/forth-weird
gforth timecards.fs
./check.sh                  # set GFORTH=/path/to/gforth if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/ForthWeird/demo-timecards.db` (default `~/.local/share/ForthWeird/`). A run looks like this:

```text
# DEMO ONLY run 1794674811797273
Meetings	19	19	2026-W46	DEMO ONLY
Coding	11	30	2026-W46	DEMO ONLY
Debugging	19	49	2026-W46	DEMO ONLY
# committed total=49 entries=3 DEMO ONLY
# no loop word anywhere: the text interpreter was rewound until the total passed 40
```

## How it works

The Forth text interpreter is a loop you never see: it reads the next word from the input line, runs it, and repeats. `>in` is a variable holding *how far it has read*. Read it with `>in @`, set it with `>in !`. Set it to an earlier value and the interpreter will cheerfully read the same words again.

The whole program is this one line at the top level, not inside any definition:

```forth
0 0 >in @ step rewind?
```

Read it left to right as the interpreter does:

1. `0 0` pushes the starting state: card number 0, running total 0.
2. `>in @` pushes the parse position, which at this moment is *just after the `@`*. That is the **anchor**: "the place to jump back to". The stack is now `( n total anchor )`.
3. `step` runs one card. It moves the anchor onto the return stack (`>r`), calls `card`, and puts the anchor back, so `card` never sees it.
4. `rewind?` decides whether to jump. `over 41 <` tests whether the total is still 40 or less and leaves a flag, and the next line is the jump itself:

   ```forth
   over >in @ - and  >in @ + >in !
   ```

   A Forth flag is **-1** (all bits set) for true and **0** for false, so it works as a bit mask. `anchor - >in` is the distance back to the anchor; `and` with the flag keeps that distance if the flag was true and zeroes it if false; adding it to `>in` gives either the anchor or "stay where you are". There is no `if`. The jump is arithmetic.
5. The line ends. If `>in` was rewound, the interpreter's next word is `step` again and the stack is exactly as the last pass left it. If not, it carries on to the line after: `drop` (discard the anchor), commit, report.

### Where the state goes

| What | Where it lives |
| --- | --- |
| Card number and running total | On the data stack, across rewinds: `( n total )` |
| The jump target | Also the data stack, as `anchor` |
| A card's hours | On the stack for the length of one `card`, then folded into the total |
| `run-id`, `sqlite` | `value`s set once at start-up and never changed |
| The ISO week text | A buffer filled once at start-up. `%G-W%V` is always eight characters, so no length is stored either |

`card` has the stack effect `( n total -- n' total' )`: it draws hours, computes the new total with `tuck +`, prints the row, sends the `INSERT`, and leaves `n+1` and the new total. `3dup` copies the three-number record `( n h t )` so both `.row` (to the terminal) and `.insert` (to SQLite, through `outfile-execute`) can consume one.

## What `check.sh` enforces

With comments and `."` strings removed, none of `begin until while repeat again if then else do loop case of recurse exit leave` appears; no `variable` or `buffer:` is declared; `>in @` appears at least twice (once for the anchor, once in the jump); and the database rows agree with the printed rows over 25 runs.

## Gotchas worth knowing

- **It only works at the top level, or in `evaluate`d / `included` text.** `>in` is the parse position *of the current input line*. A colon definition that moves `>in` (like `rewind?`) works because it runs while the interpreter is parsing the line that called it. Compile the loop *into* a word and there is no line to rewind.
- **The loop and the data are on one line.** If you move the `0 0` before the `>in @` onto the previous line, you get a correct-looking program that resets the state on every pass and never stops.
- **The anchor is a number of characters, not an address.** Edit the line and the anchor is recomputed at run time, because `>in @` reads it on the way past.
- **`random` is `0..n-1`**, so `10 random 10 +` is 10..19; Gforth is seeded from `utime`.
- **`3dup` is not in Gforth 0.7.3.** It is defined at the top with `2 pick` three times.
- **Gforth-specific words.** `outfile-execute`, `open-pipe` and `utime` are Gforth extensions.
- **Not a pattern.** A flag as a bit mask is an old, respectable trick. Rewinding the parser to loop is a stunt.
