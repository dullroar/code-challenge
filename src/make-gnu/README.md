# GNU Make: the build tool is the interpreter

**Teaches you:** arithmetic and looping in plain Make syntax, no shell required.

> **DEMO ONLY.** Fictional time cards, written to a scratch SQLite file under `$XDG_DATA_HOME/MakeChallenge/`.
> Nothing here touches real time reporting.

Put the `Makefile` in an otherwise empty directory and run `make`. Output is the same shape as the other entries:

```
# DEMO ONLY run 2
Meetings	10	10	2026-W46	DEMO ONLY
Coding	13	23	2026-W46	DEMO ONLY
Debugging	19	42	2026-W46	DEMO ONLY
Runtime error near line 1: CHECK constraint failed: stop rule fired: total exceeds 40 (19)
# committed total=42 entries=3 DEMO ONLY
# make re-executed itself 3 times, once per card
```

The question this entry asks: **how much of the work can Make's own syntax do?** The `Makefile` contains no
`$(shell)`, no `!=`, no Guile and no `load`. `check.sh` greps for all of them.

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker).

```bash
sandbox/container/run-image.sh src/make-gnu
```

It builds this folder's [`Dockerfile`](Dockerfile) and runs the result with no network, a read-only file system and user `nobody`, then prints the output and a read-only look at the rows it wrote. In the image: GNU Make and sqlite3 on a minimal Ubuntu. The Makefile runs from a private folder that starts out holding nothing else.

## How the stunt works

| Job | Done by | Shell? |
|---|---|---|
| Entropy | `$(file </proc/sys/kernel/random/uuid)`, letters stripped with nested `$(subst)`; first decimal digit left | no |
| Hours 10–19 | the string `1` glued to that digit. "Mod 10" is picking a character | no |
| Category order | `$(word n,Meetings Coding Debugging Learning)` | no |
| Arithmetic | numbers are lists of `x`; `$(words $(wordlist 1,a,$(U)) $(wordlist 1,b,$(U)))` adds, `$(wordlist b+1,a,…)` subtracts | no |
| Stop rule (`total > 40`) | the 41st word of the running list exists: `$(word 41,…)` | no |
| **The loop** | Make **re-executes itself** once per card. Every pass includes the `.tc-N.mk` files written so far; a pattern rule writes the next one while the total is ≤ 40. A new file means "makefile remade", so Make restarts. `$(MAKE_RESTARTS)` is the loop counter. When the rule declines to write, nothing is remade and `all` runs | no |
| Clock | `btime` from `/proc/stat` + whole seconds from `/proc/uptime`, added digit by digit with a carry (`NOW=<epoch>` overrides it for tests) | no |
| ISO week | epoch ÷ 86400 by long division (÷100, then ÷864 digit by digit), a year-by-year calendar walk from 1970, then the Thursday-of-the-week rule | no |
| Report | `$(info)` with a tab variable; the report is a chain of phony targets (`init`, `rows`, `footer`, frames) so output stays in order | no |
| Glow | on a terminal only: 25 phony targets, one per frame, each printing a 256-colour **DEMO ONLY** banner one grey shade brighter, then dimmer, then erased (about 1.5 s). "Is stdout a terminal?" is `$(realpath /proc/self/fd/1)` being `/dev/pts/N` | no (frames pause with `sleep 0.06`) |
| Pop-up | `make pop` runs `wt.exe` (Windows Terminal) to open a window that runs the demo; the window closes itself when `make` exits | **yes** (`wt.exe`) |
| Persistence | `$(file)` writes a `.sql` script, then `sqlite3 db < script` | **yes** |
| Plumbing | `mkdir -p`, `rm -f`, and `:` (see below) | **yes** |

The stop rule is also checked by SQLite: the last statement inserts `total <= 40` into a table whose only column has
`CHECK(ok=1)`, so the named constraint error on stderr is the stop rule announcing itself, as in the other entries.

## Walls and fine print

- **A recipe that expands to nothing doesn't count as remaking the file.** The card file is written while the recipe
  line is *expanded*, but Make only notices (and restarts) if a command actually ran. So each card carries a `@:`,
  the shell's no-op. This is the one place the loop needs a shell at all.
- **One file per pass, not one file rewritten.** The first design rewrote a single `.state.mk`. It restarted once and
  then stopped: WSL's file timestamps are coarse enough that the rewrite looked unchanged. A file going from
  *missing* to *present* is unambiguous.
- **Make expands every line of a recipe before it runs any of them**, so `$(info)` output would come out before
  SQLite's header. The report is a chain of targets (`init`, `rows`, `all`) because a recipe is expanded just
  before its own target runs.
- **`#` starts a comment, even inside a SQL string in a variable.** The header's `'# DEMO ONLY'` is written `\#`.
- **No pure-Make way to create a directory or a SQLite file.** Hence `mkdir -p` and `sqlite3`.
- **Time is UTC.** `/etc/localtime` is binary, and Make has no way to read it. Local time only differs from this
  near a week boundary. The calendar is good through 2134 (the ruler is 60,000 days long) and handles the 2100
  non-leap year.
- **Escape codes need an ESC byte.** Make has no escape syntax, so the Makefile holds one literal `0x1b` (in `define ESC`).
- **`wt.exe` treats `;` as its own subcommand separator**, so the `make pop` command line must not contain one (a first
  attempt spawned a pile of "The system cannot find the file specified" windows).
- **`make pop`, `clean` and `check` never run the card loop**; the loop would leave cards behind that the popped
  `make` would then refuse as stale.
- **A crashed run leaves `.tc-*.mk` behind.** The next `make` refuses to start (it would otherwise treat them as
  real cards); `make clean` removes them.
- **Edge case:** four cards of exactly 10 hours total exactly 40, which continues. There are only four categories,
  so the fifth card reuses `Meetings`.
- `check.sh` runs `make` 25 times in a directory holding only the `Makefile`, compares the ISO week with SQLite's
  date arithmetic, compares the SQLite rows with the printed ones, and sweeps 20 boundary instants (year ends, 53-week
  years, 1970, 2096) against `date -u`, and checks (through a pty) that the glow is 24 frames in 1–3 s and absent in a pipe.

## Run it

```bash
make          # one run (glows if stdout is a terminal, silent in a pipe)
make pop      # same, in a new Windows Terminal window that closes itself
make check    # ./check.sh
make clean    # remove leftover state after an interrupted run
```

---

See the [root README](../../README.md#the-results-so-far) for how this compares to the other entries, and [`CHALLENGE.md`](../../CHALLENGE.md) if you want to write your own.
