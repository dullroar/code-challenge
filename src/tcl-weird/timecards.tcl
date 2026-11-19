#!/usr/bin/env tclsh
# DEMO ONLY. Fictional timecards, written to a scratch SQLite file under
# XDG_DATA_HOME. Nothing here touches a real time-reporting system.
#
# Run:  tclsh timecards.tcl            (text)
#       tclsh timecards.tcl --gui      (the window is built from rows too; --seconds N closes it)
#
# The challenge: add cards of 10-19 hours until the running total passes 40.
#
# THE STUNT.  This file defines no Tcl loop and no Tcl proc that deals or
# prints a card. The program is rows in a SQLite table, and one INSERT starts it:
#
#   * the loop is a recursive SQLite trigger: inserting a card fires the
#     trigger, which inserts the next card, until the total is over 40;
#   * every number, name and printed line comes from Tcl procs that live as
#     TEXT in a table, fetched on demand by an `unknown` handler;
#   * SQL calls those procs through a Tcl command registered as an SQL function;
#   * with --gui, even the window's widgets are rows.
#
# The Tcl below only installs those three hooks, hands SQLite the program,
# and runs the INSERT.

package require sqlite3

set dir [expr {[info exists ::env(XDG_DATA_HOME)] && $::env(XDG_DATA_HOME) ne ""
    ? $::env(XDG_DATA_HOME) : [file join $::env(HOME) .local share]}]
file mkdir [file join $dir TclWeird]
sqlite3 db [file join $dir TclWeird demo-timecards.db]

# Hook 1: an SQL function, tcl(command, args...), that runs a Tcl command.
proc call {command args} {
    $command {*}$args
}
db function tcl call

# Hook 2: Tcl calls `unknown` for any command that does not exist. Ours looks
# the name up in the tcl_code table, defines it as a proc from the row, and
# retries the call. The database is the library path.
set loaded {}
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

# Hook 3: the program, as SQL. TEMP tables and triggers live only as long as
# this connection, so the file on disk keeps nothing but the timecards.
# (Tcl inside SQL inside Tcl: braces nest, and nothing here is substituted.)
db eval {
    PRAGMA recursive_triggers = ON;          -- without this the trigger below fires once

    CREATE TABLE IF NOT EXISTS demo_timecards(
        id INTEGER PRIMARY KEY, run_id TEXT, category TEXT, hours INTEGER,
        running_total INTEGER, iso_week TEXT, created_at TEXT,
        demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));

    CREATE TEMP TABLE tcl_code(name TEXT PRIMARY KEY, params TEXT, body TEXT);
    INSERT INTO tcl_code VALUES
        ('init',     '',
         'expr {srand([clock microseconds] ^ [pid])}'),
        ('runid',    '',
         'set ::runid [clock seconds]-[pid]
          puts "# DEMO ONLY run $::runid"
          set ::runid'),
        ('week',     '',
         'clock format [clock seconds] -format %G-W%V'),
        ('hours',    '',
         'expr {10 + int(rand() * 10)}'),
        ('category', 'n',
         'lindex {Meetings Coding Debugging Learning} [expr {($n - 1) % 4}]'),
        ('born',     'category hours total week',
         'puts [join [list $category $hours $total $week {DEMO ONLY}] \t]
          set ::summary "DEMO ONLY: running total $total"
          if {[llength [info commands .cards]]} {
              .cards insert {} end -values [list $category $hours $total $week]
              update
              after 400
          }');

    -- The window, as data: one Tk command per row, run in order.
    CREATE TEMP TABLE ui(id INTEGER PRIMARY KEY, command TEXT);
    INSERT INTO ui(command) VALUES
        ('ttk::treeview .cards -columns {category hours total week} -show headings -height 6'),
        ('.cards heading category -text Category'),
        ('.cards heading hours -text Hours'),
        ('.cards heading total -text Total'),
        ('.cards heading week -text Week'),
        ('pack .cards -fill both -expand 1 -padx 8 -pady 8'),
        ('ttk::label .note -textvariable ::summary'),
        ('pack .note -pady {0 8}');

    -- One row, where a card's hours wait. The hours are drawn into it once and read from it twice (as the hours and in the total), so no
    -- result depends on how often SQLite chooses to call the random function.
    CREATE TEMP TABLE draw(h INTEGER);
    INSERT INTO draw VALUES (0);

    -- The loop. Each card that is inserted prints itself (born), then inserts
    -- the next one while the total is still 40 or less. The WHERE is the stop rule.
    CREATE TEMP TRIGGER next_card AFTER INSERT ON main.demo_timecards
    BEGIN
        SELECT tcl('born', NEW.category, NEW.hours, NEW.running_total, NEW.iso_week);
        UPDATE draw SET h = tcl('hours') WHERE NEW.running_total <= 40;
        INSERT INTO demo_timecards(run_id, category, hours, running_total, iso_week, created_at)
        SELECT NEW.run_id,
               tcl('category', (SELECT count(*) FROM demo_timecards WHERE run_id = NEW.run_id) + 1),
               h, NEW.running_total + h, NEW.iso_week, datetime('now')
        FROM draw
        WHERE NEW.running_total <= 40;
    END;
}

# --gui: the widgets are rows too. One SELECT builds the window, by handing each
# row's text to uplevel #0, which runs it as Tcl at the global level.
set gui [expr {"--gui" in $argv}]
set seconds [expr {[set at [lsearch $argv --seconds]] >= 0 ? [lindex $argv $at+1] : 0}]
if {$gui} {
    package require Tk
    wm title . "Timecards - DEMO ONLY"
    db eval {
        SELECT tcl('uplevel', '#0', command) FROM ui ORDER BY id
    }
}
# The one statement that brings it to life: insert card 1 and the trigger does the rest.
db eval {SELECT tcl('init')}
db transaction {
    db eval {
        UPDATE draw SET h = tcl('hours');
        INSERT INTO main.demo_timecards(run_id, category, hours, running_total, iso_week, created_at)
        SELECT tcl('runid'), tcl('category', 1), h, h, tcl('week'), datetime('now')
        FROM draw
    }
}

db eval {
    SELECT count(*) AS entries, max(running_total) AS total
    FROM main.demo_timecards WHERE run_id = $::runid
} {
    puts "# committed total=$total entries=$entries DEMO ONLY"
}
puts "# every proc that ran was fetched from SQLite by unknown: [lsort $::loaded]"
puts "# the loop was a recursive trigger, and one INSERT started it"
if {$gui} {
    puts "# the window was built from [db eval {SELECT count(*) FROM ui}] rows of the ui table"
}
if {$gui} {
    if {$seconds > 0} {
        after [expr {$seconds * 1000}] {set done 1}
        vwait done
    } else {
        tkwait window .
    }
    # tclsh stays alive after the script ends while Tk's main window exists
    catch {destroy .}
}
db close
