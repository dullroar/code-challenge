#!/usr/bin/env tclsh
# DEMO ONLY. Fictional timecards, written to a scratch SQLite file under
# XDG_DATA_HOME. Nothing here touches a real time-reporting system.
#
# Run:  tclsh timecards.tcl            (text)
#       tclsh timecards.tcl --gui      (also a Tk window; add --seconds N to close it by itself)
#
# The challenge: add cards of 10-19 hours (Meetings, Coding, Debugging,
# Learning, round and round) until the running total passes 40.  In Tcl that
# is one while loop in the proc "draw".  Everything else is plumbing: a card
# is a dict, the database is a Tcl command, the window is optional.

package require Tcl 8.6
package require sqlite3

namespace eval timecards {
    variable categories {Meetings Coding Debugging Learning}
    variable minHours 10
    variable maxHours 19
    variable limit 40
}

# ---------------------------------------------------------------- the challenge

# One random number of hours, minHours..maxHours.
proc timecards::randomHours {} {
    variable minHours
    variable maxHours
    expr {$minHours + int(rand() * ($maxHours - $minHours + 1))}
}

# Deal cards until the running total is over the limit, and return them as a
# list of dicts. The card that crosses the line is kept, because the test is
# made before the next card is drawn, not after.
proc timecards::draw {} {
    variable categories
    variable limit
    set cards {}
    set total 0
    while {$total <= $limit} {
        set hours [randomHours]
        incr total $hours
        set category [lindex $categories [expr {[llength $cards] % [llength $categories]}]]
        lappend cards [dict create category $category hours $hours total $total]
    }
    return $cards
}

# ---------------------------------------------------------------- the calendar

# The ISO-8601 week of right now, e.g. 2026-W46. clock knows %G and %V.
proc timecards::isoWeek {} {
    clock format [clock seconds] -format %G-W%V
}

# ---------------------------------------------------------------- SQLite

proc timecards::dataDir {} {
    if {[info exists ::env(XDG_DATA_HOME)] && $::env(XDG_DATA_HOME) ne ""} {
        set base $::env(XDG_DATA_HOME)
    } else {
        set base [file join $::env(HOME) .local share]
    }
    file join $base Tcl
}

# Save every card in one transaction. The DEMO ONLY rule lives in the table:
# CHECK(demo_only=1) means a non-demo row cannot be stored.
#
# In "db eval {... $runId ...}" Tcl variables are *bound parameters*, not text
# pasted into the SQL, so quoting is never our problem. "dict with" turns a
# card's keys (category, hours, total) into local variables to be bound.
proc timecards::save {runId week cards} {
    set dir [dataDir]
    file mkdir $dir
    sqlite3 [namespace current]::db [file join $dir demo-timecards.db]
    try {
        db eval {
            CREATE TABLE IF NOT EXISTS demo_timecards(
                id INTEGER PRIMARY KEY, run_id TEXT, category TEXT, hours INTEGER,
                running_total INTEGER, iso_week TEXT, created_at TEXT,
                demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1))
        }
        db transaction {
            foreach card $cards {
                dict with card {
                    db eval {
                        INSERT INTO demo_timecards
                            (run_id, category, hours, running_total, iso_week, created_at)
                        VALUES ($runId, $category, $hours, $total, $week, datetime('now'))
                    }
                }
            }
        }
    } finally {
        db close
    }
}

# ---------------------------------------------------------------- display

proc timecards::row {card week} {
    dict with card {
        join [list $category $hours $total $week {DEMO ONLY}] \t
    }
}

# An optional Tk window: a table of the cards and the total. Tk is only
# loaded when asked for, so the text version runs on a machine with no display.
proc timecards::showWindow {cards week seconds} {
    package require Tk
    wm title . "Timecards - DEMO ONLY"
    ttk::treeview .cards -columns {category hours total week} -show headings -height 6
    foreach column {category hours total week} {
        .cards heading $column -text [string totitle $column]
        .cards column $column -width 110 -anchor center
    }
    foreach card $cards {
        dict with card {
            .cards insert {} end -values [list $category $hours $total $week]
        }
    }
    ttk::label .note -text "DEMO ONLY: [llength $cards] cards, total [dict get [lindex $cards end] total]"
    pack .cards -fill both -expand 1 -padx 8 -pady 8
    pack .note -pady {0 8}
    if {$seconds > 0} {
        after [expr {$seconds * 1000}] {set ::timecards::closed 1}
        bind . <Destroy> {set ::timecards::closed 1}
        vwait ::timecards::closed
    } else {
        tkwait window .
    }
    # A tclsh that has loaded Tk does not exit at the end of the script while
    # the main window exists, so close it explicitly.
    catch {destroy .}
}

# ---------------------------------------------------------------- main

proc timecards::main {argv} {
    set gui 0
    set seconds 0
    while {[llength $argv]} {
        set argv [lassign $argv option]
        switch -- $option {
            --gui {set gui 1}
            --seconds {set argv [lassign $argv seconds]}
            default {puts stderr "usage: timecards.tcl ?--gui ?--seconds N??"; exit 2}
        }
    }

    expr {srand([clock microseconds] ^ [pid])}
    set runId [clock seconds]-[pid]
    set week [isoWeek]
    set cards [draw]

    save $runId $week $cards
    puts "# DEMO ONLY run $runId"
    foreach card $cards {
        puts [row $card $week]
    }
    puts "# committed total=[dict get [lindex $cards end] total] entries=[llength $cards] DEMO ONLY"
    puts "# one while loop, cards as dicts, and db eval binding Tcl variables as SQL parameters"
    if {$gui} {
        showWindow $cards $week $seconds
    }
}

# Run main only when this file is the script, not when it is sourced for testing.
if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    timecards::main $argv
}
