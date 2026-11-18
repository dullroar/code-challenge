# Answers key

Worked solutions for the [exercises](exercises.md). **Try the exercise first**: write your prediction down, run it, and only then read here.

Every solution below was run against the real entries:

- Docker exercises by [`tools/verify-exercises.sh`](tools/verify-exercises.sh) (every mutation is made on a *copy* of the entry);
- Windows Sandbox exercises by [`tools/verify-windows.ps1`](tools/verify-windows.ps1) on Windows 11 Pro.

Output is random, so numbers here are *examples*. What is guaranteed is the **property** each exercise asks you to observe. Folder variables: `WORK=$(mktemp -d)`, and `cp -r src/<entry> "$WORK/"` before you edit.

## A1. Read the rows

Example output from `src/cobol-weird`:

```text
Meetings   15   15
Coding     19   34
Debugging  12   46      <- crossing card: the total before it was 34, which is <= 40
# committed total=46 entries=3 DEMO ONLY
```

- The card that crosses is the first whose running total is **over 40**; the total before it is always **at most 40** (otherwise the run would have stopped earlier). The totals can end anywhere from 41 to 59.
- Exactly 40 does not stop the run because every stop rule asks "is the total *over* 40?" (`<= 40` keeps going, `41` or more stops). Four 10-hour cards total exactly 40, so a fifth card is drawn. [`regex-dotnet`](../src/regex-dotnet/README.md) prints no running-total column, so `check-demo.sh` adds the hours itself.

## B1. COBOL: predict, then break ALTER

```bash
cp -r src/cobol-weird "$WORK/"                                   # run everything from the repo root
sed -i 's/PIC 99 VALUE 59\./PIC 99 VALUE 49./' "$WORK/cobol-weird/timecards.cob"
sandbox/container/run-image.sh "$WORK/cobol-weird" > out.txt 2>&1
bash lessons/tools/check-demo.sh out.txt 50                      # PASS: 4 rows, total 59 (limit 50)
sandbox/run.sh "$WORK/cobol-weird"                               # FAIL run N: kept going after the total passed 40
```

- **Prediction:** `WS-HEADROOM` is `PIC 99`. It overflows when `headroom + total` reaches 100, i.e. when `total >= 100 - 49 = 51`. So the run stops on the first card that takes the total **above 50**. (With the original 59 it is above 40.)
- The run ends with totals from 51 to 69; `check-demo.sh ... 50` passes. The entry's own `check.sh` fails because it hard-codes 40.
- **`DISPLAY "x"` inside `NEXT-CARD`:** the *build* fails, because `ALTER` may only rewrite a paragraph that is exactly one `GO TO`:

```text
timecards.cob:158: error: 'NEXT-CARD' is not an alterable paragraph
```

  (five of these, one per `ALTER`). The compiler has to know that the paragraph's only content is a jump whose target it can patch.

## B2. Haskell: break the laziness

1. `let entries = length cards` (a lazy binding) ends the run with:

   ```text
   timecards: fd:5: hPutStr: illegal operation (handle is closed)
   ```

   Nothing demands the cards until the summary line is printed, which is *after* the `COMMIT` and after the pipe to `sqlite3` was closed; forcing a cell then fires its effect on a closed handle. `check-demo.sh` fails (a row or two, no summary).
2. Replacing `unsafeInterleaveIO $ case ...` with `id $ case ...` does **not** hang. It dies at once with:

   ```text
   timecards: cyclic evaluation in fixIO
   ```

   Without the interleave, building the list of actions pattern-matches `before`, which needs `cards`, which `fixIO` has not produced yet. (Only the first row, `Meetings 10 10`, is printed before the loop is detected.) The `case` has to sit *inside* the deferred action.

## B3. Forth: move the anchor

- **(a)** `0 0` on its own line, then `>in @ step rewind?`: **works**. `>in @` captures the position *after* the `@`, and the rewind jumps back to that anchor, which is after the `0 0`. So `0 0` is never re-executed. `check-demo.sh` passes.
- **(b)** `>in @ 0 0 step rewind?`: the anchor is now *before* `0 0`, so every rewind re-runs `0 0` and pushes a fresh zero state. The total restarts from zero on every pass, and the stop rule never fires. With `SANDBOX_TIMEOUT=30` you get hundreds of rows (678 in the verification run), every row has total = hours, and there is no `# committed` line.
- **(c)** `41 <` to `51 <`: `check-demo.sh out.txt 50` passes (stops when the total reaches 51).
- **Why only (b)?** The parse position is a program counter: where it jumps back to decides which tokens are the loop body. State must stay *outside* the body (before the anchor).

