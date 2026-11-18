# Exercises

Step 5 of every lesson: *now break it yourself*. Each exercise has a goal, a safe way to run it, **acceptance criteria** a student (or their coding agent) can test, and, where practical, a command that tests them. Worked solutions are in the [answers key](answers-key.md). **Every exercise marked "verified" has been run end to end against the real entries**, in Docker or Windows Sandbox, by [`verify-exercises.sh`](tools/verify-exercises.sh) and [`verify-windows.ps1`](tools/verify-windows.ps1); the ones that have not are labeled **open challenge**.

The rhythm for every exercise is **predict, run, compare**. Write your prediction down *before* you run anything. The check only tells you whether you got a result; the prediction tells you whether you understood.

## Running things safely

These programs write files and start processes. Do not run entries you did not read on your own machine. Use the repo's own lockdown; one-time setup is in [`SANDBOX-SETUP.md`](../SANDBOX-SETUP.md) (including `sandbox/container/build-bases.sh`, which you must run once, and again with `--force` if a run says `cobc: not found` or similar: an old toolchain image predates some entries).

| You want to... | Command (from the repo root) | Where it runs |
| --- | --- | --- |
| **See** a Linux entry run | `sandbox/container/run-image.sh <folder>` | Docker: no network, read-only root, user `nobody`, limits, timeout |
| Run an entry's **own check** | `sandbox/run.sh <folder>` | Docker toolchain image, folder copied into a tmpfs |
| Run **any command** in that lockdown, with environment variables | `lessons/tools/run-in-sandbox.sh [-e NAME=VALUE] <folder> <command...>` | same lockdown, on a private copy of the folder |
| Run a **Windows/WPF** entry | `sandbox\windows\run.ps1 <folder>` | Windows Sandbox: a throwaway VM, networking off |

`<folder>` can be any folder, not only one under `src/`. **Work on a copy** so your checkout stays clean:

```bash
WORK=$(mktemp -d)                  # a scratch folder
cp -r src/cobol-weird "$WORK/"     # then edit $WORK/cobol-weird/... and run the commands on that folder
```

(`run-image.sh` names its Docker image after the folder, so keep the folder name.)

Ground rules:

1. **DEMO ONLY data.** Nothing connects to a real time-reporting system, and your exercise must not either.
2. **Break exercises are expected to fail an entry's own `check.sh`.** That is the point: the check proved the constraint was real.
3. **Timeouts are results.** Some breaks run forever. Set `SANDBOX_TIMEOUT=30`; the run then prints `TIMEOUT after 30s` and exits `124`.
4. **Output is random.** Row counts and totals differ on every run. The criteria below are written to hold for *every* run, so do not compare your numbers with the answers key; compare the properties.

### The shared checker

[`lessons/tools/check-demo.sh`](tools/check-demo.sh) validates the *shape* of any entry's output: a `DEMO ONLY` marker, every row's hours in 10-19, every running total equal to the previous total plus the hours, the run stopped on the first card whose total passed the limit (default 40), and the `# committed` (or `# captured`) line agrees with the rows. Exit 0 is PASS.

```bash
sandbox/container/run-image.sh src/cobol-weird > out.txt 2>&1
bash lessons/tools/check-demo.sh out.txt          # PASS: 3 rows, total 46 (limit 40)
bash lessons/tools/check-demo.sh out.txt 50       # the same check against a limit of 50
```

## A. Warm-up: predict, then run

### A1. Read the rows (verified)

**Goal:** tell, from the output alone, which card stopped the run and why that is not off by one.

1. Run three entries from different [languages](languages/README.md) and save each output.
2. For each, write down how many cards there were, which card crossed 40, and what the card *before* it totaled.
3. Run a fourth (try `src/regex-dotnet`, whose rows have no running-total column) and predict its card count before looking.

Acceptance criteria:

- `check-demo.sh` passes for every run.
- For every run, the total before the last card is **at most 40**, and the final total is **over 40**.
- In one sentence: why does a total of *exactly* 40 not stop the run? (Hint: look at the `<= 40` in the stop rules.)

## B. By language

### B1. COBOL: predict, then break ALTER (verified)

