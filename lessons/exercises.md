# Exercises

Step 5 of every lesson: *now break it yourself*. Each exercise has a goal, a way to run it **safely**, **acceptance criteria** a student (or their coding agent) can test, and a check script where one is practical.

The rhythm for every exercise is **predict, run, compare**. Write your prediction down *before* you run anything. The check script only tells you whether you got a result; the prediction tells you whether you understood.

## Running things safely

These programs write files, start processes and (some) run callouts. Do not run entries you did not read on your own machine. Use the repo's own lockdown; one-time setup is in [`SANDBOX-SETUP.md`](../SANDBOX-SETUP.md).

| You want to... | Command (from the repo root) | Where it runs |
| --- | --- | --- |
| **See** a Linux entry run | `sandbox/container/run-image.sh src/<entry>` | Docker: no network, read-only root, user `nobody`, resource limits, timeout |
| See it animate | `sandbox/container/run-image.sh --tty src/<entry>` | same, with a terminal |
| Run an entry's **own check** | `sandbox/run.sh src/<entry>` | Docker toolchain image; the folder is copied into a tmpfs, so **your edits are used and your checkout is untouched** |
| Run a **Windows/WPF** entry | `sandbox\windows\run.ps1 src\<entry>` | Windows Sandbox: a throwaway Hyper-V VM, networking off |
| Keep what it wrote | add `--out ./results` to `run-image.sh` | a folder you name |

Rules for every exercise:

1. **Edit a copy or a branch.** Never edit in place on `master`. `git switch -c exercise-<name>` and `git restore .` afterward.
2. **DEMO ONLY data.** Nothing connects to a real time-reporting system, and your exercise must not either.
3. **Break exercises are expected to fail the entry's own `check.sh`.** That is the *point*: a failing `check.sh` shows the constraint was real. Write the expected failure in your prediction.
4. **Timeouts are results.** Several breaks make a program run forever. Run those with `SANDBOX_TIMEOUT=30` and treat exit code `124` as the outcome.

### The shared checker

Save this as `check-demo.sh` (it is not committed to the repo). It validates the *shape* of any entry's output: **DEMO ONLY** marker, hours in 10-19, running totals add up, the stop rule fired on the right card, and the `# committed` line agrees with the rows. Most acceptance criteria below reuse it.

```bash
#!/usr/bin/env bash
# usage: check-demo.sh output.txt [limit=40]
f=${1:?output file}; limit=${2:-40}
fail() { echo "FAIL: $*"; exit 1; }
grep -q 'DEMO ONLY' "$f" || fail "no DEMO ONLY marker"
mapfile -t rows < <(grep -E $'^(Meetings|Coding|Debugging|Learning)\t[0-9]+\t[0-9]+\t' "$f")
(( ${#rows[@]} >= 1 )) || fail "no timecard rows"
prev=0; before_last=0
for r in "${rows[@]}"; do
  IFS=$'\t' read -r cat hrs tot _ <<<"$r"
  (( hrs >= 10 && hrs <= 19 )) || fail "hours out of 10-19: $r"
  (( tot == prev + hrs ))      || fail "running total wrong: $r"
  before_last=$prev; prev=$tot
done
(( prev > limit ))        || fail "final total $prev does not pass $limit"
(( before_last <= limit )) || fail "stopped late: total was already over $limit before the last card"
c=$(sed -nE 's/^# committed total=([0-9]+) entries=([0-9]+).*/\1 \2/p' "$f")
[[ $c == "$prev ${#rows[@]}" ]] || fail "committed line ('$c') disagrees with the rows"
echo "PASS: ${#rows[@]} rows, total $prev"
```

Use it like this:

```bash
sandbox/container/run-image.sh src/cobol-weird > out.txt 2>&1
bash check-demo.sh out.txt          # PASS: 3 rows, total 54
```

## A. Warm-up: predict, then run

### A1. Read the rows

**Goal:** be able to tell, from the output alone, which card stopped the run and why it is not off by one.