## B4. Make: remove the no-op, and override the clock

1. Without `@:` the recipe `$(if ...,$(file >$@,...))` expands to nothing, so Make runs no command and **does not count the makefile as remade**. It never restarts, so no card is ever included:

   ```text
   # committed total=0 entries=0 DEMO ONLY
   # make re-executed itself 0 times, once per card
   ```

   The card file *was* written at expansion time, but Make only notices a remade makefile when a command ran. (`sandbox/run.sh` fails: "unexpected stderr".)
2. `lessons/tools/run-in-sandbox.sh src/make-gnu make NOW=1700000000` prints rows labelled `2023-W46`. `date -u -d @1700000000 +%G-W%V` prints `2023-W46`.

## B5. CMake: mutate the literal

With 31 `x`s (`"^xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"`) the loop stops once the total reaches 31, i.e. **passes 30**. `check-demo.sh out.txt 30` passes on every run; with the default limit of 40 it passes only when the final total happens to be 41 or more, so do not rely on it. `sandbox/run.sh` fails because the entry's own check expects 40.

The stop test must come **first** in the condition because a failed `MATCHES` clears every `CMAKE_MATCH_n` register and a successful one rewrites them. The *main* match has to run last for its captures to be the ones that survive into the next pass.

## B6. APL: the off-by-one rewrite

1. `4↓` drops only the header and *three* gene lines, so the child's body keeps its parent's `T←H` gene (the fourth). Every child resets its running total to just its own hours, and `Alive←40≥T` is always 1. The program recurses until the timeout:

   ```text
   Meetings    18    18    ...
   Coding    17    17    ...        <- total equals hours on every row
   ...
   TIMEOUT after 40s          (exit 124)
   ```

   On the laptop used for the 2026-11-16 re-run the recursion filled the container's 2 GB memory limit first, so the run ended with `Killed` (exit 137) after about 2,000 lines instead of the timeout. Either way it never reaches `# committed`; which one you see depends on the machine.

   That is why [`apl-weird/check.sh`](../src/apl-weird/check.sh) runs under `timeout`: this failure is silent and structural.
2. `⎕IO←1` gives an `INDEX ERROR` on `Card0[5]`, the line `Show(⊃Categories[C])...`. `C` counts categories from 0 (`C←0`, `4|C+1`), which is a valid index only with origin 0. No rows are printed.

## B7. LINQ: enumerate twice

The program (also in [`solutions/b7-linq`](solutions/b7-linq)):

```csharp
var q = Enumerable.Range(1, 3).Select(i => { Console.WriteLine($"effect {i}"); return i; });
Console.WriteLine("-- (a) declared q");
Console.WriteLine("-- (b) q.Sum()");
_ = q.Sum();
Console.WriteLine("-- (c) q.Sum() and q.ToList()");
_ = q.Sum(); _ = q.ToList();
Console.WriteLine("-- (d) q.ToList() once, then sum the list");
var list = q.ToList(); _ = list.Sum();
var r = new Random(42);
Console.WriteLine(string.Join(" ", Enumerable.Range(0, 5).Select(_ => r.Next(10, 20))));
```

| Step | `effect` lines | Why |
| --- | --- | --- |
| (a) declare | 0 | `Select` is **deferred**: it builds a description, not a result. |
| (b) `Sum()` | 3 | Enumerating runs the lambda once per element. |
| (c) `Sum()` and `ToList()` | 6 | Each enumeration re-runs the pipeline and every side effect in it. |
| (d) `ToList()` then sum the list | 3 | `ToList()` is eager and snapshots the values; summing a list re-runs nothing. |

Seed 42 gives `16 11 11 15 11`. A `System.Random` with a fixed seed is a deterministic sequence, and the `.xaml` file creates `new Random(42)` with no other entropy, so every run produces the same cards. The eager operator that forces the lazy tail in `LinqChallenge1` is the final `.Aggregate(0, (count, _) => count + 1)`.

