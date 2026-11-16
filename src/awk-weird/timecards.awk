#!/usr/bin/gawk -f
# DEMO ONLY. Fictional timecards, written to a scratch SQLite file under
# XDG_DATA_HOME. Nothing here touches a real time-reporting system.
#
# Run:  gawk -f timecards.awk                (the random digits come from /dev/urandom)
#       gawk -f timecards.awk digits.txt     (or from any file: the digits in it ARE the dice)
#
# The challenge: add cards of 10-19 hours until the running total passes 40.
#
# THE STUNT.  There is no loop and no `if` below, and no random-number
# generator.  The input is /dev/urandom, awk's record separator is the regular
# expression [0-9], and so every "record" is a stretch of random bytes ending in
# a random digit, which gawk hands us in RT.  A digit is a die roll, a record is
# a card, and awk's own main loop is the loop.  The stop rule is a pattern with
# an `exit` action.  The whole challenge, minus the database, is one line:
#
#   gawk 'BEGIN{RS="[0-9]"; split("Meetings Coding Debugging Learning",C)}
#         {printf "%s\t%d\t%d\n", C[(NR-1)%4+1], h=10+RT, t+=h} t>40{exit}' /dev/urandom
#
# (The one-liner has no database, no week and no DEMO ONLY marker, and no
# guard for the empty last record of a finite file. The program below has all three.)
#
# GNU awk only: RT, a regular expression as RS, systime() and PROCINFO.

BEGIN {
    # Ask the clock first. RS applies to EVERY read, including getline from a
    # command: with RS="[0-9]" set, "date" would yield an empty record that ends
    # at the first digit of the year.
    "date +%G-W%V" | getline week
    close("date +%G-W%V")
    run = systime() "-" PROCINFO["pid"]
    t = n = 0                       # running total and card count (awk would default them to 0 anyway)

    RS = "[0-9]"                    # a record ends at a digit; RT holds that digit
    FS = ","                        # rule 3 builds a comma-separated record; FS splits it back
    split("Meetings Coding Debugging Learning", C, " ")

    # No file on the command line: add one. ARGC += (ARGC < 2) is 0 or 1, so no `if`.
    ARGV[ARGC] = "/dev/urandom"
    ARGC += (ARGC < 2)

    dir = (ENVIRON["XDG_DATA_HOME"] != "" ? ENVIRON["XDG_DATA_HOME"] : ENVIRON["HOME"] "/.local/share") "/AwkWeird"
    system("mkdir -p '" dir "'")
    sql = "sqlite3 '" dir "/demo-timecards.db'"
    print "BEGIN; CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id TEXT," \
          "category TEXT,hours INTEGER,running_total INTEGER,iso_week TEXT,created_at TEXT," \
          "demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));" | sql
    print "# DEMO ONLY run " run
}

# Rule 1: the last record of a finite file has no digit after it (RT is empty). Not a die roll.
RT == "" { next }

# Rule 2: the die. 10 + a digit is 10..19, and t is the running total.
# An assignment is an expression, so the hours and the sum are one statement.
{ t += h = 10 + RT }

# Rule 3: the card, as one comma-separated record. Assigning $0 re-splits it into fields.
{ $0 = C[n++ % 4 + 1] "," h "," t "," week }

# Rule 4: the same fields, as SQL, down a pipe to sqlite3.
{ print "INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES('" run "','" $1 "'," $2 "," $3 ",'" $4 "',datetime('now'));" | sql }

# Rule 5: the same fields again, for people. Setting OFS and then $1 = $1 forces awk
# to rebuild $0, now joined by tabs instead of commas.
{ OFS = "\t"; $1 = $1; print $0, "DEMO ONLY" }

# Rule 6: the stop rule. exit runs END; the card that crossed the line has already been written.
t > 40 { exit }

END {
    print "COMMIT;" | sql
    close(sql)
    print "# committed total=" t " entries=" n " DEMO ONLY"
    print "# the loop was awk's main loop over /dev/urandom, RS=[0-9] made each digit a die roll, and t > 40 { exit } stopped it"
}
