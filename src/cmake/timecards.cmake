# DEMO ONLY. Fictional timecards, written to a scratch SQLite file under XDG_DATA_HOME. See README.md.
#
# Run with:  cmake -P timecards.cmake        (add -DPOP=1 to do it in a new Windows Terminal window)
#
#     for ( seed ; test ; iterate ) ;
#
# The whole program is ONE bodiless while(). Its condition is a regex match (MATCHES), and a successful match
# leaves its captures in CMAKE_MATCH_1..5. Those are ordinary variables, and while() re-expands its condition on
# every pass, so each pass builds its subject string and its pattern out of the previous pass's captures. That is
# the machine: the registers are the state, the lookup table for the hours is in the subject, the stop rule is a
# 41-character literal, and the loop ends when the match says no. There is no function(), macro(), math(),
# list(GET) or cmake_language() in the loop, and nothing in its body, because it has none.
#
# The host only seeds the registers (a tape of random digits) before it and reports after it.
cmake_minimum_required(VERSION 3.19)

if(POP)
  # No semicolons anywhere in this command line: wt.exe treats them as its own subcommand separator.
  execute_process(COMMAND wt.exe -w new new-tab --title "DEMO ONLY"
                          wsl.exe -d $ENV{WSL_DISTRO_NAME} --cd ${CMAKE_CURRENT_LIST_DIR}
                          -e ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_FILE})
  return()
endif()

# ---- seed: the registers, and a tape of random digits (one digit = one card's hours-minus-ten) ---------------
string(RANDOM LENGTH 1 ALPHABET 0123456789 first_digit)
string(RANDOM LENGTH 8 ALPHABET 0123456789 more_digits)
set(CMAKE_MATCH_1 "")                  # total so far, in unary (a run of x's)
set(CMAKE_MATCH_2 "${first_digit}")    # the digit peeked last pass: this pass's card
set(CMAKE_MATCH_3 "${more_digits}")    # the rest of the tape
set(CMAKE_MATCH_4 "")                  # finished cards, in unary, dash-separated
set(CMAKE_MATCH_5 "")                  # hours of the card added last pass, in unary

# ---- the one statement ------------------------------------------------------------------------------------------------
# 1st test: NOT (total so far + last card is 41 or more x's): the stop rule, "exactly 40 continues". It is first
#           because a match that fails clears the registers and one that succeeds rewrites them, so the main match
#           must run last for its captures to be the ones that survive.
# 2nd test: build "<total>|<tape>|<log>||0:<10 x's>|1:<11 x's>|...|9:<19 x's>|" from the last pass's registers, then
#           match it with a pattern that peeks the next digit off the tape (groups 2,3), keeps the log (4), and
#           looks up this card's hours in the table by the digit the pattern splices in from last pass (5).
while(NOT "${CMAKE_MATCH_1}${CMAKE_MATCH_5}" MATCHES "^xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      AND "${CMAKE_MATCH_1}${CMAKE_MATCH_5}|${CMAKE_MATCH_3}|${CMAKE_MATCH_4}${CMAKE_MATCH_5}-||\
0:xxxxxxxxxx|\
1:xxxxxxxxxxx|\
2:xxxxxxxxxxxx|\
3:xxxxxxxxxxxxx|\
4:xxxxxxxxxxxxxx|\
5:xxxxxxxxxxxxxxx|\
6:xxxxxxxxxxxxxxxx|\
7:xxxxxxxxxxxxxxxxx|\
8:xxxxxxxxxxxxxxxxxx|\
9:xxxxxxxxxxxxxxxxxxx|"
          MATCHES "^(x*)\\|([0-9])([0-9]*)\\|([^|]*)\\|.*\\|${CMAKE_MATCH_2}:(x*)\\|")
endwhile()

# ---- report: the cards are in the log, in unary; lengths are hours -----------------------------------------------
string(REGEX MATCHALL "x+" cards "${CMAKE_MATCH_4}")
list(LENGTH cards n)
set(categories Meetings Coding Debugging Learning Meetings)   # a fifth card (four 10s = exactly 40) wraps to Meetings
list(SUBLIST categories 0 ${n} categories)                  # ZIP_LISTS runs to the longer list
set(acc "")
set(rows "")
foreach(unary category IN ZIP_LISTS cards categories)
  string(APPEND acc "${unary}")
  string(LENGTH "${unary}" hours)
  string(LENGTH "${acc}" running)
  list(APPEND rows "${category}\t${hours}\t${running}")