## B8. Regex: what survives a failed match

- **.NET:** with `(?!)` appended the match can never succeed; the host's `match.Success` is false and a failed `Match` exposes **no captures**, so every card accumulated in the stacks is lost:

  ```text
  match returned: false
  # captured total=0 entries=0 DEMO ONLY
  ```

  This is why the .NET entry must *return true* while the Perl and PCRE2 entries can return false after writing everything: their output is a side effect, `regex-dotnet`'s output is the captures.
- **pcre2grep:** `pcre2grep` starts a callout program with `fork` and `execv`, which does not search `PATH`. A bare `sqlite3` fails to start, which the engine treats exactly like a callout that returned non-zero, i.e. a vetoed branch. The run prints **nothing**, exits 0, and writes no rows.
- **Contrast (three sentences):** In Perl, `local` variables unwind on backtracking but `print`s and `INSERT`s already happened, so the work survives a failed match. In PCRE2 the callout state lives in a C struct that backtracking never touches, so everything survives. In .NET the only output *is* the captures, and a failed match discards them, so nothing survives.

## B9. sed: watch a computation

```bash
lessons/tools/run-in-sandbox.sh -e TRACE=1 src/regex-sed ./timecards.sh 2> trace.txt
grep -c 'tot:' trace.txt                  # e.g. 48 for a three-card run
grep -E 'tot:#{41}' trace.txt | tail -1   # the final state: 41+ tally marks
```