**Lesson:** [COBOL / ALTER](languages/cobol.md#alter). **Entry:** a copy of `src/cobol-weird`.

1. **Predict:** the headroom starts at 59 ([`timecards.cob` L44](../src/cobol-weird/timecards.cob#L44)). If it starts at 49 instead, above what total does the run stop?
2. Change `59` to `49`. Run it with `run-image.sh`, then run the entry's own check with `sandbox/run.sh`.
3. **Predict:** what happens if you add `DISPLAY "x"` as a first line inside `NEXT-CARD`?
4. Try it on a fresh copy.

Acceptance criteria:

- Step 2: `check-demo.sh out.txt 50` passes (the new rule is "total passes 50"), and `sandbox/run.sh` **fails** (the entry's own check insists on 40).
- Step 4: the build fails. The compiler message names the problem; record it. Your answer says why `ALTER` needs a paragraph that is *only* a `GO TO`.

### B2. Haskell: break the laziness (verified)

**Lesson:** [Haskell](languages/haskell.md#lazy-io-as-control-flow). **Entry:** a copy of `src/haskell-weird`.

1. **Predict:** replace `entries <- evaluate (length cards)` ([L144](../src/haskell-weird/timecards.hs#L144)) with `let entries = length cards`. What happens?
2. **Predict:** on a fresh copy, remove `unsafeInterleaveIO` from `lazily` by replacing `unsafeInterleaveIO $ case actions of` ([L64](../src/haskell-weird/timecards.hs#L64)) with `id $ case actions of`. What happens, and does it hang?
3. Run each.

Acceptance criteria:

- Change 1: the output contains `handle is closed` and `check-demo.sh` fails. Explain what was demanded *after* the pipe closed.
- Change 2: the program stops with `cyclic evaluation in fixIO` rather than hanging. Explain which value needs which: the list of actions is now forced before the list of cards exists.

### B3. Forth: move the anchor (verified)

**Lesson:** [Forth](languages/forth.md). **Entry:** a copy of `src/forth-weird`.

1. **Predict**, then test each change on a fresh copy:
   - (a) Put `0 0` on its own line before `>in @ step rewind?` ([L101](../src/forth-weird/timecards.fs#L101)).
   - (b) Write the line as `>in @ 0 0 step rewind?` (state *after* the anchor).
   - (c) In `rewind?` ([L92-94](../src/forth-weird/timecards.fs#L92-L94)) change `41 <` to `51 <`.

Acceptance criteria:

- (a) is harmless: `check-demo.sh` passes. Explain why (the anchor is still *after* the `0 0`).
- (b) runs away: use `SANDBOX_TIMEOUT=30`. There is no `# committed` line, many rows appear (hundreds), and every row's running total equals its own hours (the state resets each pass).
- (c) `check-demo.sh out.txt 50` passes.
- In one sentence: why does only (b) break the loop?

### B4. Make: remove the no-op, and override the clock (verified)

**Lesson:** [GNU Make](languages/make-cmake.md#gnu-make). **Entry:** a copy of `src/make-gnu`.

1. **Predict:** delete the trailing `@:` from the recipe line ([`Makefile` L111](../src/make-gnu/Makefile#L111)): change `...,0))@:)` to `...,0)))`. What happens?
2. On the *unmodified* entry, the Makefile already has a `NOW=<epoch>` override. Run `lessons/tools/run-in-sandbox.sh src/make-gnu make NOW=1700000000`.

Acceptance criteria:

- Step 1: the output ends `# committed total=0 entries=0` and `make re-executed itself 0 times`: no card was ever written to be remade, so Make never restarted. Your explanation uses the words "recipe expands to nothing" and "remade".
- Step 2: the rows show the ISO week `2023-W46`, which agrees with `date -u -d @1700000000 +%G-W%V`.

### B5. CMake: mutate the literal (verified)

**Lesson:** [CMake](languages/make-cmake.md#cmake). **Entry:** a copy of `src/cmake`.

1. **Predict:** the stop test is a regex literal of 41 `x`s ([`timecards.cmake` L41](../src/cmake/timecards.cmake#L41)). Shorten it to 31. What is the new stop rule?
2. Run it, then run the entry's own check.

Acceptance criteria:

- `check-demo.sh out.txt 30` passes.
- `sandbox/run.sh` on your copy **fails**. (The repo's own `check.sh` performs this same mutation to prove the literal controls the loop.)
- Explain why the stop test must come *first* in the `while()` condition.

### B6. APL: the off-by-one rewrite (verified)

**Lesson:** [APL, self-modifying functions](languages/apl.md#2-self-modifying-functions-apl-weird). **Entry:** a copy of `src/apl-weird`.

1. **Predict:** change `,5↓⊂[1]` to `,4↓⊂[1]` on [L53](../src/apl-weird/timecards.apl#L53). What does each child keep from its parent?
2. Run it with `SANDBOX_TIMEOUT=40`.
3. On a fresh copy, change `⎕IO←0` ([L17](../src/apl-weird/timecards.apl#L17)) to `⎕IO←1` and run it.

Acceptance criteria:

- Step 2: the run never ends by itself: you get `TIMEOUT after 40s` (exit `124`), or on a machine where the recursion eats memory faster than that, the container is killed for exceeding its memory limit (`Killed`, exit `137`). No `# committed` line either way. Rows appear whose running total equals their own hours: each child keeps its parent's `T←H` line and restarts the total, so the stop rule never fires. Explain why the entry's own `check.sh` runs under `timeout`.
- Step 3: an `INDEX ERROR` is printed and no rows appear. Explain which indexing in the program assumes origin 0.

### B7. LINQ: enumerate twice (verified)

**Lesson:** [C# and LINQ](languages/csharp-linq-xaml.md#deferred-execution-and-the-void-to-value-trick).

1. In a new empty folder, make a console project (`dotnet new console`, target `net10.0`) whose `Program.cs` builds
   `var q = Enumerable.Range(1, 3).Select(i => { Console.WriteLine($"effect {i}"); return i; });`
2. **Predict** how many `effect` lines print after: (a) declaring `q`; (b) one `q.Sum()`; (c) `q.Sum()` *and* `q.ToList()`; (d) `q.ToList()` once, then `.Sum()` on the *list*.
3. Run it (Docker: `lessons/tools/run-in-sandbox.sh -e DOTNET_NOLOGO=1 <folder> dotnet run`; or `dotnet run` on a Windows machine). Print a marker line between the steps so you can count.
4. Add `var r = new Random(42);` and print `r.Next(10, 20)` five times. The XAML entry seeds exactly this generator ([`strict.xaml` L13](../src/xaml/strict.xaml#L13)).

Acceptance criteria:

- (a) 0, (b) 3, (c) 6, (d) 3 `effect` lines. Name the property of `Select` that makes (a) zero and (c) six.
- The five hours for seed 42 are `16 11 11 15 11`. Say why a XAML program seeded with 42 produces the same cards on every run.
- Name the one operator in [`LinqChallenge1/Program.cs`](../src/LinqChallenge1/Program.cs#L45) that is *eager* and forces the lazy stages that follow.

### B8. Regex: what survives a failed match (verified)

**Lessons:** [Regex](languages/regex.md). **Entries:** copies of `src/regex-dotnet` and `src/regex-pcre2grep`.

1. **.NET:** change the end of the pattern on [L13](../src/regex-dotnet/Program.cs#L13) from `)*");` to `)*(?!)");`. Predict what the host can still read.
2. **pcre2grep:** in `timecards.sh`, change the first `(?C{/usr/bin/sqlite3` to `(?C{sqlite3`. Predict what happens.

Acceptance criteria:

- .NET: the output says `match returned: false` and the summary is `total=0 entries=0`; `sandbox/run.sh` on your copy fails. A failed `Match` exposes no captures.
- pcre2grep: **no output at all**, exit code 0, no rows; `check-demo.sh` fails. A callout that cannot be started is indistinguishable from a vetoed branch.
- Write three sentences contrasting what survives a failed match in Perl (`local` unwinds, side effects stay), PCRE2 (the C struct persists) and .NET (nothing).

### B9. sed: watch a computation (verified)

**Lesson:** [GNU sed](languages/regex.md#gnu-sed). **Entry:** `src/regex-sed`.

1. Run `lessons/tools/run-in-sandbox.sh -e TRACE=1 src/regex-sed ./timecards.sh 2> trace.txt`.
2. **Predict** roughly how many state lines the program writes per card.

Acceptance criteria:

- `trace.txt` has many lines containing `tot:`; the last has a `tot:` field of **41 or more** `#` characters.
- Find, in [`timecards.sed`](../src/regex-sed/timecards.sed), the rule that rejects a draw of 10-15 for the 4-bit value ([L29](../src/regex-sed/timecards.sed#L29)) and say what the pattern `1(01|1)` matches.
- The number of state lines per card is *not* constant: say why (rejected draws repeat a step).

### B10. Lisp: swap the method combination (verified)

**Lesson:** [Common Lisp](languages/lisp.md#method-combination-as-control-flow). **Entry:** copies of `src/lisp-weird`.

1. **Predict:** on a copy, replace `or` with `progn` in both places: `(:method-combination or)` ([L61](../src/lisp-weird/timecards.lisp#L61)) and `(defmethod punch or ...)` inside `defcard` ([L39](../src/lisp-weird/timecards.lisp#L39)). `progn` runs *every* method. How many cards will every run print?
2. **Predict**, on a fresh copy: change *only* the generic function's `(:method-combination or)` to `progn` and leave the `or` qualifiers alone.
3. **Predict**, on a fresh copy: change the stop test `(> (total ledger) 40)` ([L84](../src/lisp-weird/timecards.lisp#L84)) to `(> (total ledger) 100)`.
4. Run each with `run-image.sh` (or `lessons/tools/run-in-sandbox.sh <copy> sbcl --script timecards.lisp`).

Acceptance criteria:

- Step 1: **exactly five card rows on every run** (run it five times), and the closing note says `PUNCH had 0 OR methods and 5 ran`. The entry's own `check.sh` **fails** on your copy.
- Step 2: SBCL prints warnings that contain `Invalid qualifiers for PROGN method combination`. Say what the rule is: a method's qualifiers must belong to the combination of its generic function.
- Step 3: **exactly five rows on every run**, a final total of at most 95, and `check-demo.sh out.txt 100` fails with "does not pass 100". Say why five is the most this program can ever deal, and what you would have to change to support a limit of 100.
- In one sentence: which single word is the stop rule, and why does removing it not make the program fail with an error?

### B11. m4: quote the recursion (verified)

**Lesson:** [m4](languages/m4.md#a-loop-made-of-rescanning). **Entry:** copies of `src/m4`.

1. **Predict:** run `lessons/tools/run-in-sandbox.sh src/m4 m4 -Dtc_seed=12345 timecards.m4` twice. What differs between the runs, and what does not?
2. **Predict:** on a copy, remove the brackets around the recursive call: change `[tc_card()]` at the end of `tc_card` ([L82](../src/m4/timecards.m4#L82)) to `tc_card()`. Run it with `SANDBOX_TIMEOUT=20`, then again as `m4 -L 50 -Dtc_seed=7 timecards.m4`. (`-L` limits nesting.)
3. On a fresh copy change `eval(tc_total > 40)` to `eval(tc_total > 60)`.

Acceptance criteria:

- Step 1: the card rows are identical both times (`Meetings 19`, `Coding 13`, `Debugging 16`, with totals 19, 32, 48); only the run id (it contains the clock) can differ. Say why a pinned seed gives the same cards: the generator is a formula, and the program holds no other source of randomness.
- Step 2: without `-L` the run ends in `TIMEOUT after 20s` (exit 124) and prints nothing; with `-L 50` m4 stops with `recursion limit of 50 exceeded`, exits non-zero, and there is no `# committed` line. Explain, in terms of *when m4 expands arguments*, why the brackets are the stop rule.
- Step 3: `check-demo.sh out.txt 60` passes.

### B12. Tcl: edit the program in the database (verified)

**Lesson:** [Tcl](languages/tcl.md#sqlite-as-the-program). **Entry:** copies of `src/tcl-weird`.

1. **Predict:** on a copy, change `PRAGMA recursive_triggers = ON;` ([L55](../src/tcl-weird/timecards.tcl#L55)) to `OFF`. How many card rows will be printed? How many will the summary count?
2. **Predict:** on a fresh copy, change the body of the `hours` row ([L73](../src/tcl-weird/timecards.tcl#L73)) from `expr {10 + int(rand() * 10)}` to `expr {10}`. You are editing *text inside an SQL string*, not a Tcl proc.
3. Run each: `sandbox/container/run-image.sh <copy>`.

Acceptance criteria:

- Step 1: **exactly one card row** is printed and the summary says `entries=2`: the trigger fired once (so card 2 was inserted and counted) but an insert made by a trigger does not fire the trigger again unless recursion is enabled, so card 2 was never printed. `check-demo.sh` fails.
- Step 2: every run prints **exactly five rows**, hours all 10, totals 10, 20, 30, 40, 50, and `check-demo.sh` **passes**. Explain why the run does not stop at 40 (compare the last question of [A1](#a1-read-the-rows-verified)).
- Name the three hooks (an SQL function that calls Tcl, `unknown`, a trigger) and say which one you changed in step 2.

### B13. AWK: the missing RT (verified)

**Lesson:** [AWK](languages/awk.md#2-records-from-a-random-byte-stream-awk-weird). **Entry:** copies of `src/awk-weird`.

1. **Predict:** on a copy, make a digit file `printf '1 2\n' > d.txt` in the copy's folder and run `lessons/tools/run-in-sandbox.sh <copy> gawk -f timecards.awk d.txt`. What are the cards? (Dice: `10 + RT`.)
2. **Predict:** on a fresh copy, delete rule 1, the line `RT == "" { next }` ([L52](../src/awk-weird/timecards.awk#L52)), and run the same command.
3. Run the *unmodified* program under mawk **on the finite file only**: `lessons/tools/run-in-sandbox.sh <copy> mawk -f timecards.awk d.txt`. Do **not** run it under mawk on `/dev/urandom`: it never stops and eats memory until it dies.
4. On a fresh copy change the stop rule `t > 40 { exit }` ([L69](../src/awk-weird/timecards.awk#L69)) to `t > 80 { exit }` and run it on `/dev/urandom` (`run-image.sh`).

Acceptance criteria:

- Step 1: two cards, `Meetings 11 11` and `Coding 12 23`, and `# committed total=23 entries=2`. The trailing newline of the file leaves an empty last record that rule 1 skips.
- Step 2: **three** cards; the third is `Debugging 10 33` and the summary says `entries=3`. Explain why an empty `RT` counted as a 10-hour card (`10 + ""`).
- Step 3: the header and `# committed total=0 entries=0`, no error, exit 0. Explain why: mawk has no `RT`, so `RT == ""` is true for every record and rule 1 skips them all. Say what this teaches about "portable-looking" code, and which [knowledge level](intro.md#three-kinds-of-knowledge) `RT` is.
- Step 4: `check-demo.sh out.txt 80` passes.

### B14. find: rig the dice (verified)

**Lesson:** [find](languages/find.md). **Entry:** a copy of `src/find-posix`.

1. In the copy, make a folder `bin` with an executable script `bin/mktemp` that always names the new directory `xxxxxS`:

   ```sh
   #!/bin/sh
   if [ "$#" -eq 2 ] && [ "$1" = -d ]; then d=${2%XXXXXX}xxxxxS; mkdir "$d" && printf '%s\n' "$d"; else exec /usr/bin/mktemp "$@"; fi
   ```

   Run `lessons/tools/run-in-sandbox.sh <copy> sh -c 'PATH=$PWD/bin:$PATH sh ./timecards.sh'`. **Predict** the rows first. (The dice use the *last* character; `S` is in the group `STUVWX`, which is the tenth group.)
2. Change the name in the script to `xxxxxY` and run it again. **Predict:** `Y` is thrown away.
3. Change the name to `xxxxYZ` and run it again. **Predict:** both of the last two characters are thrown away.

Acceptance criteria:

- Step 1: three cards, `Meetings 19 19`, `Coding 19 38`, `Debugging 19 57`, and `# committed total=57 entries=3`. Every die shows the same group, so every card has 19 hours.
- Step 2: the walk reads the character before the `Y`. That is `x`, in the group `stuvwx`, the fourth group, so every card has 13 hours: `13 13`, `26`, `39`, `52`. Four cards, and the 39 *continues*, because 39 is not over 40. Explain why the stop rule needs a fourth card here.
- Step 3: both characters are thrown away, so the hours are 10. Five cards: totals 10, 20, 30, 40, 50. The 40 continues (exactly 40 is not over 40), and the fifth card is `Meetings` again, because there are only four categories.

### B15. GNU find: move the stop rule, read the profile (verified)

**Lesson:** [find](languages/find.md). **Entry:** copies of `src/find-gnu`.

1. **Predict:** in a copy, change the stop test in `timecards.sh`, `-regex '([^/]*/){41}.*'`, to `{31}`. What is the new stop rule? Run it with `sandbox/container/run-image.sh`, then run the entry's own `check.sh` (`sandbox/run.sh <copy>`).
2. On a *fresh* copy, run `lessons/tools/run-in-sandbox.sh -e FIND_D=rates <copy> sh ./timecards.sh`. Look at standard error.

Acceptance criteria:

- Step 1: the new rule is "stop once the path has 31 or more slashes", which is "the total is over 30". `check-demo.sh out.txt 30` passes. The entry's own `check.sh` **fails**: its forced-dice scenarios expect cards that no longer get made. Explain why changing one number in a regular expression is enough to change the stop rule.
- Step 2: find prints, for every test in the program, a line like `[real success rate 1/94=0.01064]`. You can say how many times the `-name b00` test succeeded (once per card), and you can say why find's own guess (`est success rate`) for the `-regex` tests is so far off.

### B16. tar: read the program, then run it (verified)

**Lesson:** [tar](languages/tar.md). **Entry:** a copy of `src/tar-gnu`.

1. In the copy, write an archive with fixed hours and read it without running it: `sh build-archive.sh --seed 1 --hours "12 12 12 12 12" a.tar`, then `sh inspect.sh a.tar`. **Predict** how many cards will run, and which of the five card slots will be read and ignored. Then run it: `sh interpret.sh --execute a.tar`.
2. Take the program apart with plain tar: `mkdir x && tar -C x -xf a.tar`. Open `x/021.stop-over` and change `limit=40` to `limit=20`. Pack it again **in the same order**: `tar --format=ustar -cf b.tar -C x 000.begin 010.card 011.stop-over 020.card 021.stop-over 030.card 031.stop-over 040.card 041.stop-over 050.card 051.stop-over 990.show`. **Predict** the rows, then run `b.tar`. Delete the old database first (`rm "$XDG_DATA_HOME/TarGnu/demo-timecards.db"`), so only this run is in it. Run it with the `trace` table in view: `sqlite3 "$XDG_DATA_HOME/TarGnu/demo-timecards.db" 'select * from trace'`.
3. Add a member that is not in the instruction set: `printf 'touch pwned\n' > x/025.exec`, pack `x` again with `025.exec` after `021.stop-over`, and run `sh inspect.sh c.tar; echo $?`, then `sh interpret.sh --execute c.tar; echo $?`. **Predict** both exit statuses, and whether a file called `pwned` appears.

Acceptance criteria:

- Step 1: four cards (`Meetings 12 12`, `Coding 12 24`, `Debugging 12 36`, `Learning 12 48`), and the fifth slot is read and ignored. `check-demo.sh` passes.
- Step 2: two cards (`Meetings 12 12`, `Coding 12 24`). The limit is in the archive, so changing a member changed the stop rule, and `dispatch.sh` did not change. The trace shows `ok` for the first two cards and `ignored: halted` for the rest. `check-demo.sh out.txt 20` passes.
- Step 3: the inspector prints the line `REFUSE (unknown record type)` and exits 4. `interpret.sh` exits 4 and says that nothing was run. No `pwned` file exists. Explain why plain `tar -xf` of the same archive would also not create it.
- In one sentence each: which step *parsed* the program, which step *ran* it, and where was the trust boundary?

### B17. tar, weirder: predict the clock (verified)

**Lesson:** [tar](languages/tar.md#the-archive-is-the-clock). **Entry:** a copy of `src/tar-gnu-weird`.

For seed 42 the cards are `Meetings 12`, `Coding 17`, `Debugging 17`, so the total reaches 12, 29 and 46 hours. The run needs 46 ticks.

1. **Predict**, then run: `sh run-clock.sh --seed 42 --ticks 45`, and then `--ticks 46`. Look at the exit status of each (`echo $?`).
2. **Predict** how many ticks you get from `sh run-clock.sh --seed 42 --ticks 92 --interval 2`, and from `--ticks 91 --interval 2`. Then run both.
3. **Predict** the output of `sh run-clock.sh --seed 42 --ticks 260 --blocking 4`. How many records does tar write?
4. Open the tape of the last run (`tr -d '\000' < tape.tar | wc -c` counts the bytes that are not zero). What is in it, and does the content matter?

Acceptance criteria:

- Step 1: with 45 ticks the third card is not finished, so you see two cards, the message `the clock ran out`, and exit status 3. With 46 ticks the run ends with three cards and exit status 0.
- Step 2: with `--interval 2` the callback runs once per two records. 92 records give 46 ticks, so the run finishes. 91 records give 45 ticks, so it stalls. The last `TAR_CHECKPOINT` in the finished run is 92, which is the number of records, and the machine counted 46 calls.
- Step 3: `-b 4` makes a record four blocks. 260 blocks make 65 records and 65 ticks. The run finishes with the same three cards, and 19 ticks are idle.
- Step 4: Almost all of `tape.tar` is zeros. The only other bytes are the member's 512-byte header (its name, mode and so on), fewer than 100 of them. The payload does not matter. Its *size* is the clock.

### B18. ed: move the stop rule and break the cleanup (verified)

**Lesson:** [ed and Ex](languages/editors.md#the-buffer-is-the-machine). **Entry:** a copy of `src/ed-weird`.

The launcher takes `DICE="a b c d e"`: five digits. Each card has 10 + its digit hours.

1. **Predict**, then run: `DICE="0 0 0 0 0" sh timecards.sh`, and `DICE="9 9 9 9 9" sh timecards.sh`. How many cards will each print, and why is the fifth card of the first one `Meetings` again?
2. In the copy, change `x\{41,\}` in `timecards.ed` to `x\{31,\}`. **Predict** the rows for `DICE="3 3 3 3 3"` before and after the change. Then run both.
3. Delete the line `g/^Dead /d` from `timecards.ed`. Run the ed program on its own: `printf '3\n3\n3\n3\n3\n' > d.txt; ed -s d.txt < timecards.ed`. **Predict** the extra line.

Acceptance criteria:

- Step 1: all ten-hour cards give five cards with totals 10, 20, 30, 40, 50 (a total of exactly 40 does not stop the run, and there are only four categories, so the fifth is `Meetings` again). All 19-hour cards give three cards: 19, 38, 57.
- Step 2: before the change, `13 13 13 13 13` give four cards (13, 26, 39, 52). After it, three cards (13, 26, 39): the run now stops after the first total over 30. `check-demo.sh out.txt 30` passes. One number in a regular expression moved the stop rule.
- Step 3: the output ends with an extra line `Dead 0 52`. It is the fifth card, which was turned into a dead card because the total had passed 40 at card 4. The `Dead` rule is the one that stops cards from counting; the cleanup only hides them.
- In one sentence: which ed feature made each of the three changes possible?

### B19. Ex: move the limit on the tape and cut the loop (verified)

**Lesson:** [ed and Ex](languages/editors.md#a-program-you-can-edit). **Entry:** a copy of `src/ex-weird`.

The launcher takes `DICE="a b c d e"`: five digits. Each card has 10 + its digit hours.

1. **Predict**, then run: `DICE="1 1 1 1 1" sh timecards.sh`. How many cards, and what are the totals?
2. In the copy, make the tape say "go on" up to 45 instead of 40: `sed -i 's/^\(4[1-5]\) "$/\1 @a/' timecards.ex`. **Predict** the rows for the same dice, then run them.
3. Take the loop out: `sed -i 's/|@n$//' timecards.ex`. **Predict** how many cards run, then run it with `DICE="5 5 5 5 5"`.
4. Look at the end of the program line in `timecards.ex`. Which command is the loop, and which line of the tape makes it stop?

Acceptance criteria:

- Step 1: four cards, 11, 22, 33 and 44. The total passes 40 at the fourth card, so the tape row `44` is the first "stop" instruction that the program reads, and the run ends there. `check-demo.sh` passes.
- Step 2: five cards, 11, 22, 33, 44 and 55. Row 44 now says `@a`, so the run goes on, and row 55 still says `"`. `check-demo.sh out.txt 45` passes. The program did not change: only a line of data did.
- Step 3: one card. The program runs once and never starts itself again, because nothing runs register `n` any more. With `DICE="5 5 5 5 5"` the row is `Meetings 15 15`.
- Step 4: `@n` is the loop, and register `n` holds the instruction from the tape line. The line that stops it is the first one whose instruction is `"`, which is the one for a total of 41.

### B20. JavaScript: read the clauses, move the limit and fail the structure check (verified)

**Lesson:** [JavaScript](languages/javascript.md#the-bodiless-for-in-node). **Entry:** a copy of `src/javascript`.

1. **Predict**, then run: `SEED=42 node timecards.mjs`. Which card crosses 40? (The generator is Park-Miller, and the hours of the first three cards for this seed are 12, 17 and 17.)
2. In the copy, change `<= 40` in the condition to `<= 20`. **Predict** the rows for `SEED=42`, then run them.
3. Put a statement in the loop body: replace `{ /* Intentionally empty. */ }` with `{ i.frames++; }`. Run `node timecards.mjs`, then `node check-structure.mjs timecards.mjs`.
4. Run `NOW=2026-12-31 SEED=42 node timecards.mjs` and `NOW=2024-12-30 SEED=42 node timecards.mjs`. **Predict** the week column.

Acceptance criteria:

- Step 1: three cards, `Meetings 12 12`, `Coding 17 29`, `Debugging 17 46`, and the third card crosses 40. `check-demo.sh` passes.
- Step 2: two cards, 12 and 29. The condition is evaluated after the iterator has added a card, so the card that takes the total from 12 to 29 is saved, and then the test (29 is over 20) ends the loop. `check-demo.sh out.txt 20` passes.
- Step 3: the program still runs and prints the same cards (the extra statement changes a counter that nothing reads), and the structure check **fails** with a message about the body. The constraint was a rule you broke, and the check is the proof that it was real.
- Step 4: `2026-W53` and `2025-W01`. The week is the ISO week, and the year printed is the ISO year, which can differ from the calendar year at New Year.

### B21. JavaScript, weirder: move the stop rule in a closure and watch the demand (verified)

**Lesson:** [JavaScript](languages/javascript.md#closures-all-the-way-down). **Entry:** a copy of `src/javascript-weird`.

1. Run the closure lab on the untouched copy: `node --expose-gc --test check.mjs`. How many tests pass?
2. In `core.mjs`, change the stop rule `over = total > 40` to `over = total > 20`. **Predict** the rows for `SEED=42 node timecards.mjs` (the hours of the first cards are 12, 17 and 17). Then run the lab again. **Predict** whether it passes.
3. Run this, and **predict** what it prints, and in what order:

   ```bash
   node --input-type=module -e "
   import { cards, machine } from './core.mjs';
   const m = machine(() => (console.log('drawn'), 15));
   const p = Iterator.from(cards(m)).map(c => c.total);
   console.log('built');
   console.log(p.take(1).toArray());"
   ```
4. In the same command, change `take(1)` to `take(2)`. How many `drawn` lines do you get?

Acceptance criteria:

- Step 1: all 12 tests pass.
- Step 2: two cards (`Meetings 12 12`, `Coding 17 29`): the machine says `over` as soon as the total passes 20. The lab does **not** pass: 7 of the 12 tests fail, and they are the ones that pin the stop rule (the crossing card, exactly 40, the draw counts, the replay of seed 42). The 5 that pass are about closures and do not care about the limit. In one sentence: why do the closure tests not care?
- Step 3: `built`, then `drawn`, then `[ 15 ]`. Building the pipeline draws nothing. `take(1)` asks for one card, so one hours value is drawn.
- Step 4: two `drawn` lines (and `[ 15, 30 ]`). The consumer decides how many cards exist.

## C. By solution pattern

### C1. Weird next to boring (verified)

**Lesson:** [Weird next to boring](intro.md#weird-next-to-boring). The repo has many ready-made pairs, among them `cobol`/`cobol-weird`, `haskell`/`haskell-weird`, `forth`/`forth-weird`, `apl`/`apl-weird`, `lisp`/`lisp-weird`, `tcl`/`tcl-weird`, `awk`/`awk-weird`, `tar-gnu`/`tar-gnu-weird`, `ed-weird`/`ex-weird` and `javascript`/`javascript-weird`.

Compare one pair. Run both, and count code lines (not comments) in each program.

Acceptance criteria:

- Both outputs pass `check-demo.sh`.
- A small table compares line count, what you could unit-test, what a debugger would show, and one thing only the weird version can do.
- You answer the recurring question: *under what circumstances would the weird one be the right choice?*

### C2. Make the constraint real (verified)

**Lesson:** [patterns](patterns.md). Every entry ships a `check.sh` that proves its rule (for example [`cobol-weird/check.sh`](../src/cobol-weird/check.sh) greps for banned words and counts `ALTER`s).

Write a check for `src/forth-weird`'s rule: *no loop or branch words, no variables, and `>in @` is read at least twice.*

Acceptance criteria:

- Your check passes on the unmodified `timecards.fs`.
- It fails for each of three mutations (add a `begin`; add a `variable`; remove the `>in @`s). Show the three commands.
- A banned word inside a `\` comment or a `." string"` does **not** trigger it (so you must strip comments and strings first).

### C3. A loop whose state is not a variable (verified)

**Lesson:** [Control state outside variables](patterns.md#control-state-outside-variables).

In awk, with **no** `for`, `while`, `do`, `function`, recursion or `goto`, print the numbers 1 to N for N chosen by the *caller*. (Where can the loop's state live if not in your code?)

Acceptance criteria:

- Output is `1` through `N` for N in 1, 3 and 10, run through the sandbox: `seq N | lessons/tools/run-in-sandbox.sh <folder> bash -c "awk '...'"`.
- A `grep -Ew 'for|while|do|function|goto'` of your awk source finds nothing.
- State which [knowledge level](intro.md#three-kinds-of-knowledge) your trick leans on.

## D. Port the challenge (verified: reference answer in awk)

**Goal:** implement the shared demo in a language not yet in the repo (Lua, Ruby, Prolog, a SQL recursive CTE, PowerShell, Scheme, Perl...). The repo has since gained Common Lisp, m4, Tcl and awk entries, so those are no longer open under the rules of [`CHALLENGE.md`](../CHALLENGE.md), and run it only in the sandbox.

Acceptance criteria:

1. `check-demo.sh` passes on **25 consecutive runs**. Over those runs, at least five distinct hour values appear.
2. Output has a `DEMO ONLY` marker and a `# committed total=N entries=M` line that matches the rows.
3. The stop rule is a property of your trick, not a helper called `RunEverything()`.
4. The data lives in a local SQLite file whose schema refuses a non-demo row (`CHECK(demo_only = 1)`), and your check proves it by trying to insert one.
5. A `Dockerfile` that passes [`sandbox/dockerfile-lint.sh`](../sandbox/dockerfile-lint.sh) and runs with `run-image.sh`.
6. A `check.sh` that enforces your constraint (see C2), a README with **How the stunt works** and honest **walls**.

```bash
for i in $(seq 25); do
  sandbox/container/run-image.sh <your-folder> > out.txt 2>&1 || { echo "run $i failed"; break; }
  bash lessons/tools/check-demo.sh out.txt || { echo "run $i bad"; break; }
done
```

See [`CONTRIBUTING.md`](../CONTRIBUTING.md) if you want to send it in. A reference answer lives in [`lessons/solutions/awk-port`](solutions/awk-port) (see the [answers key](answers-key.md#d-port-the-challenge)); try yours first. It was written before awk was in the repo and is a short third design (the caller pipes in five records and a pattern is the stop rule), distinct from [`src/awk`](../src/awk/README.md) (a `BEGIN` loop) and [`src/awk-weird`](../src/awk-weird/README.md) (gawk and `RS`/`RT`): compare all three.

## E. Windows Sandbox track (verified on Windows 11 Pro)

For the WPF entries. Needs Windows Sandbox and a local .NET 10 SDK ([setup](../SANDBOX-SETUP.md#windows-sandbox)); build each entry once on the host first so its NuGet packages are cached. Only one sandbox can run at a time.

### E1. Run and read the evidence

```powershell
sandbox\windows\run.ps1 src\LinqChallenge1
sandbox\windows\run.ps1 src\xaml -RunArgs strict.xaml
```

Acceptance criteria:

- Each run ends with a `PASS ...` line. The log shows `network: blocked`, so the VM really had no network.
- `LinqChallenge1` reports one run persisted **exactly 40.0h across 5 fixed rows** (its `check.ps1` expects this), and a `screenshot.png` is written.
- `xaml` reports it wrote `xaml-demo-timecards.xml` and that the window was closed by the harness.
- Name one entry whose rows total exactly 40 because the data is fixed, and one whose rows are random.

### E2. Change the XAML interpreter's seed

Work on a copy of `src\xaml`. In `strict.xaml`, the variable is the `Random` created on [L13](../src/xaml/strict.xaml#L13): `<x:Arguments><sys:Int32>42</sys:Int32></x:Arguments>`.

1. Change `42` to `7` and run `sandbox\windows\run.ps1 <your copy> -RunArgs strict.xaml`.
2. **Predict:** do the hours change? Using the console project from B7, compute the first five hours for seeds 42 and 7.

Acceptance criteria:

- The sandbox run still passes with the new seed.
- Your B7 program prints different hour sequences for 42 and 7 and the *same* sequence on every run of the same seed.
- Explain why the loop in these `.xaml` files had to be unrolled four times, and which elements play the part of "the variable".

## F. Prove a README claim (verified)

Every README has a "Gotchas" or "Walls" section. Pick **one claim** and write a test that would fail if it were false. A worked example is in the [answers key](answers-key.md#f-prove-a-readme-claim): "`takeWhile` is not enough" ([`src/haskell/README.md`](../src/haskell/README.md#gotchas-worth-knowing)).

Other good claims: "`SYSTEM` returns the raw wait status (exit 3 comes back as 768)", "GnuCOBOL warns five times about `ALTER`", "pcre2grep does not search `PATH`".

Acceptance criteria:

- The test runs in the sandbox and **passes** against current behavior.
- You also show it **fails** under a deliberate change (a negative control).
- You say whether the claim is **guaranteed**, **implementation-permitted** or **accidentally exploited**, and cite the evidence.

### F2. Trojan Source: hide a character, then find it (verified)

**Lesson:** [Trojan Source](cs/01-reading-an-adversarial-program.md#trojan-source-characters-you-cannot-see). **Entry:** none. No entry in this repository may contain an invisible character, so you make the file yourself, in a scratch folder, and you never commit it. The claim to prove is the one in [`CONTRIBUTING.md`](../CONTRIBUTING.md): "no invisible or direction-changing Unicode characters. APL glyphs and other visible Unicode are fine."

1. In a scratch folder, make a program with a zero-width space (U+200B) after `admin` in the first line:

   ```bash
   printf 'const user = "admin\xe2\x80\x8b";\nconsole.log(user === "admin");\n' > greet.js
   ```

   Look at it with `cat greet.js`. **Predict** what `node greet.js` prints, then run it (for example with `lessons/tools/run-in-sandbox.sh <folder> node greet.js`).
2. Find the character the way the gate does: `LC_ALL=C.UTF-8 grep -nP '[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{2064}\x{2066}-\x{2069}\x{FEFF}\x{00AD}\x{2028}\x{2029}]' greet.js`. Then look at the bytes: `od -c greet.js | head`.
3. **Negative control.** Make the same file without the character (`printf 'const user = "admin";\nconsole.log(user === "admin");\n' > clean.js`). Run the scan on it, and run it with `node`.
4. **The other half of the claim.** Run the same scan over `src/apl-weird` (its source is full of visible APL glyphs): `LC_ALL=C.UTF-8 grep -rlP '<the class above>' src/apl-weird`. **Predict** what it finds.

Acceptance criteria:

- Step 1: the file looks like a program that prints `true`, and it prints `false`. The string has five characters that you can see (`a d m i n`) and one that you cannot, so it is not equal to `admin`.
- Step 2: the scan prints line 1 of `greet.js`, and `od` shows the three bytes `342 200 213` after `admin`.
- Step 3: the scan finds nothing in `clean.js`, and the program prints `true`. This is the negative control: the scan fires on the hidden character, and on nothing else.
- Step 4: the scan finds **no file** in `src/apl-weird`. Visible Unicode (`⍴`, `⍳`, `⎕`) is not in the class, so a reviewer can read it and the gate lets it through. Say in one sentence why banning all non-ASCII text would be the wrong defense.
- Say whether the claim is **guaranteed**, **implementation-permitted** or **accidentally exploited**, and cite the evidence. (Hint: the gate's rule is written down in `sandbox/scope-check.sh`, and `grep -P` with a character class is its mechanism. The class lists only the characters we know of.)

## G. Open challenges (not verified; may be impossible)

These are the gaps from [blocking problems](blocking-problems.md). **Nobody has shown they can be closed**, and there is no answer key. That is the point: a well-documented wall is a good result ([`CHALLENGE.md`](../CHALLENGE.md)). If you solve one, send it in; if you cannot, write up exactly where it breaks.

| Blocker | Task | Success looks like |
| --- | --- | --- |
| LINQ draws no random hours | Replace the fixed work week with random 10-19 hour draws, still **one statement** | `check.ps1` still passes its one-statement rules; hours vary between runs |
| `regex-dotnet` cannot fail on purpose | Make the match fail while the host still obtains the rows | Same rows as the unmodified version; you explain how the captures survived |
| `regex-dotnet` has no side effects | Produce a pulse or a write during the match without `Replace`, `Matches`, `NextMatch` or a host loop | Pulse visible; the entry's `check.sh` banned-API list still passes |
| `cmake` outputs only after the loop | Print one row from *inside* the `while()` condition | One row per pass before the loop ends, with the no-body rule still passing |
| Make needs a shell | Replace `mkdir -p`, `sqlite3` or `rm` with something Make-native for **one** of them | Output unchanged; the shell-program list in `check.sh` shrinks by one |
| Only some entries use threads | Add a worker thread to a script entry | Rows are written from the thread, main only waits; `check-demo.sh` passes |
| `sed`'s RNG is a toy | Replace the 16-bit LFSR with a 32-bit one | Over 25 runs more than 16 distinct first draws appear; `check.sh` passes |
| `awk-weird` needs gawk | Get a die roll without `RT` so it also runs under mawk | Same shape of output under gawk **and** mawk; no `rand`, `srand`, loop or `if`; `check.sh` passes under both |
| `m4` needs a shell for its seed and week | Produce the seed and the ISO week without `esyscmd` | The seed differs between runs and the week is right, with only m4 builtins; if you cannot, write down exactly what m4 cannot reach |
| `lisp-weird` is SBCL-only | Run it on a second Common Lisp (ECL or CCL) changing only the implementation-specific calls | Same output and the same `or`/`progn` proof on both; list the lines you changed |
| `find-posix` was never run on BSD | Run `src/find-posix/check.sh` on a BSD or macOS `find` | Either `check.sh` passes, or you list exactly which primary, `{}` use or utility failed and what each BSD does instead |
