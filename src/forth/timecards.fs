\ DEMO ONLY. Fictional timecards, written to a scratch SQLite file under XDG_DATA_HOME.
\ Nothing here touches a real time-reporting system.
\
\ Run:  gforth timecards.fs
\
\ The challenge: add 10-19 hour cards (Meetings, Coding, Debugging, Learning,
\ round and round) until the running total passes 40.  In Forth that is one
\ BEGIN ... UNTIL in the word RUN.  Everything else is small words that each
\ do one thing, built bottom-up so every word is made of the ones above it.
\
\ Conventions: every word has a stack comment ( before -- after ); a trailing $
\ means "a string on the stack as c-addr u"; words that print start with a dot.

require random.fs

\ ---------------------------------------------------------------- state

variable total                      \ running total of hours
variable cards                      \ cards written so far
variable run-id                     \ makes this run's rows findable in the table
variable week-len                   \ length of the ISO week text in WEEK-BUF
create week-buf 16 allot            \ "2026-W46" and its newline fit easily
0 value sqlite                      \ file id of the pipe to sqlite3

\ ---------------------------------------------------------------- categories

\ One tiny word per category, and a table of their execution tokens.
\ ' (tick) turns a name into an xt; EXECUTE runs it and yields the string.
: meetings   ( -- c-addr u )  s" Meetings" ;
: coding     ( -- c-addr u )  s" Coding" ;
: debugging  ( -- c-addr u )  s" Debugging" ;
: learning   ( -- c-addr u )  s" Learning" ;

create categories  ' meetings , ' coding , ' debugging , ' learning ,

: category$  ( n -- c-addr u )  4 mod cells categories + @ execute ;

\ ---------------------------------------------------------------- numbers and text

: random-hours  ( -- n )  10 random 10 + ;               \ 10 random is 0..9
: u$            ( u -- c-addr u )  0 <# #s #> ;          \ number to text, no padding
: .num          ( n -- )  0 .r ;                         \ print with no leading space
: tab           ( -- )  9 emit ;
: quoted        ( c-addr u -- )  [char] ' emit type [char] ' emit ;
: comma         ( -- )  [char] , emit ;

: week$         ( -- c-addr u )  week-buf week-len @ ;

\ Ask date(1) for the ISO-8601 week rather than reimplementing the calendar.
: read-week     ( -- )
  s" date +%G-W%V" r/o open-pipe throw >r
  week-buf 16 r@ read-line throw drop week-len !
  r> close-pipe throw drop ;

\ ---------------------------------------------------------------- SQLite

\ Start sqlite3 with a pipe on its stdin.  The shell is used only to pick (and
\ create) the scratch directory.  The DEMO ONLY rule lives in the table itself:
\ CHECK(demo_only=1) means a non-demo row cannot be stored.
: open-sqlite   ( -- )
  s\" d=${XDG_DATA_HOME:-$HOME/.local/share}/Forth; mkdir -p \"$d\"; exec sqlite3 \"$d/demo-timecards.db\""
  w/o open-pipe throw to sqlite ;

: close-sqlite  ( -- )  sqlite close-pipe throw abort" sqlite3 reported an error" ;

\ OUTFILE-EXECUTE runs an xt with all output redirected to a file id.  That one
\ word is how ordinary printing words (." CR TYPE) become SQL.
: >sqlite       ( xt -- )  sqlite outfile-execute ;

: .schema       ( -- )
  ." CREATE TABLE IF NOT EXISTS demo_timecards("
  ." id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,"
  ." running_total INTEGER,iso_week TEXT,created_at TEXT,"
  ." demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));" cr
  ." BEGIN;" cr ;

: .commit       ( -- )  ." COMMIT;" cr ;

\ Safe only because every value is a number we computed or one of four fixed words.
: .insert       ( hours -- )
  ." INSERT INTO demo_timecards"
  ." (run_id,category,hours,running_total,iso_week,created_at) VALUES("
  run-id @ u$ quoted comma
  cards @ 1- category$ quoted comma
  .num comma
  total @ .num comma
  week$ quoted comma
  ." datetime('now'));" cr ;

\ ---------------------------------------------------------------- one card

: .row          ( hours -- )
  cards @ 1- category$ type tab
  .num tab
  total @ .num tab
  week$ type tab
  ." DEMO ONLY" cr ;

: card          ( -- )
  random-hours
  dup total +!  1 cards +!
  dup .row
  ['] .insert >sqlite ;                                  \ .insert eats the hours left on the stack

: over-40?      ( -- flag )  total @ 40 > ;

\ The whole challenge.  BEGIN ... UNTIL repeats until the flag is true.
: run           ( -- )  begin card over-40? until ;

\ ---------------------------------------------------------------- main

: reset         ( -- )  0 total !  0 cards !  utime drop dup seed ! run-id ! ;

: main          ( -- )
  reset  read-week  open-sqlite
  ." # DEMO ONLY run " run-id @ .num cr
  ['] .schema >sqlite
  run
  ['] .commit >sqlite
  close-sqlite
  ." # committed total=" total @ .num ."  entries=" cards @ .num ."  DEMO ONLY" cr
  ." # begin ... until, and an outfile-execute to point the output at SQLite" cr ;

main
bye
