# COBOL, weirder

**Teaches you:** why structured programming won, by running a program whose control flow rewrites itself.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

The [plain COBOL version](../cobol/README.md) loops with `PERFORM ... UNTIL`. This one has no `IF`, no `PERFORM`, no `EVALUATE`, no `UNTIL` and no `MOD` to rotate the categories. Control flow is `GO TO` and **`ALTER`**, a statement that changes where a `GO TO` jumps *while the program runs*. `ALTER` was declared obsolete in 1985 and deleted from the COBOL standard in 2002. GnuCOBOL still runs it, and warns five times.

The stop rule isn't a comparison either. It's a two-digit number overflowing.

## Run it

GnuCOBOL (`cobc`, 3.1 or later; `sudo apt install gnucobol` on Ubuntu) and `sqlite3`.

```bash
cd src/cobol-weird
cobc -xj timecards.cob      # compile and run; leaves a ./timecards binary (git-ignored)
./check.sh                  # set COBC=/path/to/cobc if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/CobolWeird/demo-timecards.db` (default `~/.local/share/CobolWeird/`). A run looks like this:

```text
# DEMO ONLY run 2026111414014239-12663
Meetings	19	19	2026-W46	DEMO ONLY
Coding	16	35	2026-W46	DEMO ONLY
Debugging	19	54	2026-W46	DEMO ONLY
# committed total=54 entries=3 DEMO ONLY
# no IF, no PERFORM: ALTER kept rewiring one GO TO, and a two-digit field overflowing pulled the plug
```

## How the stunt works

COBOL paragraphs run in the order they're written, falling from one into the next, unless a `GO TO` sends control somewhere else. So [`timecards.cob`](timecards.cob) reads top to bottom: set-up paragraphs fall through into the loop, and the loop ends by jumping to the last paragraph.

1. **The switchboard.** The loop is one paragraph containing one statement:

   ```cobol
   NEXT-CARD.
       GO TO MEETINGS-CARD.
   ```

   A paragraph that is exactly one `GO TO` is the only thing `ALTER` is allowed to change. `ALTER NEXT-CARD TO PROCEED TO CODING-CARD` rewrites that `GO TO`'s target, so the next time control reaches `NEXT-CARD` it goes to `CODING-CARD` instead. The source code never changes; the running program's jump does.
2. **The categories rotate by rewiring.** Each category's paragraph names itself, `ALTER`s `NEXT-CARD` to the category after it, and jumps to `RECORD-CARD`. Meetings points it at Coding, Coding at Debugging, Debugging at Learning, and Learning back at Meetings. Nothing counts cards modulo 4. Which category comes next exists only as the current target of one `GO TO`.
3. **`RECORD-CARD` does one card** (draws the hours, adds them to the total, prints the row, writes the `INSERT`) and ends with `GO TO NEXT-CARD`. So the loop is: `NEXT-CARD` jumps to whichever category it currently points at, that category re-points it and runs `RECORD-CARD`, which jumps back to `NEXT-CARD`.
4. **The tripwire is the stop rule.** `WS-HEADROOM` is `PIC 99`, two decimal digits, and starts at 59. Just before `GO TO NEXT-CARD`, each card's hours are added to it:

   ```cobol
   ADD WS-HOURS TO WS-HEADROOM
       ON SIZE ERROR
           ALTER NEXT-CARD TO PROCEED TO FINISH-RUN
   END-ADD
   ```

   59 + total fits in two digits while the total is 40 or less. The add that would take it to 100 or more is a *size error*. COBOL then leaves the field unchanged and runs the `ON SIZE ERROR` clause, which `ALTER`s `NEXT-CARD` one last time, to `FINISH-RUN`. The `GO TO NEXT-CARD` that follows is the same statement as every other time round, but now it ends the run. Four 10-hour cards make 59 + 40 = 99, which still fits, so a fifth card is drawn, exactly as the rule requires.
5. **`FINISH-RUN`** commits the SQL script through `sqlite3` and prints the summary.

### What this version refuses to use, and the honest price

`check.sh` strips comments and string literals and then fails if `IF`, `PERFORM`, `EVALUATE`, `UNTIL`, `VARYING`, `DEPENDING`, `SEARCH` or `WHEN` appears. It also insists on exactly five `ALTER`s and exactly one `ON SIZE ERROR`. Two places still needed a decision without `IF`:

- **`ON SIZE ERROR` is a conditional.** It's the one decision in the program, and it's the stop rule itself. It's a decision triggered by arithmetic running out of digits, not by a comparison anyone wrote.
- **Choosing the data folder.** `$XDG_DATA_HOME` if set, else `$HOME/.local/share`. Both paths go in a two-entry table, and the subscript is `1 + MIN(length of XDG_DATA_HOME, 1)`. Data picks the entry; nothing branches.
- **A failed `sqlite3` can't skip the summary.** Without `IF`, the shell command does the reporting instead (`... || { echo ... >&2; exit 1; }`), and its exit status becomes the program's exit code, divided by 256 because `SYSTEM` returns the raw wait status. A failed run still prints the `# committed` line, but on a failed run it also prints an error on stderr and exits 1.

### Where the program reaches outside itself

The same as the plain version: `CALL "C$GETPID"` for the run id and seed, `CALL "SYSTEM"` once for `mkdir -p` and once to run `sqlite3` on the finished script, and `CHECK(demo_only=1)` in the table, which `check.sh` tests.

## Gotchas worth knowing

- **`ALTER` only works on a one-`GO TO` paragraph.** That's why `NEXT-CARD` has nothing else in it. Put a `DISPLAY` in there and the compiler refuses the `ALTER`.
- **The program's state is partly in its jumps.** A debugger showing `WS-*` variables can't tell you which category is next; you have to know what `NEXT-CARD` was last altered to. This is precisely the complaint that got `ALTER` removed: you can't understand a paragraph by reading it.
- **A size error leaves the target unchanged.** That's the standard behavior, and why `WS-HEADROOM` doesn't need resetting. Without an `ON SIZE ERROR` clause, the add would instead quietly drop the leading digit (99 + 1 = 00).
- **`-Wall` shows five `ALTER is obsolete` warnings.** They're the point.
- **SQL by string building is a bad habit.** It's safe here only because every value is a number computed by the program or one of four fixed words. Don't copy it.
