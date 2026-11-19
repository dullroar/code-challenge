# Tcl

Entries: [`src/tcl`](../../src/tcl/README.md) (a `while` loop, dicts, an optional Tk window) and [`src/tcl-weird`](../../src/tcl-weird/README.md) (the program lives in SQLite).

For an advanced reading path with traces and experiments, see the [Tcl study guide](../study-guides/languages/tcl.md).

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

**Hook 3: the loop is a recursive trigger.** The [trigger](../../src/tcl-weird/timecards.tcl#L104-L114):

```sql
CREATE TEMP TRIGGER next_card AFTER INSERT ON main.demo_timecards
BEGIN
    SELECT tcl('born', NEW.category, NEW.hours, NEW.running_total, NEW.iso_week);
    UPDATE draw SET h = tcl('hours') WHERE NEW.running_total <= 40;
    INSERT INTO demo_timecards(...)
    SELECT NEW.run_id, tcl('category', ...), h, NEW.running_total + h, ...
    FROM draw
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

Tags: `proc`, `unknown`, `uplevel`, `namespace`, `dict`, and `try` are **guaranteed** by Tcl 8.6. `db function` and `db eval` variable binding belong to the **sqlite3 Tcl package** (**implementation-permitted**: the interface is stable but is not part of Tcl). Recursive triggers need `PRAGMA recursive_triggers`, **documented SQLite** behavior. That each card's hours are drawn exactly once is **guaranteed by design**: the hours are written into a one-row TEMP table and read from it twice, so the result does not depend on how often SQLite evaluates a function. (An earlier version used a subquery and relied on SQLite calling the function once per row, which is **accidentally exploited**: SQLite does not promise that for non-deterministic functions.)

### 4. Do this in production and you're fired

- **Your program is not in version control.** It is in a TEMP table that exists only for this connection. The `.tcl` file holds two procs and a string.
- **`unknown` is global.** Every misspelled command now takes a database lookup before the error. If the table is writable by someone else, so is your program.
- **Triggers are invisible in stack traces**, and SQLite's recursion depth limit (`SQLITE_MAX_TRIGGER_DEPTH`, 1000 by default) is a hidden constraint.
- **Quoting is two levels deep:** the Tcl in the SQL in the Tcl. A stray brace breaks the outer string.
- **A value used twice must be drawn once.** The hours are used as the hours and inside the running total. The trigger stores them in the one-row TEMP table `draw` and reads them from it, and `check.sh` counts the calls of the `hours` procedure (one per card).
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

When your code genuinely belongs with your data: a rules engine where rules are rows, a game where scripts live in the save file, a tool that must patch behavior in a running system. Using a recursive trigger as a `while` loop is a stunt; storing procs in a table is a design.

<!-- BEGIN GENERATED program-flow:languages/tcl.md -->
## How each program runs

Each picture below is the `## Program Flow` section of an entry's README, copied here by the build. It shows how that program makes the work happen: what the language, runtime or tool really does. [The introduction](../intro.md#what-the-challenge-does) shows what the challenge asks for and where entries differ.

### Program flow of `tcl`

From [`tcl`](../../src/tcl/README.md) ([source section](../../src/tcl/README.md#program-flow)).

```mermaid
flowchart TD
    accTitle: tcl: an ordinary while loop in a namespace, then one transaction
    accDescr: A flowchart. The main procedure parses the arguments with a while, lassign and switch loop, seeds the random generator from the clock and the process id, and calls draw. The draw procedure is a while loop. While the total is at or under the limit, it draws hours, adds them to the total with incr, picks the next category, and appends a card as a dict. When the total is over the limit, the save procedure opens SQLite and writes all the cards inside one transaction. Then the program prints the cards. Only if asked does it build a Tk window with a treeview.
    A["main: parse argv, seed rand from the clock and pid"] --> B{{"draw: while total <= limit?"}}
    B -->|yes| C["randomHours, incr total, pick a category, lappend a card as a dict"]
    C --> B
    B -->|no| D["save: db transaction inserts every card with bound parameters"]
    D --> E["Print the cards; build the Tk treeview only if --gui was given"]
```

**What this shows:** the conventional Tcl shape. A `while` is the loop, a dict is the card, and `db transaction` makes the save all-or-nothing. A guard around `main` lets the checks `source` the file and test `draw` in the same process.

**Why this mechanism matters:** the program draws first and saves afterwards, so the card list is complete before the database sees it. Tcl's `while` re-evaluates its test each pass, and the test comes before the draw, so the crossing card is kept. The weird sibling [`tcl-weird`](../../src/tcl-weird/README.md) moves the loop into the database.

### Program flow of `tcl-weird`

From [`tcl-weird`](../../src/tcl-weird/README.md) ([source section](../../src/tcl-weird/README.md#program-flow)).

```mermaid
sequenceDiagram
    accTitle: tcl-weird: a recursive SQLite trigger calls Tcl procs that are fetched from a table
    accDescr: A sequence diagram. The Tcl host installs three hooks and inserts the first card. Each insert fires a trigger in SQLite. The trigger calls the SQL function tcl, which calls back into Tcl. The first time the Tcl side asks for a command such as born, the command does not exist, so Tcl calls unknown. The unknown handler reads the proc's text from the tcl_code table, defines the proc and retries the call. The call prints the row. The trigger then inserts the next card, but only while the total of the card just inserted is 40 or less. That insert fires the trigger again. When the total is over 40, nothing is inserted, and control returns to the host, which prints the summary.
    participant H as Tcl host
    participant D as SQLite and the next_card trigger
    participant U as unknown handler
    participant T as tcl_code table
    H->>D: INSERT the first card
    loop each INSERT fires the trigger, while the total is 40 or less
        D->>H: SQL function tcl calls the Tcl command born
        H->>U: born does not exist yet, so Tcl calls unknown
        U->>T: look up the proc's params and body
        T-->>U: the text of the proc
        U->>H: define the proc, retry the call
        H-->>D: the row is printed
        D->>D: INSERT the next card: the trigger fires again
    end
    D-->>H: total is over 40, no insert: the trigger chain ends
    H->>H: print the summary
```

**What this shows:** the loop is a trigger that inserts a row and so fires itself, and every number and printed line comes from Tcl code stored as text in a table. The first call of a proc takes the long way, through `unknown` and the table, and later calls find the proc defined.

**Why this mechanism matters:** the database is dispatching, but it is not an event queue. The trigger runs synchronously inside the `INSERT`, and the recursion is the loop. The `WHERE` on the trigger's insert is the stop rule. Control moves between three layers (Tcl, SQL, Tcl) on one call stack.
<!-- END GENERATED program-flow:languages/tcl.md -->

## Computer science behind this page

<!-- BEGIN GENERATED concepts:languages/tcl.md -->
The computer-science ideas behind this page: [Arbitrary code execution](../cs/01-reading-an-adversarial-program.md#arbitrary-code-execution), [Control flow](../cs/03-control-flow-and-continuations.md#control-flow), [Recursion](../cs/03-control-flow-and-continuations.md#recursion), [Interpreters and virtual machines](../cs/05-formal-languages-as-computational-substrates.md#interpreters-and-virtual-machines), [State](../cs/06-state-beyond-variables.md#state), [Scope and binding](../cs/06-state-beyond-variables.md#scope-and-binding), [Homoiconicity: code as data](../cs/06-state-beyond-variables.md#homoiconicity-code-as-data), [Reflection and metaprogramming](../cs/06-state-beyond-variables.md#reflection-and-metaprogramming), [Database triggers](../cs/06-state-beyond-variables.md#database-triggers), [Serialization, deserialization and object pickling](../cs/06-state-beyond-variables.md#serialization-deserialization-and-object-pickling), [Transactions](../cs/07-effects-errors-and-commitment.md#transactions), [Callbacks](../cs/10-events-callbacks-and-reactive-control-flow.md#callbacks).
<!-- END GENERATED concepts:languages/tcl.md -->
