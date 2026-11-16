dnl DEMO ONLY. Fictional timecards, written to a scratch SQLite file under
dnl XDG_DATA_HOME. Nothing here touches a real time-reporting system.
dnl
dnl Run:  m4 timecards.m4
dnl
dnl The challenge: add cards of 10-19 hours (Meetings, Coding, Debugging,
dnl Learning, round and round) until the running total passes 40.  m4 has no
dnl loop statement and no variables: it has macros, and what a macro expands
dnl to is scanned again.  So the loop is a macro that ends by calling itself,
dnl and the stop rule is the ifelse that decides whether it does.
dnl
dnl This file uses GNU m4 (1.4.x or later).  GNU-only features, each marked
dnl where it is used: esyscmd (capture a command's output), format, and
dnl eval being 32-bit.  Every macro here starts with tc_ so that none of them
dnl can collide with a word in the SQL text, which m4 would helpfully expand.
dnl
dnl ---- 1. Make m4 safe for our text --------------------------------------
dnl By default # starts a comment, and a comment is copied through without
dnl expanding macros: that would eat our "# DEMO ONLY" lines.  And ' is the
dnl closing quote, which SQL strings need.  Fix both before anything else.
changecom()dnl
changequote([, ])dnl
dnl Everything until divert(0) below is definitions; send any stray output
dnl (such as the newline after each define) to diversion -1, i.e. nowhere.
divert(-1)

dnl ---- 2. State: macros are the variables ---------------------------------
define([tc_n], 0)
define([tc_total], 0)

dnl A seed from the OS: 3 random bytes as a decimal number.  [GNU: esyscmd]
dnl Scaled so that it fits m4's 32-bit eval, and never 0.  ifdef lets you pin
dnl it (and the week) from the command line: m4 -Dtc_seed=12345 -Dtc_week=2026-W01 timecards.m4
ifdef([tc_seed], [],
  [define([tc_seed], eval(esyscmd([od -An -N3 -tu4 /dev/urandom | tr -d ' \n']) * 127 + 1))])
define([tc_run], esyscmd([date +%s | tr -d '\n'])-tc_seed)
ifdef([tc_week], [], [define([tc_week], esyscmd([date +%G-W%V | tr -d '\n']))])
define([tc_tab], format([%c], 9))   dnl [GNU: format]

dnl ---- 3. A random number generator, in m4 arithmetic ----------------------
dnl Park-Miller "minimal standard": seed = 16807 * seed mod (2^31 - 1).
dnl Schrage's trick keeps every intermediate value inside 32 bits, which is
dnl all eval has: 16807 * 127773 + 2836 = 2^31 - 1.
define([tc_next],
  [define([tc_seed], eval(16807 * (tc_seed % 127773) - 2836 * (tc_seed / 127773)))dnl
ifelse(eval(tc_seed < 0), 1, [define([tc_seed], eval(tc_seed + 2147483647))])])

dnl ---- 4. Text-building helpers --------------------------------------------
dnl tc_category(N): card N's category.  ifelse is "if arg1 = arg2 then arg3",
dnl and after that it continues in groups of THREE (arg1 again, arg2, arg3),
dnl with a lone last argument as the else.  So the thing being tested has to be
dnl repeated in every group: tc_pick gets the number as $1 and repeats it.
define([tc_pick],
  [ifelse($1, 0, [Meetings], $1, 1, [Coding], $1, 2, [Debugging], [Learning])])
define([tc_category], [tc_pick(eval(($1 - 1) % 4))])

dnl The [] in the bodies below are empty quotes: they split a $1 from the
dnl macro name after it, which would otherwise glue into one word.
define([tc_row], [$1[]tc_tab[]$2[]tc_tab[]$3[]tc_tab[]tc_week[]tc_tab[]DEMO ONLY])
define([tc_insert],
  [INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES('tc_run','$1',$2,$3,'tc_week',datetime('now'));
])

dnl The SQL script is a macro that grows: defn gives back a macro's text,
dnl quoted, so appending is "redefine yourself as yourself plus more".
define([tc_sql], [BEGIN;
CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));
])
define([tc_append], [define([tc_sql], defn([tc_sql])[$1])])

dnl ---- 5. The challenge ----------------------------------------------------
dnl One card: draw, add, remember the INSERT, print the row, then either stop
dnl or expand ourselves again.  The text a macro returns is rescanned, so the
dnl last word of tc_card is what makes it a loop.
define([tc_card],
  [tc_next()dnl
define([tc_hours], eval(10 + tc_seed / 1024 % 10))dnl
define([tc_n], incr(tc_n))dnl
define([tc_total], eval(tc_total + tc_hours))dnl
tc_append(tc_insert(tc_category(tc_n), tc_hours, tc_total))dnl
tc_row(tc_category(tc_n), tc_hours, tc_total)
ifelse(eval(tc_total > 40), 1, [], [tc_card()])])

dnl ---- 6. Run it -----------------------------------------------------------
divert(0)dnl
# DEMO ONLY run tc_run
tc_card()dnl
# committed total=tc_total entries=tc_n DEMO ONLY
# no loop statement: [tc_card] expands itself again until ifelse says stop, and m4 is the whole program
divert(-1)

dnl Save: hand the finished script to sqlite3 through the shell.  The shell
dnl only picks the folder and runs sqlite3; every byte of SQL was made by m4.
dnl The terminator is quoted so the shell leaves the SQL alone.  [syscmd is POSIX]
syscmd([d="${XDG_DATA_HOME:-$HOME/.local/share}/M4"; mkdir -p "$d" && sqlite3 "$d/demo-timecards.db" <<'END_OF_DEMO_SQL'
]defn([tc_sql])[COMMIT;
END_OF_DEMO_SQL
])
ifelse(sysval, 0, [], [errprint([sqlite3 failed
])m4exit(1)])
