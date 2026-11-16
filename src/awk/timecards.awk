#!/usr/bin/awk -f
# DEMO ONLY. Fictional timecards, written to a scratch SQLite file under
# XDG_DATA_HOME. Nothing here touches a real time-reporting system.
#
# Run:  awk -f timecards.awk
#
# The challenge: add cards of 10-19 hours (Meetings, Coding, Debugging,
# Learning, round and round) until the running total passes 40.  Portable
# POSIX awk: it runs unchanged under gawk, mawk, the one-true-awk and
# busybox awk.  There is no input file, so the whole program is the BEGIN
# rule; the weird version (../awk-weird) lets awk's main loop do the work.

# The text of a command's first output line.
function command_line(command,    line) {
    line = ""
    command | getline line
    close(command)
    return line
}

# TEXT as one shell word.  split() on the quote avoids awk's replacement-string
# escape rules, which differ between implementations.
function shell_quote(text,    parts, n, i, quoted) {
    n = split(text, parts, "'")
    quoted = parts[1]
    for (i = 2; i <= n; i++)
        quoted = quoted "'\\''" parts[i]
    return "'" quoted "'"
}

# TEXT as an SQL string literal: doubling the quotes is the whole rule.
function sql_quote(text) {
    gsub(/'/, "''", text)
    return "'" text "'"
}

# 10..19.  rand() is in [0,1), so int() of it times 10 is 0..9.
function random_hours() {
    return HOURS_MIN + int(rand() * (HOURS_MAX - HOURS_MIN + 1))
}

# One tab-separated row.  Assigning to a field rebuilds $0 joined with OFS,
# so print with no arguments prints the finished record.
function print_row(name, worked, running, iso) {
    $0 = ""
    $1 = name
    $2 = worked
    $3 = running
    $4 = iso
    $5 = "DEMO ONLY"
    print
}

function sql_insert(run_id, name, worked, running, iso) {
    return sprintf("INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) " \
                   "VALUES(%s,%s,%d,%d,%s,datetime('now'));",
                   sql_quote(run_id), sql_quote(name), worked, running, sql_quote(iso))
}

BEGIN {
    HOURS_MIN = 10
    HOURS_MAX = 19
    LIMIT = 40
    total = 0
    cards = 0
    OFS = "\t"
    split("Meetings Coding Debugging Learning", CATEGORY, " ")

    # A seed from the OS, and a run id made from the clock and the seed.
    seed = command_line("od -An -N4 -tu4 /dev/urandom") + 0
    srand(seed)
    run = command_line("date +%s") "-" seed
    week = command_line("date +%G-W%V")

    # Where the scratch database lives.
    dir = ENVIRON["XDG_DATA_HOME"]
    if (dir == "")
        dir = ENVIRON["HOME"] "/.local/share"
    dir = dir "/Awk"
    system("mkdir -p " shell_quote(dir))
    sqlite = "sqlite3 " shell_quote(dir "/demo-timecards.db")

    # The DEMO ONLY rule lives in the table: CHECK(demo_only=1).
    print "BEGIN;" | sqlite
    print "CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id TEXT," \
          "category TEXT,hours INTEGER,running_total INTEGER,iso_week TEXT,created_at TEXT," \
          "demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));" | sqlite

    print "# DEMO ONLY run " run

    # The challenge.  The test is made before each draw, so the card that
    # crosses the line is the last one added.
    while (total <= LIMIT) {
        hours = random_hours()
        total += hours
        category = CATEGORY[cards++ % 4 + 1]
        print_row(category, hours, total, week)
        print sql_insert(run, category, hours, total, week) | sqlite
    }

    print "COMMIT;" | sqlite
    if (close(sqlite) != 0) {
        print "sqlite3 reported an error" > "/dev/stderr"
        exit 1
    }
    print "# committed total=" total " entries=" cards " DEMO ONLY"
    print "# a BEGIN-only awk program: arrays, a pipe to sqlite3, and fields rebuilding each row"
}
