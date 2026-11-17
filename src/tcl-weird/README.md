---
name: "Tcl"
teaches: "that Tcl code is just strings, so it can live in a database and be fetched, defined and run on demand, with SQLite triggers as the control flow."
kind: weird
languages: [tcl, sqlite]
lesson: "languages/tcl.md#sqlite-as-the-program"
loop-by: dispatch-and-triggers
evaluation: eager
assurance: accidentally-exploited
pairs-with: tcl
machine: "A string-command interpreter whose command lookup can be hooked"
state: "A TEMP table of proc source, and the depth of trigger recursion"
tags: [arbitrary-code-execution, control-flow, database-trigger, homoiconicity, recursion, reflection-and-metaprogramming, scope-and-binding, state]
---
# Tcl, weirder

**Teaches you:** that Tcl code is just strings, so it can live in a database and be fetched, defined and run on demand, with SQLite triggers as the control flow.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

[`timecards.tcl`](timecards.tcl) defines **no Tcl loop and no Tcl proc that deals or prints a card**. The program is rows in a SQLite table. One `INSERT` of card 1 brings it to life: a **recursive trigger** inserts the next card until the total is over 40, and each insert calls Tcl procs that exist only as TEXT in a table, pulled into the interpreter on demand by an overridden `unknown`. With `--gui`, even the window is a handful of rows.

The straight version is [`tcl`](../tcl/README.md).

## Run it

You need Tcl 8.6 (`tclsh`) with the `sqlite3` Tcl package (Ubuntu: `tcl8.6`, `libsqlite3-tcl`), and `tk8.6` for `--gui`.

```bash
cd src/tcl-weird
tclsh timecards.tcl                        # text
tclsh timecards.tcl --gui --seconds 3      # also a window, built from rows; closes after 3 seconds
./check.sh                                 # set TCLSH=/path/to/tclsh if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/TclWeird/demo-timecards.db` (default `~/.local/share/TclWeird/`). A run looks like this:

```text
# DEMO ONLY run 1794860980-15
Meetings	15	15	2026-W47	DEMO ONLY
Coding	13	28	2026-W47	DEMO ONLY
Debugging	17	45	2026-W47	DEMO ONLY
# committed total=45 entries=3 DEMO ONLY
# every proc that ran was fetched from SQLite by unknown: born category hours init runid week
# the loop was a recursive trigger, and one INSERT started it
# the window was built from 8 rows of the ui table
```

The `unknown:` line is real introspection: the `unknown` handler records each name it defines, and the list is printed at the end. The last line appears only with `--gui`. **Headless:** Tk needs an X display; `xvfb-run -a tclsh timecards.tcl --gui --seconds 1` works, and the container image below runs on Xvfb and screenshots the window.

## How the stunt works

Three hooks, then a program written in SQL.

### Hook 1: SQL that can call Tcl

```tcl
proc call {command args} { $command {*}$args }
db function tcl call
```

`db function name script` registers a Tcl command as an **SQL function**. From now on any SQL, including SQL inside a trigger, can say `tcl('hours')` or `tcl('category', 3)`, and SQLite calls back into the interpreter: `call hours`, `call category 3`. `{*}$args` is Tcl's "expand this list into separate words".

### Hook 2: the database is the library path

```tcl
rename unknown _unknown
proc unknown {name args} {
    if {[db exists {SELECT 1 FROM tcl_code WHERE name = $name}]} {
        db eval {SELECT params, body FROM tcl_code WHERE name = $name} {}
        proc $name $params $body
        lappend ::loaded $name
        return [uplevel 1 [list $name {*}$args]]
    }
    tailcall _unknown $name {*}$args
}
```

When Tcl is asked to run a command that does not exist, it calls a command named `unknown`, which is how `auto_load` and abbreviation of commands in the interactive shell work. This one is replaced: it looks the name up in the `tcl_code` table, creates the proc with `proc $name $params $body`, using the row's text as the body, and **retries the call**. The proc exists from then on; the next call does not touch the database. Anything not in the table is passed to the original handler, so real typos still fail properly.

### Hook 3: the program is a TEMP table and a TEMP trigger

```sql
CREATE TEMP TABLE tcl_code(name TEXT PRIMARY KEY, params TEXT, body TEXT);
INSERT INTO tcl_code VALUES
    ('hours', '', 'expr {10 + int(rand() * 10)}'),
    ('category', 'n', 'lindex {Meetings Coding Debugging Learning} [expr {($n - 1) % 4}]'),
    ('born', 'category hours total week', 'puts [join [list $category ...] \t] ...'), ...
```

Tcl code *is* text, so it fits in a column. (`TEMP` tables and triggers belong to the connection and vanish when it closes, so the file on disk contains only the timecards; `check.sh` verifies that.) The program is three languages deep in one file: Tcl, around SQL, around Tcl. Braces nest, and Tcl substitutes nothing inside them, so the text arrives intact.

### The loop is a trigger

```sql
CREATE TEMP TRIGGER next_card AFTER INSERT ON main.demo_timecards
BEGIN
    SELECT tcl('born', NEW.category, NEW.hours, NEW.running_total, NEW.iso_week);
    INSERT INTO demo_timecards(...)
    SELECT NEW.run_id, tcl('category', (SELECT count(*) ...) + 1),
           h, NEW.running_total + h, NEW.iso_week, datetime('now')
    FROM (SELECT tcl('hours') AS h)
    WHERE NEW.running_total <= 40;
END;
```

When a row is inserted, the trigger fires. It first calls `born` (print the row and, if there is a window, add a table row), then inserts the next card **if the total is 40 or less**: that `WHERE` is the stop rule. That insert fires the same trigger again, which is allowed because of `PRAGMA recursive_triggers = ON`; without it SQLite refuses to let a trigger trigger itself. The recursion depth *is* the number of cards.