- The state is one line, e.g. `run:... k:### rng:0110101000001111 cats:Coding,... tot: n: c:Meetings`; `tot:` grows by tally marks (`#`). About 16 lines per card in the verification run, but it **varies** because of rejection.
- [L29](../src/regex-sed/timecards.sed#L29), `/ rng:1(01|1)/b draw`, redraws when the 4-bit nibble is 10-15. `1(01|1)` matches `101x` (10, 11) and `11xx` (12-15): the values a 10-19 hour draw cannot use. A rejected draw repeats the shift-register steps, which is why the per-card line count is not constant.

## B10. Lisp: swap the method combination

1. With `progn` in both places every run deals **all five cards**, because `progn` calls every applicable method and ignores their return values:

   ```text
   Meetings	13	78	2026-W47	DEMO ONLY
   # committed total=78 entries=5 DEMO ONLY
   # PUNCH had 0 OR methods and 5 ran: the class precedence list is the loop, and OR is the stop rule
   ```

   The totals end anywhere from 50 to 95. The method count says `0 OR methods` because the note counts methods qualified `or`, and there are none now. `check.sh` fails on your copy because it insists on `(:method-combination or)`. (The unmodified entry's own check runs this same mutation to prove `or` is the stop rule.)
2. Changing only the generic function leaves five methods with a qualifier that `progn` does not accept. SBCL warns:

   ```text
   WARNING:
      Invalid qualifiers for PROGN method combination in method
      #<STANDARD-METHOD TIMECARDS-WEIRD::PUNCH OR (CARD-5) ...>:
        (OR).
   ```

   A method's qualifiers have to match its generic function's combination: the combination is the generic function's choice, not the method's.
3. With `100` there are always five rows and a total of at most 95. The program stops because it **runs out of classes**, not because the rule was met; `check-demo.sh out.txt 100` fails with `final total N does not pass 100`. Five is the most it can deal: cards are at least 10 hours, so four cards total at least 40, and a fifth always crosses 40. A limit of 100 needs eleven classes (ten cards of 10 total exactly 100, so an eleventh must cross), so you would add `defcard` forms and renumber.
- **The stop rule is `or`**, and the program does not fail without it, because `progn` is a valid combination: the program just never stops early. A silent change of meaning is the whole risk of the technique.

## B11. m4: quote the recursion

1. Same seed, same cards:

   ```text
   Meetings	19	19
   Coding	13	32
   Debugging	16	48
   ```

   Only the run id (`1794869456-12345`: the clock and the seed) can differ. The generator is the Park-Miller formula and nothing else supplies randomness. `ifdef([tc_seed], [], ...)` ([L34](../src/m4/timecards.m4#L34)) creates a random seed only when you have not already defined one.
2. Unbracketed, `tc_card()` is *called while `ifelse`'s arguments are being collected*, so every call makes another call before `ifelse` can choose anything. m4 expands arguments before it runs the macro. With `SANDBOX_TIMEOUT=20` the run ends in a timeout (exit 124) and prints nothing: m4 buffers its output and was killed before it flushed. With `-L 50`:

   ```text
   m4:timecards.m4:87: recursion limit of 50 exceeded, use -L<N> to change it
   ```

   and exit status 1. The brackets turn `tc_card()` into text that is only expanded when `ifelse` returns it, after the test; that is the only stop rule the program has.
3. `eval(tc_total > 60)`: the run stops on the first card that takes the total above 60. `check-demo.sh out.txt 60` passes.

## B12. Tcl: edit the program in the database

1. With `recursive_triggers = OFF` the first `INSERT` fires the trigger once; the trigger inserts card 2; **that** insert does not fire the trigger again, because a trigger does not fire itself unless recursion is on. So card 1 is printed (by `tcl('born', ...)` in the trigger), card 2 is in the database but was never printed:

   ```text
   Meetings	17	17	2026-W47	DEMO ONLY
   # committed total=31 entries=2 DEMO ONLY
   ```

   `check-demo.sh` fails: "final total 17 does not pass 40", and the summary line disagrees with the single row.
2. The text of the `hours` row is the Tcl program for the dice. With `expr {10}` every card is 10 hours:

   ```text
   Meetings	10	10
   Coding	10	20
   Debugging	10	30
   Learning	10	40
   Meetings	10	50
   # committed total=50 entries=5 DEMO ONLY
   ```

   The trigger's rule is `NEW.running_total <= 40`, so a total of exactly 40 draws another card (the same reason as in A1). `check-demo.sh` passes: five cards of 10 hours is a legal run.
- **The three hooks:** `db function tcl call` (SQL calls Tcl), the `unknown` override (the table is the library), and the recursive trigger (the loop). In step 2 you changed a row that `unknown` fetches: the *program* changed without editing a line of Tcl.

## B13. AWK: the missing RT

The digit file is `1 2` followed by a newline. With `RS="[0-9]"` the records are: `""` ending in `1` (RT=1), `" "` ending in `2` (RT=2), and `"\n"` with **no** digit after it (RT is empty).

1. Dice 1 and 2 make hours 11 and 12:

   ```text
   Meetings	11	11	2026-W47	DEMO ONLY
   Coding	12	23	2026-W47	DEMO ONLY
   # committed total=23 entries=2 DEMO ONLY
   ```

   The third record is skipped by rule 1, `RT == "" { next }`.
2. Without the guard the third record is dealt like the others, and `10 + RT` with an empty `RT` is `10 + 0`: a phantom card, `Debugging 10 33`, `entries=3`. It is a real INSERT too.
3. mawk has no `RT`. The variable is never set, so `RT == ""` is true for **every** record, rule 1 skips them all, `t` never grows and `t > 40` never fires:

   ```text
   # committed total=0 entries=0 DEMO ONLY
   ```

   No error, exit 0. On `/dev/urandom` the same program never stops and mawk reads until it runs out of memory (verified under a 400 MB limit). A program that *looks* portable and silently computes nothing is worse than one that crashes. `RT` is a **gawk extension**: implementation-permitted, not part of POSIX.
4. `t > 80 { exit }`: the run stops on the first card that takes the total above 80, and `check-demo.sh out.txt 80` passes. The pattern *is* the stop rule: `check.sh` makes the same edit on a stream of 5s to prove it (three cards become six).

## B14. find: rig the dice

The fake `mktemp` makes the dice. The walk reads the last character of each six-character name, in the pattern `-path '*/[!/][!/][!/][!/][!/][STUVWX]/?'`.

1. `xxxxxS` is in group 9, so each card is 19 hours:

   ```text
   Meetings	19	19	2026-W47	DEMO ONLY
   Coding	19	38	2026-W47	DEMO ONLY
   Debugging	19	57	2026-W47	DEMO ONLY
   # committed total=57 entries=3 DEMO ONLY
   ```

   The first total, 19, is the digit sequence 1 ... 9, 0 ... 9: the path has one directory named `0`, and the last digit is 9. After the third card the path has five of them, so the tens digit is 5 and the stop rule fires.
2. `xxxxxY` ends in `Y`, which is not one of the 60 good characters, so the walk tries the character before it. That is `x`, in the group `stuvwx`: 13 hours. The totals are 13, 26, 39 and 52. The stop rule says "over 40", and 39 is not, so a fourth card is made. The categories are `Meetings`, `Coding`, `Debugging`, `Learning`.
3. `xxxxYZ`: `Z` is thrown away, and so is `Y` before it. The last branch of the table is the default: 10 hours. The totals are 10, 20, 30, 40 and 50. The stop rule is "five directories named `0`, or four of them and a last digit that is not `0`". At 40 the path has four of them and the last digit is `0`, so it continues. The fifth card is `Meetings` again.

## B15. GNU find: move the stop rule, read the profile

1. `([^/]*/){31}.*` matches a path with at least 31 slashes. The start directory `t` is depth 0, and the end of a card is at depth equal to the running total, so the test is true exactly when the total is 31 or more, which is "over 30". `check-demo.sh out.txt 30` passes. The entry's own `check.sh` fails, because the seven forced-dice scenarios (for example `10 10 10 10 10`, five cards) now stop after fewer cards. The stop rule is that one number, because depth is the total.
2. With `FIND_D=rates`, find prints its profile on stderr after the walk. Each test shows `[est success rate 0.8]` (the optimizer's flat guess) and `[real success rate a/b=...]`. The `-name b00` test succeeds once per card, so `a` equals the number of rows. The guess is far off because the optimizer has no idea that most directories are named `b..` and only one in about 15 ends a card.

## B16. tar: read the program, then run it

1. Four cards run: 12, 24, 36 and 48. The total passes 40 at the fourth card, so the fifth slot (`050.card`) and the `stop-over` members after the halt are read and ignored. The trace table shows `ignored: halted` for them.
2. Changing `limit=40` to `limit=20` in `021.stop-over` makes the halt happen after the second card (24 is over 20). Nothing in `dispatch.sh` changed: the limit is data, in the archive. `check-demo.sh out.txt 20` passes. Order matters: tar reads members in the order they are in the archive, so a repack in a different order is a different program.
3. `inspect.sh` marks `025.exec` as `REFUSE (unknown record type)` and exits 4. `interpret.sh --execute` asks the inspector first, so it exits 4, prints that nothing was run, and starts no tar. No `pwned` appears. A plain `tar -xf` writes `025.exec` as an inert file and runs nothing, because an archive cannot register a hook for itself. **Parsing** was done by `tar -t` and `tar -xO` inside `inspect.sh`, and by tar again inside `interpret.sh`. **Running** happened only in `interpret.sh --execute`, in `tar --to-command`. The trust boundary is the command line the operator typed.

## B17. tar, weirder: predict the clock

1. With 45 ticks the machine reaches 45 hours of work, but the third card needs the 46th. It prints the two closed cards (`Meetings 12 12`, `Coding 17 29`), reports `the clock ran out` and exits 3. With 46 ticks it finishes: three cards, total 46, exit 0.
2. `--ticks 92 --interval 2`: 92 records, one callback every second record, so 46 callbacks and the run finishes. `--ticks 91`: 45 callbacks, and it stalls. `TAR_CHECKPOINT` is the record number, so the last value in the finished run is 92 and `fsm.tick` shows it, while the machine has counted 46 hours. The check script says this as: last `TAR_CHECKPOINT` = ticks x K.
3. 260 blocks at `-b 4` are 65 records, so `floor(65 / 1) = 65` ticks. The same three cards, a total of 46, and 65 - 46 = 19 idle ticks. The tape is 65 x 2,048 = 133,120 bytes.
4. The payload is zeros, and the only other bytes are the member's header (a name and some numbers; 74 non-zero bytes in the test run). Nothing reads the content for its meaning. Only the size counts, because the size decides how many records tar writes.

## B18. ed: move the stop rule and break the cleanup

1. `DICE="0 0 0 0 0"`: five cards of 10 hours, totals 10, 20, 30, 40, 50. The run continues at 40, because 40 is not over 40, and the fifth card gets the category of line 5, `Meetings` (the category list is Meetings, Coding, Debugging, Learning, Meetings). `DICE="9 9 9 9 9"`: three cards of 19 hours, 19, 38, 57.
2. `DICE="3 3 3 3 3"` is 13 hours a card. With `x\{41,\}`: 13, 26, 39, 52, four cards. With `x\{31,\}`: 13, 26, 39, three cards, because 39 is over 30 and the bar becomes a bang. `check-demo.sh out.txt 30` passes. The stop rule is the regular expression over the marks.
3. The output has a fifth line, `Dead 0 52`. At card 4 the total is 52, so the ledger line has a `!`. Card 5 joins with it, the Dead rule rewrites the joined line to `Dead 0!` plus the marks, and the decimal rules print the total. With the cleanup in place `g/^Dead /d` removes it. **Features:** step 1 is the rewrite table and the addressing (a changed number of marks), step 2 is a regular expression interval, step 3 is `g` with `d`.

## C1. Weird next to boring

Measured with the verification script (non-comment lines):

| Pair | Idiomatic | Weird |
| --- | --- | --- |
| COBOL | 156 | 170 |
| Haskell | 91 | 108 |
| Forth | 97 | 84 |
| APL | 41 | 47 |
| Lisp | 150 | 110 |
| Tcl | 138 | 118 |
| AWK | 85 | 41 |

Sample comparison for Haskell: the idiomatic `timecards` is one **pure function** (`span`), so a unit test needs no database, and a debugger shows plain lists. The weird version cannot be tested without running its effects and the order of effects depends on the consumer; but it can do something the idiomatic one cannot: *write each row exactly when that card is first demanded*, with no loop or accumulator in the program. It is the right choice for a lazy streaming library or a teaching demo, not for application code.

Forth is the instructive exception: the weird version is *shorter* because it deletes the `variable`s and the word that updates them, trading them for stack discipline.

Lisp, Tcl and AWK also come out shorter in the weird version, but mostly because the weird versions *do less*, not because the stunt is more compact: `lisp` works out the ISO week itself (calendar arithmetic, plus an optional date argument and a `card` struct) where `lisp-weird` just asks `date`; `tcl` has a namespace with separate `draw`, `save`, `row` and window procs where `tcl-weird` has two procs and some SQL; `awk` has six helper functions where `awk-weird` has none. Line count measures what each program carries, not how hard it is to understand (the weird entries put the difficulty into comments and READMEs). Counts include blank lines and exclude comment-only lines.

## C2. Make the constraint real

A reference check, [`solutions/c2-forth-rule-check.sh`](solutions/c2-forth-rule-check.sh):

```bash
code=$(tr -d '\r' < "$f" | sed -E -e 's/(^|[[:space:]])[\]([[:space:]].*)?$//' \
                                  -e 's/[(][^)]*[)]//g' -e 's/[.]"[^"]*"//g')   # strip \ comments, ( ) comments, ." strings
grep -Eiqw 'begin|until|while|repeat|again|if|then|else|do|loop|case|of|recurse|exit|leave' <<<"$code" && fail
grep -Eiqw 'variable|buffer:' <<<"$code" && fail
(( $(grep -o '>in @' <<<"$code" | wc -l) >= 2 )) || fail
```

Run against the real file it prints `OK: no control words, no variables, >in @ x3`. The three mutations (verified):

```bash
sed 's/^drop /begin drop /'              timecards.fs > m1.fs   # FAIL: banned control word: begin
sed 's/^utime drop/variable v utime drop/' timecards.fs > m2.fs # FAIL: a variable is declared
sed 's/>in @/0/g'                         timecards.fs > m3.fs  # FAIL: >in @ appears 0 time(s)
```

A `begin if until` placed after a `\` on a line is stripped first, so it does not trigger.

## C3. A loop whose state is not a variable

```bash
seq 10 | awk '{ print ++c }'          # prints 1..10
```

The loop is awk's **implicit main loop**: it runs the rule once per input record. The state ("how many times") lives in the *input stream*, which the caller controls (`seq N` supplies N records). `c` only counts. No `for`, `while`, `do`, `function` or `goto` appears. Verified for N = 1, 3, 10. Knowledge level: **guaranteed**: POSIX defines the record-processing model.

## D. Port the challenge

A complete reference answer in awk is in [`solutions/awk-port`](solutions/awk-port): `timecards.awk`, a `Dockerfile`, and a `check.sh`. Run it:

```bash
sandbox/container/run-image.sh lessons/solutions/awk-port   # build and run, shows the rows and the SQLite table
sandbox/run.sh lessons/solutions/awk-port                   # its own check: 25 runs
```

How it satisfies the criteria:

| Criterion | How |
| --- | --- |
| The stop rule is the trick | `total <= 40 { ... }` is a *pattern*; the five records come from `seq 5`, and once the total passes 40 no later record matches. Five records always suffice (5 x 10 >= 50). |
| DEMO ONLY enforced | `CHECK(demo_only = 1)` in the table; `check.sh` tries to insert `demo_only = 0` and fails if it is accepted. |
| 25 runs, varied hours | `check.sh` loops 25 times, compares the printed rows with the `# committed` line and the SQLite row count, and requires at least 5 distinct hour values. |
| Constraint is real | `check.sh` strips comments and strings and fails on `for`, `while`, `do`, `function`, `func` or `goto`. |

Verified mutations: adding a `for` loop makes the check fail; making the hours constant (`hours = 10`) makes it fail (fewer than five distinct hour values).

## E1. Run and read the evidence (Windows Sandbox)

```powershell
sandbox\windows\run.ps1 src\LinqChallenge1
sandbox\windows\run.ps1 src\xaml -RunArgs strict.xaml
```

Verified output highlights:

```text
network: blocked
OK: no orchestration helper, build clean, one run persisted exactly 40.0h across 5 fixed rows, and the process exited on its own
PASS LinqChallenge1 (check.ps1 exited 0)
...
wrote: C:\work\xaml\data\xaml-demo-timecards.xml (607 bytes)
screenshot: ...\out\screenshot.png
PASS xaml (still running with a window after 20s; closed cleanly by the harness)
```

Fixed-data entries: the LINQ ones always total exactly 40.0h (a fixed work week). Random: `ModernChallenge1` and every other entry; `xaml` is *seeded* random (`Random(42)`), so it is the same every run. Needs the .NET 10 SDK on the host.

## E2. Change the XAML interpreter's seed

Replacing `<sys:Int32>42</sys:Int32>` with `7` in `strict.xaml` and running it in Windows Sandbox still passes (the window is shown and closed by the harness). The sandbox does not print the hours, so read them with the B7 program: seed 42 gives `16 11 11 15 11`; `new Random(7)` gives a different sequence. The same seed always gives the same sequence because `System.Random` is deterministic given its seed.

"The variable" is the `<sys:Random x:Key="rnd">` resource plus the **carrier arrays**: each `ObjectDataProvider` call fills a `char[]`/`byte[]` in place and the next one reads it. The loop is unrolled (four copied passes, per the [README](../src/xaml/README.md)) because XAML has no loop construct: the file needs one copy of the draw-and-store sequence per card.

## F. Prove a README claim

Claim, from [`src/haskell/README.md`](../src/haskell/README.md): "`takeWhile` is not enough: `takeWhile (<= 40)` drops the card that crosses the line, and the challenge needs it. `span` hands back both halves."

[`solutions/f-takewhile.hs`](solutions/f-takewhile.hs):

```haskell
main :: IO ()
main = do
  let totals = scanl1 (+) [15, 11, 12, 11] :: [Int]            -- 15, 26, 38, 49
  putStrLn ("takeWhile: " ++ show (takeWhile (<= 40) totals))
  let (under, over) = span (<= 40) totals
  putStrLn ("span: " ++ show (under ++ take 1 over))
```

```bash
lessons/tools/run-in-sandbox.sh lessons/solutions runghc f-takewhile.hs
# takeWhile: [15,26,38]          <- the crossing total, 49, is dropped
# span: [15,26,38,49]            <- kept
```

Negative control: change the limit to `<= 50` and `takeWhile` returns all four totals. **Tag: guaranteed**, since both functions are specified by the Haskell `Prelude`, and your test does not depend on the implementation.

## G. Open challenges

No answers: these are unsolved. If you close one, send it in.
