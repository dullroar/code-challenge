\ DEMO ONLY. Fictional timecards, written to a scratch SQLite file under XDG_DATA_HOME.
\ Run: gforth timecards.fs
require random.fs
variable total   variable cards   variable rid   variable wkn   create wk 16 allot   0 value sqlf

: category ( n -- c-addr u )  4 mod 10 * s" Meetings  Coding    Debugging Learning  " drop + 10 -trailing ;
: hours ( -- n )  10 random 10 + ;
: week ( -- )  s" date +%G-W%V" r/o open-pipe throw >r  wk 16 r@ read-line throw drop wkn !  r> close-pipe 2drop ;
: sqlite ( -- )  s\" d=${XDG_DATA_HOME:-$HOME/.local/share}/Forth; mkdir -p \"$d\"; exec sqlite3 \"$d/demo-timecards.db\"" w/o open-pipe throw to sqlf ;
: schema ( -- )  ." CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));" cr ." BEGIN;" cr ;
: post   ( h -- )  ." INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES('" rid @ 0 u.r ." ','" cards @ 1- category type ." '," 0 .r ." ," total @ 0 .r ." ,'" wk wkn @ type ." ',datetime('now'));" cr ;
: commit ( -- )  ." COMMIT;" cr ;
: card ( -- )
  hours dup total +!  1 cards +!
  cards @ 1- category type 9 emit  dup 0 .r 9 emit  total @ 0 .r 9 emit  wk wkn @ type 9 emit ." DEMO ONLY" cr
  ['] post sqlf outfile-execute ;
: run ( -- )  begin card total @ 40 > until ;

utime drop dup seed ! rid !  week  sqlite
." # DEMO ONLY run " rid @ 0 u.r cr
' schema sqlf outfile-execute
run
' commit sqlf outfile-execute  sqlf close-pipe 2drop
." # committed total=" total @ 0 .r ."  entries=" cards @ 0 .r ."  DEMO ONLY" cr
." # begin ... until, and an outfile-execute to point the output at SQLite" cr
bye
