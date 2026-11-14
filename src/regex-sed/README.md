# Regex challenge, Track 4: GNU sed (the program is one line of text, rewritten until it's done)

One `sed` command runs the whole timecard demo, writes the records to a real SQLite transaction, pulses a banner, and then **exits 1**. There are no variables, no numbers and no arithmetic anywhere in it. The entire program state is a single line of text, and every step is a regex substitution on that line. This entry goes beyond the original regex plan (it lives in git history as `plans/regex.md`), but it follows the same rules. **DEMO ONLY**: the records are fictional and go to a scratch SQLite file, with no connection to any real time-reporting system.

## Run it

GNU sed (Ubuntu's default), `sqlite3` (`sudo apt install sqlite3`) and coreutils' `basenc` (9.x on Ubuntu 24.04). Under WSL 2:

```bash
cd src/regex-sed
./timecards.sh            # run the demo
TRACE=1 ./timecards.sh    # also dump the program state (the line of text) to stderr at every step
./check.sh                # 25 runs plus static checks, asserts the rules below
```

Records go to `$XDG_DATA_HOME/RegexSed/demo-timecards.db` (default `~/.local/share/RegexSed/`). Delete that directory to start over. A run looks like this, followed by a three-second pulse on a real terminal:

```text
# DEMO ONLY run 1794625386-3788
Meetings	15	15	2026-W46	DEMO ONLY
Coding	14	29	2026-W46	DEMO ONLY
Debugging	14	43	2026-W46	DEMO ONLY
# committed total=43 entries=3 DEMO ONLY
# sed now exits with status 1 (failure), on purpose
```

## The idea

The other regex entries make **one match** do the work. The engine's quantifiers and backtracking are the loop, and a host language (Perl code blocks, a C struct, SQLite) does the arithmetic. This entry takes the opposite approach: **many small substitutions, one after another, on a single string**. Nothing outside that string holds any state. Random numbers, addition, comparison and decimal formatting are all done by rewriting text. That is an old and well-understood model of computation, the Markov algorithm.

## Markov algorithms: computing by find-and-replace

A **Markov algorithm** (Andrey Markov Jr. called them *normal algorithms*, in the early 1950s; not the Markov of Markov chains) is a program made of nothing but an ordered list of rewrite rules, `pattern → replacement`. It runs like this:

1. Look through the rules **in order** and find the first one whose pattern appears anywhere in the string.
2. Replace the **leftmost** occurrence of that pattern with the rule's replacement.
3. If that rule is marked as terminating, stop. Otherwise go back to step 1 and **start again from the first rule**.
4. If no rule's pattern appears in the string, stop.

That's the whole model: no variables, no memory but the string, no instructions but "replace this with that." And it is **Turing-complete**. Anything a computer can compute, some list of rewrite rules can compute too, given a long enough string.

### A tiny example: binary to unary

Three rules convert a binary number into that many tally marks:

| # | Rule | Meaning |
|---|---|---|
| 1 | `\|0` → `0\|\|` | a mark passing a `0` to its right doubles (moving a digit one place left in binary doubles its value) |
| 2 | `1` → `0\|` | a `1` becomes a `0` with one mark |
| 3 | `0` → *(nothing)* | once no marks are left of any `0`, delete the `0`s |

Run on `101` (five), always restarting from rule 1:

| String | Rule applied |
|---|---|
| `101` | 2: the first `1` becomes `0\|` |
| `0\|01` | 1: `\|0` becomes `0\|\|` |
| `00\|\|1` | 2: no `\|0`, so the next `1` |
| `00\|\|0\|` | 1 |
| `00\|0\|\|\|` | 1 |
| `000\|\|\|\|\|` | 3: no `\|0` or `1` left, delete a `0` |
| `00\|\|\|\|\|` | 3 |
| `0\|\|\|\|\|` | 3 |
| `\|\|\|\|\|` | no rule applies: stop. Five marks |

### The same algorithm in sed

sed can run a Markov algorithm almost word for word. `s` replaces the leftmost match, and `t top` ("jump to `top` if the last substitution matched") supplies the "start again from the first rule":

```sed
:top
s/|0/0||/
t top
s/1/0|/
t top
s/0//
t top
```

`echo 101 | sed -f b2u.sed` prints `|||||`. (I ran this, and `sed --debug` shows exactly the nine strings in the table above.)

### How `timecards.sed` relates to that

`timecards.sed` is not written as one flat Markov rule list. That would work in principle, but it would be thousands of rules and unreadable even by this entry's standards. It is a **Markov-style machine with a program counter**: the string is still the only memory and every operation is still a substitution, but labels and jumps (`b`, `/regex/b`) decide which group of rules runs next. Inside the groups, pure Markov behavior shows up all over:

- The **lookup tables** (bits to digit, digit to tally marks, tally marks to decimal) are ordered rule lists where the first rule that matches wins.
- The **XOR** is a three-rule rewriting system: delete the `0`s, then an odd number of `1`s becomes `1` and an even number becomes `0`.
- The **loops** (`/ k:#/b step`) are "keep applying this group while its pattern still matches," which is the Markov restart in a different form.
- Every **decision** is "does this pattern occur in the string?" That's step 1 of a Markov algorithm, used as an `if`.

## The program state: one line of text

`timecards.sh` writes one line (the *tape*) and runs one `sed` command on it:

```text
run:1794625386-3788 wk:2026-W46 rng:1011001110100101 tty:1 trace:0
```

The first substitution validates it and adds the rest of the state. From then on, the pattern space looks like this, and it is the entire computer:

```text
run:1794625386-3788 wk:2026-W46 tty:1 trace:0 rng:0101101100111010 cats:Coding,Debugging,Learning, tot:############### n:%
```

| Field | Holds | Represented as |
|---|---|---|
| `run:`, `wk:` | run id, ISO week | text from the host, copied into the output |
| `tty:` | is stdout a terminal (for the pulse) | `tty -s`'s exit status, `0` = yes |
| `trace:` | dump the state at each step? | `0` / `1` |
| `rng:` | the random number generator | 16 characters of `0`/`1`: a shift register |
| `cats:` | categories not yet used | a comma list, consumed from the front |
| `tot:` | the running total | **tally marks**: 15 hours is `###############` |
| `n:` | entries so far | tally marks: `%%%` is 3 |
| `k:`, `x:`, `c:`, `d:`, `D:` | scratch registers | appear and disappear during one iteration (see the trace) |
| `ret:` | return address for the decimal-printing subroutine | the text `ret:row` or `ret:sum` at the front |

`TRACE=1` prints this line at the top of each iteration and after each shift-register step. For the full story, GNU sed can show every command and the string after it:

```bash
echo 'run:1794625386-3788 wk:2026-W46 rng:1011001110100101 tty:1 trace:0' \
  | sed --debug -nE -f timecards.sed 3>/dev/null | less
```

That fixed seed always produces the run shown at the top of this README. The trace below is taken from that `--debug` output.

## One iteration, traced step by step

This is the **second** iteration of that run: it books *Coding, 14 hours*, taking the total from 15 to 29. It's a good one to follow because its first random draw is **rejected** and redrawn. It takes 137 sed commands, 58 of them substitutions that actually matched. In the snapshots below, `…` stands for the unchanging prefix `run:1794625386-3788 wk:2026-W46 tty:1 trace:0`.

### Step 1: the loop head and the stop rule

```text
… rng:0101101100111010 cats:Coding,Debugging,Learning, tot:############### n:%
```

```sed
:entry
/ trace:1 /w /dev/stderr
/ tot:#{41}/b done
/ cats: /b done
```

The second line prints the state if tracing is on. The third is the **stop rule**: if the total contains 41 marks, it's over 40, so jump to the finish. Here it has 15, so no match. The fourth stops if the category list is empty, and it isn't. Two "comparisons," and neither one compares numbers. Each asks whether a pattern occurs.

### Step 2: take the next category

```sed
s/ cats:([A-Za-z]+),(.*)$/ cats:\2 c:\1/
```

The first category moves off the list into a scratch field `c:` at the end:

```text
… rng:0101101100111010 cats:Debugging,Learning, tot:############### n:% c:Coding
```

### Step 3: draw a random nibble (four shift-register steps)

```sed
:draw
s/ rng:/ k:#### rng:/
```

A counter `k:####` (four marks, four steps) is inserted. Then the `:step` group runs once per mark. Here is the **first step** in full:

```sed
:step
s/ rng:([01]{10})([01])([01])([01])([01])([01])([01]) / rng:\1\2\3\4\5\6\7 x:\2\4\5\7 /
```

This *copies* the four **tap bits** (characters 11, 13, 14 and 16) into a scratch field `x:`. The register `0101101100111010` has taps `1`, `1`, `0`, `0`:

```text
… k:#### rng:0101101100111010 x:1100 cats:…
```

```sed
s/ x:0*(1?)0*(1?)0*(1?)0*(1?)0* / x:\1\2\3\4 /
s/ x:(11)*1 / x:1 /
s/ x:(11)* / x:0 /
```

That's **XOR, done by rewriting**. First the `0`s are deleted (`x:1100` becomes `x:11`). Then an odd number of `1`s becomes `x:1` (no match here) and an even number becomes `x:0` (match). The XOR of `1,1,0,0` is `0`.

```sed
s/ rng:([01]{15})[01] x:([01]) / rng:\2\1 /
s/ k:#/ k:/
/ k:#/b step
```

The **shift**: the new bit goes on the front, the last bit falls off the end, and `x:` disappears. One counter mark is removed, and if any remain, it loops:

```text
… k:### rng:0010110110011101 cats:…
```

The three remaining steps go the same way:

| Step | Register before | Tap bits → `x:` | `0`s dropped | XOR | Register after |
|---|---|---|---|---|---|
| 1 | `0101101100111010` | `1100` | `11` | `0` | `0010110110011101` |
| 2 | `0010110110011101` | `0111` | `111` | `1` | `1001011011001110` |
| 3 | `1001011011001110` | `0110` | `11` | `0` | `0100101101100111` |
| 4 | `0100101101100111` | `1011` | `111` | `1` | **`1010`**`010110110011` |

After four steps, the first four characters are four brand-new bits: `1010`, which is 10.

### Step 4: reject and redraw

```sed
s/ k: / /
/ rng:1(01|1)/b draw
```

The empty counter is removed. A digit must be 0-9, so `1010` through `1111` (10-15) are rejected. In binary those are exactly the nibbles that start with `101` or `11`, so the regex `1(01|1)` matches them, and it matches here. **Jump back to `:draw`** and run four more steps:

| Step | Register before | Tap bits → `x:` | `0`s dropped | XOR | Register after |
|---|---|---|---|---|---|
| 5 | `1010010110110011` | `1001` | `11` | `0` | `0101001011011001` |
| 6 | `0101001011011001` | `0101` | `11` | `0` | `0010100101101100` |
| 7 | `0010100101101100` | `1110` | `111` | `1` | `1001010010110110` |
| 8 | `1001010010110110` | `1010` | `11` | `0` | **`0100`**`101001011011` |

`0100` doesn't match `1(01|1)`, so execution continues.

### Step 5: bits to a digit (a lookup table)

```sed
s/ rng:([01]{4})(.*)$/ rng:\1\2 d:\1/
s/ d:0000$/ d:0/
s/ d:0001$/ d:1/
…
s/ d:1001$/ d:9/
```

The nibble is copied to the end as `d:0100`, and a ten-rule lookup table rewrites it. Rules for `0000` through `0011` don't match, then `d:0100` becomes `d:4`, and the remaining rules don't match either:

```text
… rng:0100101001011011 cats:Debugging,Learning, tot:############### n:% c:Coding d:4
```

The hours are now *the text* `1` followed by `4`. Nothing ever adds 10 to 4.

### Step 6: the digit to tally marks (another lookup table)

```sed
s/ d:([0-9])$/ d:\1 D:##########\1/
s/ D:(#*)9$/ D:\1#########/
…
s/ D:(#*)4$/ D:\1####/
…
```

A scratch field `D:` starts as ten marks plus the digit (`D:##########4`). The table replaces the trailing `4` with four more marks:

```text
… tot:############### n:% c:Coding d:4 D:##############
```

### Step 7: addition is concatenation

```sed
s/ tot:(#*) (.*) D:(#*)$/ tot:\1\3 \2/
s/ n:(%*) / n:\1% /
```

The 14 marks in `D:` move onto the end of the 15 in `tot:`. That is the entire addition. The entry count gets one more `%`:

```text
… tot:############################# n:%% c:Coding d:4
```

### Step 8: save the state and build the output row

```sed
h
s/^run:([^ ]+) wk:([^ ]+) .* tot:(#+) .* c:([A-Za-z]+) d:([0-9])$/ret:row \4\t1\5\t\3\t\2\tDEMO ONLY\n\1/
b dec
```

sed has one spare buffer, the **hold space**. `h` copies the whole state into it, because the next substitution destroys the pattern space by rewriting it into the output row. The row still has the total in tally marks, and the run id is tucked on after a newline for later:

```text
ret:row Coding	14	#############################	2026-W46	DEMO ONLY
1794625386-3788
```

`ret:row` at the front is a **return address**. sed has no call or return, so the caller writes where to come back to into the text, then jumps to the subroutine.

### Step 9: the subroutine, tally marks to decimal

```sed
:dec
s/#{10}/@/g
s/@([^#@])/@0\1/
s/#########/9/
…
s/#/1/
s/@@@@@/5/
…
s/@/1/
/^ret:row /b row
/^ret:sum /b sum
```

Every ten marks become one `@` (`@@#########`). The second rule adds a `0` when there are tens but no units left over, which isn't the case here. A units table turns the nine leftover marks into `9`, and a tens table turns `@@` into `2`:

```text
ret:row Coding	14	29	2026-W46	DEMO ONLY
1794625386-3788
```

Then the subroutine "returns": it matches `^ret:row ` against the text and jumps to `:row`.

### Step 10: print the row, then turn it into SQL

```sed
:row
s/^ret:row //
P
s/^([A-Za-z]+)\t([0-9]+)\t([0-9]+)\t([^\t]+)\tDEMO ONLY\n(.*)$/INSERT INTO demo_timecards(…) VALUES('\5','\1',\2,\3,'\4',datetime('now','localtime'));/w /dev/fd/3
```

`P` prints the pattern space only up to the first newline, so the screen gets just the row:

```text
Coding	14	29	2026-W46	DEMO ONLY
```

Then the same text is rewritten into an `INSERT`, using the run id after the newline, and the substitution's `w` flag writes it to fd 3, which the host has piped into `sqlite3`:

```sql
INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES('1794625386-3788','Coding',14,29,'2026-W46',datetime('now','localtime'));
```

### Step 11: restore the state and loop

```sed
g
s/ c:[A-Za-z]+ d:[0-9]$//
b entry
```

`g` copies the saved state back from the hold space, the per-entry scratch fields are deleted, and execution jumps to the top. The next iteration starts with:

```text
… rng:0100101001011011 cats:Debugging,Learning, tot:############################# n:%%
```

The third iteration books Debugging 14, for a total of 43. Then step 1's stop rule finds 41 marks in a row, and `b done` ends the loop.

## Finishing: the summary, the pulse, and exit 1

After the loop, `:done` builds the summary line, borrows the same `:dec` subroutine (with `ret:sum`), prints it, and sends `COMMIT;` down fd 3. If sed never got that far, SQLite would roll the whole run back at end of input, so a half-finished run leaves no rows.

**The pulse** runs only if `tty:0`. sed has no `sleep`, so each frame is timed by making the regex engine **grind**: the state is swapped out for `aaa…acb`, and `/^(a+)\1*(a+)\2*b/` is tested against it. That can never match (a `c` is always in the way), but glibc's backreference matcher tries every way of splitting the `a`s before giving up, roughly 50 ms per frame on the test machine. Then the state comes back, the next shade is read off a list of 60 grey levels appended to it, and the banner is redrawn in place with `\x1b[A` (cursor up). This is the denial-of-service-shaped worst case that regex engines are criticized for, used as a clock.

Finally `Q1` quits with exit status 1. In shell terms the program "fails" after doing all of its work. That is the sed form of the signature move.

## Why this is a different exercise from the other regex entries

- **The regex entries borrow a computer, but sed is one.** In Perl, PCRE2 and pcre2grep, the pattern supplies the control flow (looping, branching, stopping), but the arithmetic happens in Perl, C or SQLite. Here there's nowhere else to go, so randomness, addition, comparison and number formatting are all text rewriting.
- **It's a different model of computation.** The other entries use *backtracking search*: one match explores paths and abandons branches. This one is a *rewriting system*. A single regex match always finishes, because its input is fixed and it can only try a bounded number of paths. Rewriting a string over and over in a loop is Turing-complete. The other entries show a regex engine *driving* a program; this one shows substitution *being* one.
- **You can see the entire machine.** Perl's state is in hidden variables and PCRE2's is in C memory. Here every bit of state, including the return address, is in one printable line.
- **The data structures had to be invented.** Integers are tally marks, addition is concatenation, `> 40` is "does `#{41}` match," XOR is deleting zeros and checking whether the count of `1`s is odd, a random number generator is a 16-character string, and a function call is a return address written into the text.
- **Each regex is simple; the composition is what's hard.** The Perl and PCRE2 entries are one monstrous pattern each. Here almost every regex is short and readable on its own, and the baffling part is that 137 of them in a row book one timecard.

## The walls and the fine print

- **sed has a goto.** `b` and `t` jump, which the Perl and PCRE entries don't have. Those entries had to get their loops out of quantifiers and backtracking, which is arguably the stricter constraint. Here almost every jump is behind an address (`/regex/b label`), so a regex match still makes every decision, but the structure is a rewriting machine with a program counter, not a single match.
- **"Returning false" is weaker.** In Perl and PCRE the *match itself* reports failure after doing the work. sed has no match result that spans the whole program, so the closest equivalent is the process exit status.
- **The randomness is a toy.** The host seeds the shift register with 16 bits from `/dev/urandom` (an all-zero seed, which would stick the register, is replaced inside sed). After that, every draw is sed rewriting `0`s and `1`s. The taps (16, 14, 13, 11) give the maximal period of 65,535, but the same seed always gives the same timecards, and `check.sh` relies on that. It is not a good random number generator, which suits a DEMO ONLY program.
- **The host is not nothing.** `timecards.sh` creates the scratch directory, works out whether stdout is a terminal (`tty -s`, passed in as `tty:0`/`tty:1` because sed can't ask), writes the tape, wires fd 3 into `sqlite3`, and maps sed's exit status 1 to 0 so that "failed on purpose" doesn't look like an error. It has no loop and no `if`, and `check.sh` enforces both.
- **No shell-outs.** GNU sed can run commands (`e` and `s///e`) and read files (`r`, `R`). `check.sh` rejects all of those, and rejects any `w` target other than fd 3 and stderr. I tested that each injected violation makes it fail. The checks are greps over the script, not a sandbox (`sed --sandbox` would also forbid the `w` this entry needs).
- **The pulse speed depends on the machine.** The backtracking clock was calibrated on one WSL 2 machine at roughly 3 seconds for 60 frames. A slower CPU pulses slower. The time grows steeply with the length of the `a…` tape inside `timecards.sed`, so shorten it if the pulse drags. Pipes and `check.sh` skip the pulse entirely.
- **GNU only.** `T`, `Q`, `--debug`, `\x1b`, `\t` and `-E` intervals are GNU extensions. macOS/BSD sed won't run this.
- SQL is built by pasting text into strings. That's safe here only because every value is a run id the host built from digits, a week from `date`, one of four fixed category names, or a number sed produced from tally marks. Don't copy the habit.
- `run_id` is `epoch-pid`, so two runs in the same second from the same PID would collide. It's a toy.

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker).

```bash
sandbox/container/run-image.sh src/regex-sed
```

It builds this folder's [`Dockerfile`](Dockerfile) and runs the result with no network, a read-only file system and user `nobody`, then prints the output and a read-only look at the rows it wrote. In the image: GNU sed, bash and coreutils (from the Ubuntu base) and sqlite3. No compiler, no package manager.
