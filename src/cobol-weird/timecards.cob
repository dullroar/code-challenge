      * DEMO ONLY. Fictional timecards, written to a scratch SQLite file
      * under XDG_DATA_HOME. Nothing here touches a real time-reporting
      * system.
      *
      * Run:  cobc -xj timecards.cob
      *
      * The same challenge as ../cobol, with no IF, no PERFORM, no
      * EVALUATE and no UNTIL anywhere. Control flow is GO TO and the
      * ALTER statement, which rewrites where a GO TO jumps while the
      * program runs. ALTER was declared obsolete in 1985 and deleted
      * from the standard in 2002; GnuCOBOL still runs it, and warns.
      *
      * - The loop is one paragraph, NEXT-CARD, holding one GO TO.
      * - Each category's paragraph ALTERs that GO TO to point at the
      *   next category. That is the round-and-round.
      * - The stop rule is a two-digit field, WS-HEADROOM, that starts
      *   at 59. Each card's hours are added to it, and it overflows
      *   (ON SIZE ERROR) exactly when the total passes 40, because
      *   59 + 41 = 100 does not fit in PIC 99. The size-error handler
      *   ALTERs NEXT-CARD one last time, to FINISH-RUN.
      *
      * Fixed format: a * in column 7 is a comment, code is in columns
      * 8-72. Paragraphs run in the order they are written unless a
      * GO TO says otherwise, so this file reads top to bottom.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TIMECARDS-WEIRD.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SQL-SCRIPT ASSIGN TO WS-SQL-PATH
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD  SQL-SCRIPT.
       01  SQL-LINE                PIC X(400).

       WORKING-STORAGE SECTION.
      * ---- the tripwire --------------------------------------------
      * 59 + total fits in two digits while the total is 40 or less.
      * The add that would make it 100 or more is a size error, and a
      * size error leaves the field as it was.
       01  WS-HEADROOM             PIC 99 VALUE 59.
       01  WS-TOTAL                PIC 99 VALUE 0.
       01  WS-HOURS                PIC 99.
       01  WS-ENTRIES              PIC 9 VALUE 0.
       01  WS-CATEGORY             PIC X(9).

      * ---- run id and random seed ----------------------------------
       01  WS-NOW                  PIC X(21).
       01  WS-PID                  PIC 9(9).
       01  WS-PID-TEXT             PIC Z(8)9.
       01  WS-RUN-ID               PIC X(30).
       01  WS-SEED                 PIC 9(9).
       01  WS-IGNORED              USAGE COMP-2.

      * ---- the ISO-8601 week, by date arithmetic --------------------
       01  WS-TODAY                PIC 9(8).
       01  WS-DAY                  PIC 9(7).
       01  WS-THURSDAY             PIC 9(7).
       01  WS-ISO-YEAR             PIC 9(4).
       01  WS-ISO-WEEK             PIC 99.
       01  WS-WEEK                 PIC X(8).

      * ---- where the data goes, chosen without IF -------------------
      * Choice 1 is $HOME/.local/share, choice 2 is $XDG_DATA_HOME.
      * The subscript is 1 + MIN(length of XDG_DATA_HOME, 1): 1 when
      * it is unset, 2 when it is set.
       01  WS-HOME                 PIC X(300).
       01  WS-XDG                  PIC X(300).
       01  WS-XDG-LENGTH           PIC 9(4) VALUE 0.
       01  BASE-CHOICES.
           05  BASE-CHOICE         PIC X(300) OCCURS 2 TIMES.
       01  WS-BASE-IX              PIC 9.
       01  WS-DIR                  PIC X(320).
       01  WS-DB-PATH              PIC X(360).
       01  WS-SQL-PATH             PIC X(360).
       01  WS-CMD                  PIC X(1200).
       01  WS-LINE                 PIC X(400).
       01  WS-TAB                  PIC X VALUE X"09".

       PROCEDURE DIVISION.
       SET-UP.
           MOVE FUNCTION CURRENT-DATE TO WS-NOW
           CALL "C$GETPID" RETURNING WS-PID
           MOVE WS-PID TO WS-PID-TEXT
           MOVE SPACES TO WS-RUN-ID
           STRING WS-NOW(1:16) "-" FUNCTION TRIM(WS-PID-TEXT)
               DELIMITED BY SIZE INTO WS-RUN-ID
           COMPUTE WS-SEED = FUNCTION MOD(
               FUNCTION NUMVAL(WS-NOW(9:8)) * 7919 + WS-PID,
               999999937)
           COMPUTE WS-IGNORED = FUNCTION RANDOM(WS-SEED).

      * Same arithmetic as ../cobol: day 1 (1601-01-01) was a Monday,
      * and an ISO week belongs to the year its Thursday is in.
       WORK-OUT-WEEK.
           MOVE WS-NOW(1:8) TO WS-TODAY
           COMPUTE WS-DAY = FUNCTION INTEGER-OF-DATE(WS-TODAY)
           COMPUTE WS-THURSDAY =
               WS-DAY - FUNCTION MOD(WS-DAY - 1, 7) + 3
           COMPUTE WS-ISO-YEAR =
               FUNCTION DATE-OF-INTEGER(WS-THURSDAY) / 10000
           COMPUTE WS-ISO-WEEK = (WS-THURSDAY -
               FUNCTION INTEGER-OF-DATE(WS-ISO-YEAR * 10000 + 101))
               / 7 + 1
           STRING WS-ISO-YEAR "-W" WS-ISO-WEEK
               DELIMITED BY SIZE INTO WS-WEEK.

       CHOOSE-FOLDER.
           ACCEPT WS-HOME FROM ENVIRONMENT "HOME"
           ACCEPT WS-XDG FROM ENVIRONMENT "XDG_DATA_HOME"
           STRING FUNCTION TRIM(WS-HOME) "/.local/share"
               DELIMITED BY SIZE INTO BASE-CHOICE(1)
           MOVE WS-XDG TO BASE-CHOICE(2)
           INSPECT WS-XDG TALLYING WS-XDG-LENGTH
               FOR CHARACTERS BEFORE INITIAL SPACE
           COMPUTE WS-BASE-IX = 1 + FUNCTION MIN(WS-XDG-LENGTH, 1)
           STRING FUNCTION TRIM(BASE-CHOICE(WS-BASE-IX)) "/CobolWeird"
               DELIMITED BY SIZE INTO WS-DIR
           STRING FUNCTION TRIM(WS-DIR) "/demo-timecards.db"
               DELIMITED BY SIZE INTO WS-DB-PATH
           STRING FUNCTION TRIM(WS-DIR) "/run-"
               FUNCTION TRIM(WS-RUN-ID) ".sql"
               DELIMITED BY SIZE INTO WS-SQL-PATH.

      * The shell creates the folder here and runs sqlite3 at the end.
      * CHECK(demo_only=1) means a non-demo row cannot be stored.
       OPEN-SCRIPT.
           MOVE SPACES TO WS-CMD
           STRING "mkdir -p '" FUNCTION TRIM(WS-DIR) "'"
               DELIMITED BY SIZE INTO WS-CMD
           CALL "SYSTEM" USING WS-CMD
           OPEN OUTPUT SQL-SCRIPT
           MOVE SPACES TO WS-LINE
           STRING "CREATE TABLE IF NOT EXISTS demo_timecards("
               "id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,"
               "hours INTEGER,running_total INTEGER,iso_week TEXT,"
               "created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 "
               "CHECK(demo_only=1));"
               DELIMITED BY SIZE INTO WS-LINE
           WRITE SQL-LINE FROM WS-LINE
           WRITE SQL-LINE FROM "BEGIN;"
           DISPLAY "# DEMO ONLY run " FUNCTION TRIM(WS-RUN-ID).

      * ---- the switchboard ------------------------------------------
      * NEXT-CARD is the only thing ALTER may change: a paragraph that
      * is exactly one GO TO. It starts out pointing at MEETINGS-CARD.
       NEXT-CARD.
           GO TO MEETINGS-CARD.

      * Each category names itself, rewires NEXT-CARD to the category
      * after it, and joins RECORD-CARD. Nothing counts modulo 4.
       MEETINGS-CARD.
           MOVE "Meetings" TO WS-CATEGORY
           ALTER NEXT-CARD TO PROCEED TO CODING-CARD
           GO TO RECORD-CARD.

       CODING-CARD.
           MOVE "Coding" TO WS-CATEGORY
           ALTER NEXT-CARD TO PROCEED TO DEBUGGING-CARD
           GO TO RECORD-CARD.

       DEBUGGING-CARD.
           MOVE "Debugging" TO WS-CATEGORY
           ALTER NEXT-CARD TO PROCEED TO LEARNING-CARD
           GO TO RECORD-CARD.

       LEARNING-CARD.
           MOVE "Learning" TO WS-CATEGORY
           ALTER NEXT-CARD TO PROCEED TO MEETINGS-CARD
           GO TO RECORD-CARD.

      * One card. The last statement before GO TO NEXT-CARD is the
      * tripwire: if the headroom overflows, NEXT-CARD is rewired to
      * FINISH-RUN, so the very same GO TO now ends the run.
       RECORD-CARD.
           COMPUTE WS-HOURS = 10 + FUNCTION RANDOM * 10
           ADD WS-HOURS TO WS-TOTAL
           ADD 1 TO WS-ENTRIES
           DISPLAY FUNCTION TRIM(WS-CATEGORY) WS-TAB
               WS-HOURS WS-TAB WS-TOTAL WS-TAB WS-WEEK WS-TAB
               "DEMO ONLY"
      * Safe only because every value is a number computed here or
      * one of four fixed words. Do not copy this pattern.
           MOVE SPACES TO WS-LINE
           STRING "INSERT INTO demo_timecards(run_id,category,hours,"
               "running_total,iso_week,created_at) VALUES('"
               FUNCTION TRIM(WS-RUN-ID) "','"
               FUNCTION TRIM(WS-CATEGORY) "',"
               WS-HOURS "," WS-TOTAL ",'" WS-WEEK
               "',datetime('now'));"
               DELIMITED BY SIZE INTO WS-LINE
           WRITE SQL-LINE FROM WS-LINE
           ADD WS-HOURS TO WS-HEADROOM
               ON SIZE ERROR
                   ALTER NEXT-CARD TO PROCEED TO FINISH-RUN
           END-ADD
           GO TO NEXT-CARD.

      * Without IF, a failed sqlite3 cannot skip the summary; instead
      * the shell reports it on stderr and its status becomes the
      * program's exit code (SYSTEM returns status * 256).
       FINISH-RUN.
           WRITE SQL-LINE FROM "COMMIT;"
           CLOSE SQL-SCRIPT
           MOVE SPACES TO WS-CMD
           STRING "sqlite3 -bail '" FUNCTION TRIM(WS-DB-PATH)
               "' < '" FUNCTION TRIM(WS-SQL-PATH)
               "' && rm -f '" FUNCTION TRIM(WS-SQL-PATH)
               "' || { echo 'sqlite3 failed; the script is still at "
               FUNCTION TRIM(WS-SQL-PATH) "' >&2; exit 1; }"
               DELIMITED BY SIZE INTO WS-CMD
           CALL "SYSTEM" USING WS-CMD
           COMPUTE RETURN-CODE = RETURN-CODE / 256
           DISPLAY "# committed total=" WS-TOTAL
               " entries=" WS-ENTRIES " DEMO ONLY"
           DISPLAY "# no IF, no PERFORM: ALTER kept rewiring one GO TO,"
               " and a two-digit field overflowing pulled the plug"
           STOP RUN.
