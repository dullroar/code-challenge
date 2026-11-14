# DEMO ONLY. Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.
#
# Reference answer for exercise D ("Port the challenge"). The stunt: awk's own record loop is the
# program's only loop. The caller pipes in five records (`seq 5`); the pattern `total <= 40` is the
# stop rule: once the total passes 40 no later record matches, and the rest are read and ignored.
# There is no for, while, do, function or goto anywhere in this file.
#
#   seq 5 | awk -f timecards.awk
BEGIN {
    "od -An -N4 -tu4 /dev/urandom" | getline seed; srand(seed + 0)
    "date +%G-W%V" | getline week
    split("Meetings Coding Debugging Learning", cat, " ")
    dir = (ENVIRON["XDG_DATA_HOME"] != "" ? ENVIRON["XDG_DATA_HOME"] : ENVIRON["HOME"] "/.local/share") "/Awk"
    system("mkdir -p '" dir "'")
    sqlite = "sqlite3 -bail '" dir "/demo-timecards.db'"
    run = seed "-" NR
    print "CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY, run_id TEXT, category TEXT," \
          " hours INTEGER CHECK(hours BETWEEN 10 AND 19), running_total INTEGER, iso_week TEXT," \
          " created_at TEXT, demo_only INTEGER NOT NULL CHECK(demo_only = 1)); BEGIN;" | sqlite
    print "# DEMO ONLY run " run
}
total <= 40 {
    hours = 10 + int(rand() * 10)
    total += hours
    kind = cat[n % 4 + 1]; n++
    printf "%s\t%d\t%d\t%s\tDEMO ONLY\n", kind, hours, total, week
    printf "INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at,demo_only)" \
           " VALUES('%s','%s',%d,%d,'%s',datetime('now'),1);\n", run, kind, hours, total, week | sqlite
}
END {
    print "COMMIT;" | sqlite; close(sqlite)
    print "# committed total=" total " entries=" n " DEMO ONLY"
    print "# awk's record loop was the only loop; the stop rule was a pattern that stopped matching"
}