1. Run any three entries from different [languages](languages/README.md).
2. For each, write down: how many cards, which card crossed 40, and what the card *before* it totaled.
3. Run a fourth entry and predict its row count before looking at the output.

Acceptance criteria:

- For each run, your notes name the crossing card and the previous total, and the previous total is **at most 40**.
- `check-demo.sh` passes for all runs.
- Explain, in one sentence, why exactly 40 does *not* stop the run. (Four 10-hour cards total 40 and a fifth is drawn.)

## B. By language

### COBOL: predict, then break ALTER

**Lesson:** [COBOL / ALTER](languages/cobol.md#alter). **Entry:** `src/cobol-weird`.

1. **Predict:** the headroom starts at 59 ([`timecards.cob` L44](../src/cobol-weird/timecards.cob#L44)). If you change it to 49, what total does the run stop above?
2. Change `59` to `49` on a branch. Run it.
3. **Predict:** what does the compiler do if you add a `DISPLAY "x"` line inside `NEXT-CARD`?
4. Try it. Restore the file.

Acceptance criteria:

- Step 2: `check-demo.sh out.txt 50` passes (the new rule is "total passes 50").
- Step 2: `sandbox/run.sh src/cobol-weird` **fails** (its own check insists on 40), and you can say which assertion.
- Step 4: the compile fails or the `ALTER` is rejected. Record the compiler's message; your answer explains why `ALTER` needs a one-`GO TO` paragraph.
- All five `ALTER` statements are still present (the repo's `check.sh` counts them with comments and string literals stripped).

```bash
sed -i 's/WS-HEADROOM *PIC 99 VALUE 59/WS-HEADROOM                PIC 99 VALUE 49/' src/cobol-weird/timecards.cob
sandbox/container/run-image.sh src/cobol-weird > out.txt 2>&1 && bash check-demo.sh out.txt 50
sandbox/run.sh src/cobol-weird; echo "check exit: $? (expect non-zero)"
git restore src/cobol-weird/timecards.cob
```

### Haskell: break the laziness

**Lesson:** [Haskell](languages/haskell.md#lazy-io-as-control-flow). **Entry:** `src/haskell-weird`.

1. **Predict:** what happens if `entries <- evaluate (length cards)` ([L144](../src/haskell-weird/timecards.hs#L144)) is replaced with `let entries = length cards`?
2. **Predict:** what happens if `unsafeInterleaveIO $` is removed from `lazily` ([L64](../src/haskell-weird/timecards.hs#L64))?
3. Make each change on its own, run, restore.

Acceptance criteria:

- Change 1: output contains `handle is closed` (the README documents this failure), and `check-demo.sh` **fails**.
- Change 2: the program never finishes (exit `124` under `SANDBOX_TIMEOUT=30`) because the effects run over an infinite list first.
- You explain why "when is it demanded?" is part of the program's meaning.

```bash
SANDBOX_TIMEOUT=30 sandbox/container/run-image.sh src/haskell-weird > out.txt 2>&1; echo "exit $?"
grep -q 'handle is closed' out.txt && echo "reproduced the lazy-let bug"
```

### Forth: move the anchor

**Lesson:** [Forth](languages/forth.md). **Entry:** `src/forth-weird`.

1. **Predict:** if you move `0 0` onto the line *before* `>in @ step rewind?` ([L101](../src/forth-weird/timecards.fs#L101)), what changes?
2. Make the change and run it under a timeout.
3. Restore. Then change `41 <` in `rewind?` to `51 <` (find it near [L92-94](../src/forth-weird/timecards.fs#L92-L94)) and run again.

Acceptance criteria:

- Step 2: the run does not terminate normally (exit `124`), because the state is reset on every pass.
- Step 3: `check-demo.sh out.txt 50` passes.
- You can say why the loop works only on a single input line.

### Make: remove the no-op

**Lesson:** [GNU Make](languages/make-cmake.md#gnu-make). **Entry:** `src/make-gnu`.

1. **Predict:** what if the trailing `@:` on the recipe ([`Makefile` L111](../src/make-gnu/Makefile#L111)) is deleted?
2. Make the change, run, restore.

Acceptance criteria:

- The run no longer produces a normal sequence of cards: either no restart happens or fewer than three card rows appear, so `check-demo.sh` **fails**.
- Your explanation uses the words "recipe expands to nothing" and "remade".
- Clean up the leftover state with `make clean` inside the container's copy (the check runs in a throwaway tmpfs, so your checkout is not touched).

```bash
sed -i 's/)@:)$/))/' src/make-gnu/Makefile    # adjust to match the line you actually see
sandbox/run.sh src/make-gnu; echo "exit $? (expect non-zero)"
git restore src/make-gnu/Makefile
```

### CMake: mutate the literal

**Lesson:** [CMake](languages/make-cmake.md#cmake). **Entry:** `src/cmake`.

1. **Predict:** shorten the 41-`x` literal in the stop test ([`timecards.cmake` L41](../src/cmake/timecards.cmake#L41)) to 31 `x`s. What is the new stop rule?
2. Run it.

Acceptance criteria:

- `check-demo.sh out.txt 30` passes.
- `sandbox/run.sh src/cmake` fails (its check expects 40). The repo's own `check.sh` performs exactly this mutation to prove the literal is what controls the loop.
- You explain why the stop test must come *first* in the condition.

### APL: the off-by-one rewrite

**Lesson:** [APL, self-modifying functions](languages/apl.md#2-self-modifying-functions-apl-weird). **Entry:** `src/apl-weird`.

1. **Predict:** change `5↓` to `4↓` on [L53](../src/apl-weird/timecards.apl#L53). What does each child keep from its parent?
2. Run it under a timeout.

Acceptance criteria:

- The run does not terminate (exit `124` under `SANDBOX_TIMEOUT=30`): each child keeps its parent's `T←H` gene, resets the total to one card, and the stop rule never fires.
- You explain why the entry's own `check.sh` runs under `timeout`.
- Restore, then change `⎕IO←0` to `⎕IO←1` ([L17](../src/apl-weird/timecards.apl#L17)) and say what breaks and why (the weird version relies on `⎕IO←0`).

### LINQ: enumerate twice

**Lesson:** [C# and LINQ](languages/csharp-linq-xaml.md#deferred-execution-and-the-void-to-value-trick). Run on **Windows**, in a scratch project, not in the repo.

1. Write a console program that builds `var q = Enumerable.Range(1, 3).Select(i => { Console.WriteLine($"effect {i}"); return i; });`.
2. **Predict** how many `effect` lines print after (a) declaring `q`, (b) `q.Sum()`, (c) `q.Sum()` and `q.ToList()` together, (d) `q.ToList()` once, then summing the list.
3. Run it. Then run the real thing: `sandbox\windows\run.ps1 src\LinqChallenge1`.

Acceptance criteria:

- Observed: (a) 0 lines, (b) 3, (c) 6, (d) 3. A line count script:

```powershell
$o = dotnet run | Out-String
([regex]::Matches($o, 'effect \d')).Count   # compare with your prediction per step
```

- The `LinqChallenge1` run reports `PERSISTED 5 rows, total=40.0h` (its `check.ps1` expects this) and a screenshot is produced.
- You point to the exact operator in [`LinqChallenge1/Program.cs`](../src/LinqChallenge1/Program.cs#L45) that makes the lazy tail run, and name it eager (`Aggregate`).

### Regex: what survives a failed match

**Lessons:** [Regex](languages/regex.md). Entries: `regex-dotnet`, `regex-pcre2grep`.

1. **.NET:** append `(?!)` to the pattern ([`Program.cs` L13](../src/regex-dotnet/Program.cs#L13)). Predict what `Match` exposes.
2. **pcre2grep:** replace one absolute callout path (e.g. `/usr/bin/sqlite3`) with the bare name `sqlite3` in [`timecards.sh`](../src/regex-pcre2grep/timecards.sh). Predict what happens.
3. Run each; restore.

Acceptance criteria:

- .NET: the run produces **no** time-card rows (the captures vanish with a failed match), and `sandbox/run.sh src/regex-dotnet` fails.
- pcre2grep: no rows are written, and nothing says why. The failed callout looks the same as a vetoed branch. `sandbox/run.sh src/regex-pcre2grep` fails.
- Your write-up contrasts three engines: what survives a failed match in Perl (`local` unwinds, side effects stay), PCRE2 (C struct persists), .NET (nothing survives).

### sed: watch a computation

**Lesson:** [GNU sed](languages/regex.md#gnu-sed). **Entry:** `src/regex-sed`.

1. Run `TRACE=1 ./timecards.sh` through the container with `--tty` removed, capturing stderr.
2. **Predict** how many state lines the program writes per card.

Acceptance criteria:

- Your capture contains state lines (they carry `tot:`) and the total field's `#` run grows to 41 or more `#` at the end.
- You identify, for one card, the substitution that adds hours (tally marks concatenate) and the one that rejects a draw of 10-15 for the nibble ([L29](../src/regex-sed/timecards.sed#L29)).

## C. By solution pattern

### C1. Write the boring version

**Lesson:** the [Weird next to boring](intro.md#weird-next-to-boring) idea. Pick any `-weird` entry.

Write the idiomatic version of the same behavior in the same language (if one does not exist) and compare.

Acceptance criteria:

- Your version's output passes `check-demo.sh`.
- A short table compares line count, what you can unit-test, what a debugger shows, and what the weird version could do that yours cannot.
- You answer the recurring question: *under what circumstances would the weird one be the right choice?*

### C2. Make the constraint real

**Lesson:** [patterns](patterns.md). Every entry ships a `check.sh` that proves its rule (for example, [`cobol-weird/check.sh`](../src/cobol-weird/check.sh) greps for banned words and counts `ALTER`s).

Choose an entry with a stated rule (no loop word, one statement, no variables) and write a check that **fails when the rule is broken**.

Acceptance criteria:

- Your check passes on the unmodified entry.
- For three different mutations (reintroduce a banned construct, add a second statement, remove a required one) your check fails each time. Show the three commands.
- Your check strips comments and string literals before searching, so a banned word in a comment does not trigger it.

### C3. A pattern in a new place

Pick one [pattern](patterns.md#control-state-outside-variables) and find a *new* home for the state: for example, a program counter in an `awk` record separator, or the loop in a SQL recursive CTE. You do not have to finish the whole demo; implement a loop that runs exactly N times and stops by that mechanism.

Acceptance criteria:

- The loop runs exactly N times for N in {1, 3, 10}, shown by a printed counter.
- There is no `for`, `while`, recursion or `goto` in your source (state the grep that proves it).
- You document which of the three [knowledge levels](intro.md#three-kinds-of-knowledge) your trick depends on.

## D. Port the challenge

**Goal:** implement the shared demo in a language not yet in the repo (Lua, awk, Tcl, m4, SQL recursive CTE, PowerShell, make-with-eval...) under the rules in [`CHALLENGE.md`](../CHALLENGE.md), and run it only in the sandbox.

Acceptance criteria:

1. `bash check-demo.sh out.txt` passes on **25 consecutive runs** (loop it).
2. The output contains a `**DEMO ONLY**` marker and a `# committed total=N entries=M` line that matches the rows.
3. Hours are random in 10-19 (over 25 runs, at least five distinct values appear).
4. The stop rule is a property of your trick, not a helper called `RunEverything()`.
5. All output stays local: your Dockerfile follows the repo's rules ([`sandbox/dockerfile-lint.sh`](../sandbox/dockerfile-lint.sh) passes) and runs with no network.
6. A README with **How the stunt works** and honest **walls** sections.
7. A `check.sh` that enforces your constraint (see C2).

```bash
for i in $(seq 25); do
  sandbox/container/run-image.sh src/<yours> > out.txt 2>&1 || { echo "run $i failed"; break; }
  bash check-demo.sh out.txt || { echo "run $i bad"; break; }
done
```

See [`CONTRIBUTING.md`](../CONTRIBUTING.md) if you want to send it in.

## Close a blocker

Each item is a gap from [blocking problems](blocking-problems.md). Work in a copy of the entry.

| Blocker | Task | Acceptance criteria |
| --- | --- | --- |
| LINQ draws no random hours | Replace the fixed work week with random 10-19 hour draws, still **one statement** | Over 25 runs the total is over 40 and the last card crossed it (`check-demo.sh`-style), hours vary between runs, and `check.ps1` still verifies the one-statement rule |
| `regex-dotnet` cannot fail on purpose | Make the match fail while the host still obtains the rows | The pattern ends in a failing construct, yet the rows printed equal those from the unmodified version; explain *how* you kept the captures |
| `regex-dotnet` has no side effects | Produce a pulse or a write during the match without `Replace`, `Matches`, `NextMatch` or a loop in the host | Rows and pulse appear; `check.sh`'s banned-API list still passes |
| `cmake` outputs only after the loop | Print one row from *inside* the `while()` condition | One row printed per pass, before the loop ends, with `check.sh`'s no-body rule still passing |
| Make needs a shell | Replace `mkdir -p`, `sqlite3` or `rm` with something Make-native for **one** of them | Output unchanged; `check.sh`'s program list shrinks by one |
| Make reads `/proc` | Make the clock or entropy source work with an override variable (`NOW=<epoch>` already exists for tests) on a non-Linux path | Passing `NOW` yields the expected ISO week (compare with `date -u -d @<epoch> +%G-W%V`) |
| Nothing but C#/Java/Go/Rust/Python has a thread | Add a worker thread to one script entry | Rows are written from the thread; the main thread only waits; output still passes `check-demo.sh` |
| `sed`'s RNG is a toy | Replace the 16-bit LFSR with a 32-bit one | Over 25 runs, more than 16 distinct first draws appear (the toy repeats after 65,535 steps); `check.sh` passes |

## E. Windows Sandbox track

For the WPF entries (`ModernChallenge1`, `LinqChallenge1`, `LinqChallenge2`, `xaml`). Requires Windows Sandbox and a local .NET 10 SDK ([setup](../SANDBOX-SETUP.md#windows-sandbox)).

### E1. Run and read the evidence

```powershell
sandbox\windows\run.ps1 src\LinqChallenge1
sandbox\windows\run.ps1 src\xaml          # see profiles\README.md for passing strict.xaml
```

Acceptance criteria:

- The VM runs with networking off, a screenshot of the window is produced, and the entry's saved rows are printed.
- `LinqChallenge1` prints `PERSISTED 5 rows, total=40.0h`.
- You can name two entries whose rows total exactly 40 because the data is fixed, and one whose rows are random.

### E2. Break the XAML interpreter

1. Open `src\xaml\strict.xaml` and change `Random(42)`'s seed.
2. **Predict:** do the hours change? Why does the same seed give the same hours on every run?

Acceptance criteria:

- Two runs with the same seed produce identical hours; two runs with different seeds differ.
- You explain which element in the `.xaml` file corresponds to "the variable", and why the loop had to be unrolled four times.

## F. Prove a README claim

Every README has a "Gotchas" or "Walls" section. Pick **one claim** and write a test that would fail if it were false.

Examples: "`SYSTEM` returns the raw wait status (exit 3 comes back as 768)", "GnuCOBOL warns five times", "`takeWhile` drops the crossing card", "pcre2grep does not search `PATH`".

Acceptance criteria:

- The test runs in the sandbox and **passes** against current behavior.
- You also show it **fails** under a deliberate mutation (a negative control).
- You report whether the claim is **guaranteed**, **implementation-permitted** or **accidentally exploited**, and the evidence for that tag.
