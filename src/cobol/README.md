# COBOL

**Teaches you:** that a stop rule can be declared as data, and that a number's picture can do your rounding.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

COBOL (1959) was built for exactly this kind of program: records, totals and a report. The challenge ("add 10-19 hour cards until the total passes 40") is one statement in the `PROCEDURE DIVISION`, `PERFORM DRAW-CARD UNTIL OVER-FORTY`. The rule itself isn't in the procedure code at all. `OVER-FORTY` is declared in the `DATA DIVISION`, on the total.

## Run it

GnuCOBOL (`cobc`, 3.1 or later; `sudo apt install gnucobol` on Ubuntu) and `sqlite3`.

```bash
cd src/cobol
cobc -xj timecards.cob      # compile and run; leaves a ./timecards binary (git-ignored)
./check.sh                  # set COBC=/path/to/cobc if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/Cobol/demo-timecards.db` (default `~/.local/share/Cobol/`). A run looks like this:

```text
# DEMO ONLY run 2026111413594869-8051
Meetings	11	11	2026-W46	DEMO ONLY
Coding	11	22	2026-W46	DEMO ONLY
Debugging	12	34	2026-W46	DEMO ONLY
Learning	15	49	2026-W46	DEMO ONLY
# committed total=49 entries=4 DEMO ONLY
# PERFORM UNTIL an 88-level: the stop rule is declared in the DATA DIVISION
```

## How the stunt works

A COBOL program has four *divisions*, always in the same order: `IDENTIFICATION` (its name), `ENVIRONMENT` (which files it uses), `DATA` (every variable, with its exact shape) and `PROCEDURE` (the code). Read [`timecards.cob`](timecards.cob) top to bottom with this beside it.

1. **The stop rule is data.** In the `WORKING-STORAGE SECTION`:

   ```cobol
   01  WS-TOTAL                PIC 99 VALUE 0.
       88  OVER-FORTY          VALUE 41 THRU 99.
   ```

   `PIC 99` ("picture") says the total is exactly two decimal digits. The `88` line under it is a *condition name*. It doesn't store anything. It names a range of `WS-TOTAL`'s values, and using `OVER-FORTY` anywhere asks whether the total is currently in that range. So the loop, `PERFORM DRAW-CARD UNTIL OVER-FORTY`, holds no comparison. Change the rule and you edit the data description, not the code.
2. **The picture does the rounding.** `COMPUTE WS-HOURS = 10 + FUNCTION RANDOM * 10` produces something from 10.0 to 19.99. `WS-HOURS` is `PIC 99`, two digits with no decimal places, so storing into it simply drops the fraction. Nothing calls a floor function: the field's shape gives 10..19. COBOL arithmetic is decimal, not binary floating point, which is why money still runs on it.
3. **One string, seen twice.** The four category names are four 9-character `FILLER`s in `CATEGORY-NAMES`. `CATEGORY-TABLE REDEFINES CATEGORY-NAMES` lays a second description over the same 36 bytes: `CATEGORY ... OCCURS 4 TIMES`, an array. `DRAW-CARD` picks `CATEGORY(MOD(entries, 4) + 1)`. COBOL subscripts start at 1.
4. **The SQL is a record file.** `SELECT SQL-SCRIPT ASSIGN TO WS-SQL-PATH ORGANIZATION IS LINE SEQUENTIAL` declares a file whose name is in a variable, and `FD SQL-SCRIPT` describes its record: one 400-character line. The program `WRITE`s a `CREATE TABLE`, a `BEGIN`, one `INSERT` per card and a `COMMIT` to it, `CLOSE`s it, and only then hands the whole script to `sqlite3`. So every run lands in one transaction, or not at all.
5. **The ISO week is arithmetic.** COBOL has date functions but no ISO week. `FUNCTION INTEGER-OF-DATE` counts days from 1601-01-01, which was a Monday, so `MOD(day - 1, 7)` is 0 on Mondays. An ISO week belongs to the year its Thursday falls in, and week 1 is the one holding that year's first Thursday. `WORK-OUT-WEEK` is those two facts in four `COMPUTE`s. It was checked against `date +%G-W%V` for every day from 2020 to 2030, including the week-53 years, and `check.sh` compares it again on every run.

### Where the program reaches outside itself

| Line | Why |
| --- | --- |
| `CALL "C$GETPID"` | The process id, added to the timestamp for the run id, so two runs in the same hundredth of a second still differ. Also mixed into the random seed |
| `CALL "SYSTEM"` in `OPEN-SCRIPT` | Runs `mkdir -p` on the data folder before the script file is opened in it |
| `CALL "SYSTEM"` in `COMMIT-SCRIPT` | Runs `sqlite3 -bail db < script && rm -f script`. The script is deleted only if `sqlite3` succeeded. Otherwise the program prints where it is and exits 1 |
| `CHECK(demo_only=1)` | Makes a non-demo row unrepresentable in the table. `check.sh` tries to insert one and expects SQLite to refuse |

## Gotchas worth knowing

- **Columns matter.** This is *fixed format*, from punched cards: columns 1-6 were a sequence number, a `*` in column 7 makes a comment, division and paragraph names start in column 8 ("area A"), statements start in column 12 ("area B"), and **nothing past column 72 is read**. A long line is silently cut, not rejected. `check.sh` fails if any line is longer than 72. GnuCOBOL also accepts `cobc -free`, which drops all of this.
- **`STRING` doesn't clear its target.** It writes from the left and leaves whatever was already to the right. That's why every reused buffer gets `MOVE SPACES` first.
- **Some names are taken.** COBOL has hundreds of reserved words. `TAB` is one in GnuCOBOL, which is why the tab character is `WS-TAB`.
- **`SYSTEM` returns the raw wait status.** An exit code of 3 comes back as 768 (3 × 256). This file only compares it with zero.
- **`ACCEPT ... FROM ENVIRONMENT` blanks the field when the variable is unset.** It doesn't leave it alone, so the `IF` that falls back to `$HOME/.local/share` tests for spaces.
- **Ubuntu's compiler prints a `_FORTIFY_SOURCE redefined` warning** on every compile. It comes from `cobc`'s C flags meeting Ubuntu's GCC defaults, and it's harmless.
- **SQL by string building is a bad habit.** It's safe here only because every value is a number computed by the program or one of four fixed words. Don't copy it.
