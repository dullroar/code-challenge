# Tcl

Entries: [`src/tcl`](../../src/tcl/README.md) (a `while` loop, dicts, an optional Tk window) and [`src/tcl-weird`](../../src/tcl-weird/README.md) (the program lives in SQLite).

## What makes Tcl special

Tcl's rule is "everything is a command, and every command receives its arguments as strings". There is no keyword for `while`, `proc` or `if`: they are commands, and `{...}` is just a way to hand a command an unevaluated string. That makes the language tiny, and makes two features cheap that most languages treat as exotic: **rewriting how unknown commands are resolved** and **running a string as code in another scope**.

| Feature | Where | What it teaches |
| --- | --- | --- |
| Braces defer evaluation | [`tcl/timecards.tcl` L40](../../src/tcl/timecards.tcl#L40): `while {$total <= $limit} {` | The condition is a braced string, evaluated again every pass. Write `while $total <= $limit` and it is substituted once, and never changes. The same rule is why `expr` should always be braced. |
| Dictionaries are values | [L44](../../src/tcl/timecards.tcl#L44): `lappend cards [dict create category $category hours $hours total $total]` | A card is a plain dict; no class is needed. |
| `dict with` unpacks into variables | [L86](../../src/tcl/timecards.tcl#L86): `dict with card {` | A dict's keys become local variables for a block. |
| `db eval` binds Tcl variables as SQL parameters | [L87-91](../../src/tcl/timecards.tcl#L87-L91): `VALUES ($runId, $category, $hours, $total, $week, ...)` | The `$name` inside the braced SQL is not pasted in as text. SQLite receives it as a bound parameter, so quoting is never a problem. |
| `try ... finally` closes the database | [L77-95](../../src/tcl/timecards.tcl#L77-L95) | Cleanup survives an error. |
| Tk is a package, not a program | [L110](../../src/tcl/timecards.tcl#L110): `showWindow`, `--gui` and `--seconds N` | A GUI is a few commands, and with Xvfb it can be tested headless. |
| An entry-point guard | [L170](../../src/tcl/timecards.tcl#L170): `if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]}` | The file can be `source`d for testing without running. |

## SQLite as the program

### 1. Behold the monstrosity

```bash
sandbox/container/run-image.sh src/tcl-weird
```

Open [`timecards.tcl`](../../src/tcl-weird/timecards.tcl). Exactly **two** procs are defined in Tcl, and neither deals a card. The code that does is *text in a database table*, and the loop is an SQL trigger.

### 2. How the hell does that work?

Three hooks make a program out of nothing.

**Hook 1: SQL can call Tcl.** [`db function tcl call`](../../src/tcl-weird/timecards.tcl#L28-L34) registers an SQL function `tcl(command, args...)` whose implementation is a Tcl proc that runs a command. From inside any SQL statement, `SELECT tcl('hours')` runs the Tcl command `hours` and returns its result.

**Hook 2: `unknown` is the library path.** When Tcl is asked to run a command that does not exist, it calls a command named `unknown`. The entry [renames and replaces it](../../src/tcl-weird/timecards.tcl#L36-L49): it looks the name up in a TEMP table `tcl_code(name, params, body)`; if there is a row, it defines a proc from it with `proc $name $params $body` and retries. So `hours`, `category`, `born` and the rest are *never* written as Tcl source. The first call to `tcl('hours')` finds no such command, asks `unknown`, which finds the row in SQLite, builds the proc, and runs it. The program prints which procs came out of the database at the end:

```text
# every proc that ran was fetched from SQLite by unknown: born category hours init runid week
```

**Hook 3: the loop is a recursive trigger.** The [trigger](../../src/tcl-weird/timecards.tcl#L99-L108):

```sql
CREATE TEMP TRIGGER next_card AFTER INSERT ON main.demo_timecards
BEGIN
    SELECT tcl('born', NEW.category, NEW.hours, NEW.running_total, NEW.iso_week);
    INSERT INTO demo_timecards(...)
    SELECT NEW.run_id, tcl('category', ...), h, NEW.running_total + h, ...
    FROM (SELECT tcl('hours') AS h)
    WHERE NEW.running_total <= 40;
END;
```

Inserting a card fires the trigger, which prints the card (via `tcl('born', ...)`) and inserts the *next* one. That insert fires the trigger again. The `WHERE NEW.running_total <= 40` is the stop rule: when it is false the `INSERT ... SELECT` inserts nothing, so no further trigger fires. [`PRAGMA recursive_triggers = ON`](../../src/tcl-weird/timecards.tcl#L55) is required: SQLite's default is that a trigger does not fire itself. The one statement that starts everything is the `INSERT` of card 1.

**The window is data too.** With `--gui`, a TEMP table `ui(id, command)` holds eight Tk commands, run by `SELECT tcl('uplevel', '#0', command) FROM ui ORDER BY id`. `uplevel #0` evaluates each string at global level, where `.cards` and `.note` must live. Each card's `born` then adds a row to the tree view and updates the screen.

### 3. What did we just learn?

- **Code and data are the same thing in Tcl.** A proc is created from two strings; the place the strings came from is up to you. Here it is a database row, so `UPDATE tcl_code SET body = ...` is a hot-patch.
- **A database trigger is a control-flow construct.** It is an event handler that can cause the event it handles: that is recursion.
- **Every hook point is a loop opportunity.** SQLite lets you register functions and triggers; Tcl lets you intercept lookups. Either alone is a feature, together they are a runtime.
- **Braces versus substitution** decides everything in Tcl. (Compare [Make's expansion time versus run time](make-cmake.md#gnu-make) and [m4's quoting](m4.md).)

Tags: `proc`, `unknown`, `uplevel`, `namespace`, `dict`, and `try` are **guaranteed** by Tcl 8.6. `db function` and `db eval` variable binding belong to the **sqlite3 Tcl package** (**implementation-permitted**: the interface is stable but is not part of Tcl). Recursive triggers need `PRAGMA recursive_triggers`, **documented SQLite** behaviour. That `SELECT tcl('hours')` is called *once* per trigger run is **accidentally exploited**: SQLite evaluates the subquery a single time, but does not promise that.

### 4. Do this in production and you're fired

- **Your program is not in version control.** It is in a TEMP table that exists only for this connection. The `.tcl` file holds two procs and a string.
- **`unknown` is global.** Every misspelled command now takes a database lookup before the error. If the table is writable by someone else, so is your program.
- **Triggers are invisible in stack traces**, and SQLite's recursion depth limit (`SQLITE_MAX_TRIGGER_DEPTH`, 1000 by default) is a hidden constraint.
- **Quoting is two levels deep:** the Tcl in the SQL in the Tcl. A stray brace breaks the outer string.
- **It depends on SQLite's evaluation order.** The stunt's `check.sh` has a test that would catch a change, but SQLite does not promise it.
- **Tk quirk:** a `tclsh` that has loaded Tk does not exit when the script ends. The entry calls `destroy .` (a normal Tk program is waiting for events).

Legitimate uses: **loading code on demand** (Tcl's own `unknown` already calls `auto_load` to find a command's definition on disk), **SQL functions that call back into the host language** (a standard SQLite feature), and **keeping rules in a table** so they can change without a deploy. Tcl Starkits packed a whole application into one virtual-filesystem file for the same reason: code that travels with its data.

### 5. Now break it yourself

See [exercises](../exercises.md#b12-tcl-edit-the-program-in-the-database-verified).

## Quirks

- **Triggers reject a qualified table name in `INSERT`.** Inside the trigger, `main.demo_timecards` is an error; the unqualified name is required, while the `AFTER INSERT ON main.demo_timecards` line does qualify, because a TEMP trigger watches a table in the main database.
- **`expr` without braces is both slower and a code-injection hole.** The idiomatic entry braces every `expr`.
- **`dict with` writes back**: assignments to the unpacked variables update the dict.
- **`DISPLAY=:0` under WSL hangs Tk.** Tests use `xvfb-run`; see `check.sh`.

## Weird next to boring

[`tcl`](../../src/tcl/README.md) is a namespaced `while` with dicts and bound SQL parameters: tidy, testable, unit-testable (`draw` is called 2,000 times in its check). [`tcl-weird`](../../src/tcl-weird/README.md) has the same output and none of those properties. The first is how you write Tcl; the second is what Tcl's "everything is a string command" *permits*. Compare [`haskell`](haskell.md#lazy-io-as-control-flow), where effects hide inside a lazy list, and [CMake](make-cmake.md#cmake), where a `while()` condition is the register machine.

## Under what circumstances would this terrible idea become reasonable?

When your code genuinely belongs with your data: a rules engine where rules are rows, a game where scripts live in the save file, a tool that must patch behaviour in a running system. Using a recursive trigger as a `while` loop is a stunt; storing procs in a table is a design.