### The one statement

```tcl
db eval {SELECT tcl('init')}                       ;# seeds rand()
db transaction {
    db eval {
        INSERT INTO main.demo_timecards(...)
        SELECT tcl('runid'), tcl('category', 1), h, h, tcl('week'), datetime('now')
        FROM (SELECT tcl('hours') AS h)
    }
}
```

That is the whole of the running program: insert card 1. Everything after is the trigger calling Tcl and Tcl, on demand, being loaded from the table that the trigger is looking at.

### `--gui`: widgets as rows

```sql
CREATE TEMP TABLE ui(id INTEGER PRIMARY KEY, command TEXT);
INSERT INTO ui(command) VALUES
    ('ttk::treeview .cards -columns {category hours total week} -show headings -height 6'),
    ('.cards heading category -text Category'), ... ('pack .cards ...'), ('ttk::label .note -textvariable ::summary'), ...
```

`SELECT tcl('uplevel', '#0', command) FROM ui ORDER BY id` runs each row at the global level: one SELECT builds the window. When `born` runs it checks `info commands .cards`, and if the widget exists, it inserts a row into it, so the table fills in as the trigger fires; `update` repaints and `after 400` slows it enough to watch.

## Why this is weird

Tcl's basic claim is "everything is a string", and this program takes it literally: the procedures are strings in a table, the loop is a feature of the database, and the interpreter's own missing-command hook is the loader. The SQL calls Tcl, and Tcl calls the SQL, and *which* of them is "the program" depends on where you stand. A Tcl programmer will recognize `unknown` and `uplevel`; very few will have seen them used as a database-backed autoloader. A SQL programmer will recognize a recursive trigger and be surprised that it is the only loop.

Why you might get fired: the control flow of a program is hidden in a trigger and a pragma, procedures cannot be found with grep or a debugger's source view, `unknown` hooks make typos in other people's code confusing, and the first time someone runs this against a *shared* database, every insert fires interpreter calls. Do not store code in a data table that other people can write to.

## What you can learn

- `unknown` and how Tcl autoloading actually works; `rename`, `tailcall`, and `uplevel` for transparent wrappers.
- `proc` as a *runtime* operation: a proc is created by calling a command with a string body.
- `{*}` expansion, `uplevel #0`, and `info commands` as a feature test.
- The `sqlite3` package's `db function`, which exposes any Tcl command to SQL.
- Recursive triggers (`PRAGMA recursive_triggers`), `TEMP` triggers and tables, and that a trigger body may contain a `SELECT` (its result is discarded, but its function calls still run).
- That `$name` inside a SQL string literal inside Tcl braces is just text. The bound-variable rule only applies to the SQL itself, which is why code with `$n` in it can be stored.

## Proof that the mechanisms do the work

`check.sh` demonstrates it by editing copies of the file:

- **Recursion.** Change `PRAGMA recursive_triggers = ON` to `OFF` and exactly one card is announced, not the three to five: the trigger fires for card 1 only.
- **Code in the table.** Replace the text of the `hours` row with `expr {19}` and every run prints three cards of 19 hours: the hours come from the row, not from anywhere in the Tcl.
- **Autoloading.** The run reports `born category hours init runid week` as fetched by `unknown`, and a static check shows only two procs (`call` and `unknown`) are defined in Tcl at all.
- **No loop command.** With comments removed, none of `while`, `for`, `foreach`, `lmap`, `dict for` appears in the file.
- **Nothing left behind.** After a run the file's `sqlite_master` lists only `demo_timecards`.

## Gotchas worth knowing

- **Statements are evaluated once per call, and SQLite owns the order.** The trigger depends on `h` being the same value in `h` and in `NEW.running_total + h`. Here SQLite evaluates the subquery's function call once per row; `check.sh` would fail if it did not (running totals must equal the sum), but SQLite does not promise this for non-deterministic functions. A hardened version would draw the hours once and store them.
- **Qualified names in triggers.** `INSERT INTO main.demo_timecards` is rejected inside a trigger ("qualified table names are not allowed"), so the trigger body uses the bare name. The trigger is `TEMP`, so the bare name resolves to the one table in `main`.
- **A tclsh that has loaded Tk does not exit** at the end of the script while the main window exists, so the script ends with `destroy .`.
- **Depth.** SQLite limits trigger recursion (1000 by default); the challenge needs 3 to 5.
- **Trust.** `unknown` runs whatever text is in the table. Here the table is built by the program itself in memory; this is not a pattern for data other people can edit.
- **Requirements.** The program needs the Tcl `sqlite3` package and, for the window, Tk. It was tested with Tcl 8.6.14 and SQLite 3.45.
- **Formatting.** No Tcl formatter was available; the layout is by hand. The SQL is laid out like the SQL in the other entries.

## What `check.sh` enforces

Everything in the previous section, then a `--gui --seconds 1` run under Xvfb (skipped, and said so, where neither Xvfb nor a `DISPLAY` exists) that must report the window built from 8 rows, then 25 real runs checked for sane records (hours 10-19, categories in order, correct totals, stopping when the total passes 40) with SQLite agreeing with the output.

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker). The `cc-rt-tcl` base image comes from `sandbox/container/build-bases.sh`.

```bash
sandbox/container/run-image.sh src/tcl-weird
sandbox/container/run-image.sh --out ./results src/tcl-weird    # the folder must be writable by user nobody
```

It builds this folder's [`Dockerfile`](Dockerfile), runs `--gui` on a virtual display with no network, a read-only file system and user `nobody`, takes a screenshot of the window, and prints the output and the rows written. The image holds Tcl/Tk, the Tcl sqlite3 package and sqlite3 on a minimal Ubuntu.