endforeach()
string(LENGTH "${acc}" total)

# ---- ISO week. string(TIMESTAMP) knows %V but not %G, so the ISO *year* is fixed up by hand ----------------
string(TIMESTAMP stamp "%Y %m %V")
string(REPLACE " " ";" stamp "${stamp}")
list(GET stamp 0 year)
list(GET stamp 1 month)
list(GET stamp 2 week)
if(month STREQUAL "12" AND week STREQUAL "01")
  math(EXPR year "${year} + 1")
elseif(month STREQUAL "01" AND week GREATER 51)
  math(EXPR year "${year} - 1")
endif()
set(iso_week "${year}-W${week}")

# ---- SQLite (same schema as the other entries) ------------------------------------------------------------------
if(DEFINED ENV{XDG_DATA_HOME} AND NOT "$ENV{XDG_DATA_HOME}" STREQUAL "")
  set(data "$ENV{XDG_DATA_HOME}")
else()
  set(data "$ENV{HOME}/.local/share")
endif()
set(dir "${data}/CmakeChallenge")
set(db "${dir}/demo-timecards.db")
file(MAKE_DIRECTORY "${dir}")

file(WRITE "${dir}/.init.sql" [[
CREATE TABLE IF NOT EXISTS runs(id INTEGER PRIMARY KEY,started_at TEXT);
CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id INTEGER,category TEXT,hours INTEGER CHECK(hours BETWEEN 10 AND 19),running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));
CREATE TABLE IF NOT EXISTS stop_rule(ok INTEGER CONSTRAINT "stop rule fired: total exceeds 40" CHECK(ok=1));
INSERT INTO runs(started_at) VALUES(datetime('now','localtime'));
SELECT printf('# DEMO ONLY run %d',last_insert_rowid());
]])
execute_process(COMMAND sqlite3 -noheader "${db}" INPUT_FILE "${dir}/.init.sql")

set(sql "")
foreach(card IN LISTS rows)
  string(REPLACE "\t" ";" f "${card}")
  list(GET f 0 category)
  list(GET f 1 hours)
  list(GET f 2 running)
  file(APPEND /dev/stdout "${card}\t${iso_week}\tDEMO ONLY\n")
  string(APPEND sql "INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES((SELECT max(id) FROM runs),'${category}',${hours},${running},'${iso_week}',datetime('now','localtime'));\n")
endforeach()
# The stop rule, witnessed by SQLite: inserting "total <= 40" into a CHECK(ok=1) column fails when it should stop.
string(APPEND sql "INSERT INTO stop_rule SELECT coalesce((SELECT max(running_total) FROM demo_timecards WHERE run_id=(SELECT max(id) FROM runs)),0)<=40;\nDELETE FROM stop_rule;\n")
file(WRITE "${dir}/.rows.sql" "${sql}")
execute_process(COMMAND sqlite3 "${db}" INPUT_FILE "${dir}/.rows.sql")   # its CHECK error goes to stderr, on purpose
file(REMOVE "${dir}/.init.sql" "${dir}/.rows.sql")

file(APPEND /dev/stdout "# committed total=${total} entries=${n} DEMO ONLY\n")
file(APPEND /dev/stdout "# an empty while() went round ${n} times, once per card\n")

# ---- the glow, only on a real terminal (CMake's own realpath of its stdout is /dev/pts/N, not a pipe) -----
file(REAL_PATH /proc/self/fd/1 stdout_path)
if(stdout_path MATCHES "^/dev/(pts|tty)")
  string(ASCII 27 ESC)
  set(ramp 232 234 236 238 240 242 244 246 248 250 252 254 254 252 250 248 246 244 242 240 238 236 234 232 0)
  set(first TRUE)
  foreach(shade IN LISTS ramp)
    set(up "")
    if(NOT first)
      set(up "${ESC}[1A")
    endif()
    set(first FALSE)
    if(shade EQUAL 0)
      file(APPEND /dev/stdout "${up}${ESC}[2K\n")
    else()
      if(shade GREATER 242)
        set(fg 30)
      else()
        set(fg 97)
      endif()
      file(APPEND /dev/stdout "${up}${ESC}[2K${ESC}[48;5;${shade}m${ESC}[${fg}m  DEMO ONLY  ${ESC}[0m\n")
    endif()
    execute_process(COMMAND ${CMAKE_COMMAND} -E sleep 0.06)
  endforeach()
endif()
