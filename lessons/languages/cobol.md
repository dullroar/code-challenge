# COBOL

Entries: [`src/cobol`](../../src/cobol/README.md) (the idiomatic one) and [`src/cobol-weird`](../../src/cobol-weird/README.md) (no `IF`, no `PERFORM`).

COBOL (1959) was built for records, totals and reports, and it shows. What makes it special is that it moves rules and shapes *out of the procedure and into the data description*. What makes it a rich field for quirks is that it is old enough to have a feature, `ALTER`, that the standard has since deleted.

## What makes COBOL special

| Feature | Where | What it teaches |
| --- | --- | --- |
| A stop rule declared as data | [`cobol/timecards.cob` L41-42](../../src/cobol/timecards.cob#L41-L42): `01 WS-TOTAL PIC 99 VALUE 0.` / `88 OVER-FORTY VALUE 41 THRU 99.` used by [L93](../../src/cobol/timecards.cob#L93): `PERFORM DRAW-CARD UNTIL OVER-FORTY` | An `88`-level *condition name* is a named range of a field's values. The loop holds no comparison; change the rule by editing the data, not the code. |
| The picture does the rounding | [L107](../../src/cobol/timecards.cob#L107): `COMPUTE WS-HOURS = 10 + FUNCTION RANDOM * 10`, into `PIC 99` | Storing 10.0-19.99 into a two-digit field drops the fraction. The field's shape is the floor function. COBOL arithmetic is decimal, not binary floating point. |
| One string, seen twice | [L48-55](../../src/cobol/timecards.cob#L48-L55): `CATEGORY-TABLE REDEFINES CATEGORY-NAMES` / `PIC X(9) OCCURS 4 TIMES` | `REDEFINES` lays a second description over the same bytes. A table of strings is also one long string. |
| Files whose names are variables | `SELECT SQL-SCRIPT ASSIGN TO WS-SQL-PATH` | The program writes a SQL script as a line-sequential file and hands it to `sqlite3`: one transaction, or none. |

## ALTER

`ALTER` is exhibit A for "a language quirk that was once a feature." It was declared obsolete in 1985 and deleted from the standard in 2002. GnuCOBOL still runs it, and warns five times.

### 1. Behold the monstrosity

```bash
sandbox/container/run-image.sh src/cobol-weird
```

Three to five time-card rows and a committed total over 40, from a program with no `IF`, `PERFORM`, `EVALUATE`, `UNTIL` or `MOD`.

### 2. How the hell does that work?

Paragraphs run in the order they are written unless a `GO TO` redirects them. The loop is one paragraph that holds one `GO TO` ([`cobol-weird/timecards.cob` L150-151](../../src/cobol-weird/timecards.cob#L150-L151)):

```cobol
       NEXT-CARD.
           GO TO MEETINGS-CARD.
```

A paragraph that is exactly one `GO TO` is the only thing `ALTER` may change. Each category paragraph rewires it to the next category ([L157](../../src/cobol-weird/timecards.cob#L157), [L162](../../src/cobol-weird/timecards.cob#L162), [L167](../../src/cobol-weird/timecards.cob#L167), [L172](../../src/cobol-weird/timecards.cob#L172)): `ALTER NEXT-CARD TO PROCEED TO CODING-CARD`. Nothing counts modulo 4. "Which category is next" exists only as the current target of a jump.

The stop rule is overflow. `WS-HEADROOM` is `PIC 99` starting at 59 ([L44](../../src/cobol-weird/timecards.cob#L44)). Each card adds its hours ([L196-199](../../src/cobol-weird/timecards.cob#L196-L199)):

```cobol
ADD WS-HOURS TO WS-HEADROOM
    ON SIZE ERROR
        ALTER NEXT-CARD TO PROCEED TO FINISH-RUN
END-ADD
```

59 + total fits in two digits while the total is 40 or less. The add that reaches 100 is a *size error*: the field is left unchanged and `ON SIZE ERROR` rewires `NEXT-CARD` one last time. The `GO TO NEXT-CARD` that follows is the same statement as always, and now it ends the run.

### 3. What did we just learn?

- **A jump target can be state.** Control flow is not only the program counter walking source text; it can be data the program edits. Compare [Make's restart](make-cmake.md#gnu-make), [CMake's registers](make-cmake.md#cmake) and [Forth's `>in`](forth.md): all keep control state somewhere other than ordinary variables. See [patterns](../patterns.md#control-state-outside-variables).
- **Overflow is a decision.** `ON SIZE ERROR` is a conditional triggered by arithmetic running out of digits rather than by a comparison anyone wrote.
- **Structured programming won for a reason**, and this program is the reason. See the next step.

Tags: `ALTER` is **implementation-permitted** (deleted from the standard, kept by GnuCOBOL). Size-error behavior (field unchanged) is **guaranteed** by the standard.

### 4. Do this in production and you're fired

- **You cannot understand a paragraph by reading it.** `NEXT-CARD` says `GO TO MEETINGS-CARD` and, at run time, almost never does. That complaint is what got `ALTER` removed.
- **Debuggers show variables, not jump targets.** Nothing in the `WS-*` fields tells you which category is next.
- **Portability.** Newer compilers may not accept it, and standards-conformance flags may reject it.
- **Optimizers.** A compiler that cannot assume a `GO TO` is constant has little it can do with the paragraph.
- **Reentrancy.** Rewriting the code's own jump table is the opposite of reentrant: two callers share one `NEXT-CARD`. (On the rewriting-the-program theme, see [APL](apl.md#2-self-modifying-functions-apl-weird).)

Legitimate uses: none in new code. Historically, though, in memory-poor, performance-sensitive batch systems, a switch set once and tested by an unconditional `GO TO` was cheaper than testing a flag on every pass. That is the "mainframe in 1978" answer to the recurring question: *it was reasonable when the constraint was real*. See the [intro](../intro.md#the-recurring-question).

### 5. Now break it yourself

See [exercises](../exercises.md#b1-cobol-predict-then-break-alter-verified): predict what happens if you add a `DISPLAY` to `NEXT-CARD`, or change the `59`.

## Quirks

- **Fixed format.** Columns 1-6 were a sequence number; `*` in column 7 is a comment; division and paragraph names start in column 8 ("area A"), statements in column 12 ("area B"); **nothing past column 72 is read**. A long line is silently truncated, not rejected. `check.sh` rejects lines over 72 ([`cobol-weird/check.sh`](../../src/cobol-weird/check.sh)).
- **`STRING` does not clear its target.** It writes from the left and leaves old bytes to the right, so reused buffers need `MOVE SPACES` first.
- **Reserved words are everywhere.** `TAB` is reserved in GnuCOBOL, which is why the tab character is `WS-TAB`.
- **`SYSTEM` returns the raw wait status**: an exit code of 3 comes back as 768. [`cobol-weird`](../../src/cobol-weird/README.md#how-the-stunt-works) divides by 256 to recover it.
- **`ACCEPT ... FROM ENVIRONMENT` blanks the field** when the variable is unset, rather than leaving it alone.
- **The ISO week has to be hand-built.** COBOL has date functions but no ISO week; `FUNCTION INTEGER-OF-DATE` counts from 1601-01-01 (a Monday), and the Thursday rule is four `COMPUTE`s. The README notes it was checked against `date +%G-W%V` for 2020-2030.
- **Choosing without `IF`.** [`cobol-weird` L119](../../src/cobol-weird/timecards.cob#L119): `COMPUTE WS-BASE-IX = 1 + FUNCTION MIN(WS-XDG-LENGTH, 1)` picks one of two table entries by data alone.
- **`ALTER` needs a one-`GO TO` paragraph.** Put a `DISPLAY` in `NEXT-CARD` and the compiler refuses.
- **A size error leaves the target field unchanged**, so `WS-HEADROOM` needs no reset. Without `ON SIZE ERROR`, the add would silently drop the leading digit (99 + 1 = 00).

## Weird next to boring

[`cobol`](../../src/cobol/README.md) does the job in one `PERFORM ... UNTIL OVER-FORTY` with the rule declared as data. [`cobol-weird`](../../src/cobol-weird/README.md) does it with rewired jumps. The first is easier to change and read; the second shows what the language lets a program do to itself.

## Under what circumstances would this terrible idea become reasonable?

Rarely in the form shown. The `88`-level stop rule, though, is a good design wherever business rules change more often than code. The `ALTER` form was reasonable when memory and cycles were the constraint and the engineers owning the system understood every jump. It stopped being reasonable when teams, tools and maintenance horizons grew.
