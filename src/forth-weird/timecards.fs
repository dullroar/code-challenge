\ DEMO ONLY. Fictional timecards, written to a scratch SQLite file under XDG_DATA_HOME.
\ Nothing here touches a real time-reporting system.
\
\ Run:  gforth timecards.fs
\
\ THE STUNT: this program is a two-register machine.
\   * The memory is the data stack.  There is not one VARIABLE in the file.
\   * The program counter is >IN, the text interpreter's parse position.
\ There is no BEGIN, UNTIL, WHILE, IF, DO, CASE or recursion anywhere.  The
\ "loop" is a line of source text that the interpreter reads, and which is
\ read AGAIN because REWIND? moves >IN backwards.  Between passes the running
\ total, the card number and the rewind target live on the stack, untouched.
\
\ The one line to read is the one marked  <== THE LOOP  near the bottom.

require random.fs

0 value run-id                      \ identifies this run's rows in the table
0 value sqlite                      \ file id of the pipe to sqlite3
create week-buf 16 allot            \ the ISO week text, set once and never changed

\ ---------------------------------------------------------------- plumbing

: meetings   ( -- c-addr u )  s" Meetings" ;
: coding     ( -- c-addr u )  s" Coding" ;
: debugging  ( -- c-addr u )  s" Debugging" ;
: learning   ( -- c-addr u )  s" Learning" ;
create categories  ' meetings , ' coding , ' debugging , ' learning ,
: category$  ( n -- c-addr u )  4 mod cells categories + @ execute ;

: random-hours  ( -- n )  10 random 10 + ;
: u$            ( u -- c-addr u )  0 <# #s #> ;
: .num          ( n -- )  0 .r ;
: tab           ( -- )  9 emit ;
: quoted        ( c-addr u -- )  [char] ' emit type [char] ' emit ;
: comma         ( -- )  [char] , emit ;
: 3dup          ( a b c -- a b c a b c )  2 pick 2 pick 2 pick ;

: read-week     ( -- )
  s" date +%G-W%V" r/o open-pipe throw >r
  week-buf 16 r@ read-line throw 2drop
  r> close-pipe throw drop ;
\ %G-W%V is always eight characters (2026-W46), so no length needs remembering.
: week$         ( -- c-addr u )  week-buf 8 ;

: open-sqlite   ( -- )
  s\" d=${XDG_DATA_HOME:-$HOME/.local/share}/ForthWeird; mkdir -p \"$d\"; exec sqlite3 \"$d/demo-timecards.db\""
  w/o open-pipe throw to sqlite ;
: close-sqlite  ( -- )  sqlite close-pipe throw abort" sqlite3 reported an error" ;
: >sqlite       ( xt -- )  sqlite outfile-execute ;

: .schema       ( -- )
  ." CREATE TABLE IF NOT EXISTS demo_timecards("
  ." id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,"
  ." running_total INTEGER,iso_week TEXT,created_at TEXT,"
  ." demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));" cr
  ." BEGIN;" cr ;
: .commit       ( -- )  ." COMMIT;" cr ;

\ n is the card's position (it picks the category), h its hours, t the total after it.
: .insert       ( n h t -- )
  ." INSERT INTO demo_timecards"
  ." (run_id,category,hours,running_total,iso_week,created_at) VALUES("
  run-id u$ quoted comma
  2 pick category$ quoted comma
  swap .num comma
  .num comma
  week$ quoted comma
  ." datetime('now'));" cr
  drop ;                                                  \ the n left underneath
: .row          ( n h t -- )
  >r swap category$ type tab
  .num tab
  r> .num tab
  week$ type tab
  ." DEMO ONLY" cr ;

\ ---------------------------------------------------------------- the machine

\ One card.  The state in is ( n total ); the state out is ( n+1 total' ).
: card          ( n total -- n' total' )
  random-hours tuck +                                     ( n h t )
  3dup .row
  3dup ['] .insert >sqlite
  >r drop 1+ r> ;                                         ( n+1 t )

\ Run a card while the anchor rides underneath it on the return stack.
: step          ( n total anchor -- n' total' anchor )  >r card r> ;

\ The jump.  If the total is still 40 or less, set >IN back to ANCHOR; otherwise
\ leave it alone.  No branch: the flag (-1 or 0) masks the distance to travel.
: rewind?        ( n total anchor -- n total anchor )
  over 41 <                                               ( ... flag )
  over >in @ - and  >in @ + >in ! ;

\ ---------------------------------------------------------------- main

utime drop dup seed ! to run-id   read-week   open-sqlite
." # DEMO ONLY run " run-id .num cr
' .schema >sqlite
0 0 >in @ step rewind?                                     \ <== THE LOOP  ( n total anchor )
drop                                                      \ the anchor has done its job
' .commit >sqlite   close-sqlite
swap ." # committed total=" over .num ."  entries=" .num ."  DEMO ONLY" cr
drop
." # no loop word anywhere: the text interpreter was rewound until the total passed 40" cr
bye
