      * DEMO ONLY. Fictional timecards, written to a scratch SQLite file
      * under XDG_DATA_HOME. Nothing here touches a real time-reporting
      * system.
      *
      * Run:  cobc -xj timecards.cob
      *
      * The challenge: add 10-19 hour cards (Meetings, Coding,
      * Debugging, Learning, round and round) until the running total
      * passes 40. Here that is one statement in the PROCEDURE DIVISION,
      * PERFORM DRAW-CARD UNTIL OVER-FORTY, and the stop rule itself is
      * not code at all: OVER-FORTY is an 88-level condition declared
      * on the total in the DATA DIVISION.
      *
      * Layout is traditional fixed format, inherited from punched
      * cards: columns 1-6 were a sequence number (left blank here), a
      * * in column 7 makes a comment, and code lives in columns 8-72.
      * Division, section and paragraph names start in column 8
      * ("area A"); statements start in column 12 ("area B").
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TIMECARDS.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
      * The SQL script is an ordinary COBOL sequential file, one record
      * per line. ASSIGN TO a data item means its name is decided at
      * run time, from the contents of WS-SQL-PATH when it is OPENed.
           SELECT SQL-SCRIPT ASSIGN TO WS-SQL-PATH
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD  SQL-SCRIPT.
       01  SQL-LINE                PIC X(400).

       WORKING-STORAGE SECTION.
      * ---- the stop rule, as data ----------------------------------
      * PIC 99 is exactly two decimal digits. The 88-level gives a
      * name to a range of WS-TOTAL's values; UNTIL OVER-FORTY just
      * asks whether the total is currently in that range.
       01  WS-TOTAL                PIC 99 VALUE 0.
           88  OVER-FORTY          VALUE 41 THRU 99.
      * Storing 10.0-19.99 into PIC 99 drops the fraction: 10..19.
       01  WS-HOURS                PIC 99.
       01  WS-ENTRIES              PIC 9 VALUE 0.

      * ---- the categories: four FILLERs, seen again as a table ------
      * REDEFINES lays a second description over the same 36 bytes.
       01  CATEGORY-NAMES.
           05  FILLER              PIC X(9) VALUE "Meetings".
           05  FILLER              PIC X(9) VALUE "Coding".
           05  FILLER              PIC X(9) VALUE "Debugging".
           05  FILLER              PIC X(9) VALUE "Learning".
       01  CATEGORY-TABLE REDEFINES CATEGORY-NAMES.
           05  CATEGORY            PIC X(9) OCCURS 4 TIMES.
       01  WS-CAT-IX               PIC 9.

      * ---- run id and random seed ----------------------------------
      * CURRENT-DATE is 21 characters: YYYYMMDDhhmmssff then the UTC
      * offset. ff is hundredths of a second.
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

      * ---- files and the shell -------------------------------------
       01  WS-HOME                 PIC X(300).
       01  WS-BASE                 PIC X(300).
       01  WS-DIR                  PIC X(320).
       01  WS-DB-PATH              PIC X(360).
       01  WS-SQL-PATH             PIC X(360).
       01  WS-CMD                  PIC X(1200).
       01  WS-LINE                 PIC X(400).
       01  WS-TAB                  PIC X VALUE X"09".

       PROCEDURE DIVISION.
       MAIN-PARAGRAPH.
           PERFORM SET-UP
           PERFORM OPEN-SCRIPT
           DISPLAY "# DEMO ONLY run " FUNCTION TRIM(WS-RUN-ID)

      * ---- the whole challenge --------------------------------------
           PERFORM DRAW-CARD UNTIL OVER-FORTY

           PERFORM COMMIT-SCRIPT
           DISPLAY "# committed total=" WS-TOTAL
               " entries=" WS-ENTRIES " DEMO ONLY"
           DISPLAY "# PERFORM UNTIL an 88-level: the stop rule is"
               " declared in the DATA DIVISION"
           MOVE 0 TO RETURN-CODE
           STOP RUN.

      * One card: pick the category, draw the hours, keep the totals,
      * show the row and add its INSERT to the script.
       DRAW-CARD.
           COMPUTE WS-CAT-IX = FUNCTION MOD(WS-ENTRIES, 4) + 1
           COMPUTE WS-HOURS = 10 + FUNCTION RANDOM * 10
           ADD WS-HOURS TO WS-TOTAL
           ADD 1 TO WS-ENTRIES
           DISPLAY FUNCTION TRIM(CATEGORY(WS-CAT-IX)) WS-TAB
               WS-HOURS WS-TAB WS-TOTAL WS-TAB WS-WEEK WS-TAB
               "DEMO ONLY"
      * Safe only because every value is a number computed here or
      * one of four fixed words. Do not copy this pattern.
           MOVE SPACES TO WS-LINE
           STRING "INSERT INTO demo_timecards(run_id,category,hours,"
               "running_total,iso_week,created_at) VALUES('"
               FUNCTION TRIM(WS-RUN-ID) "','"
               FUNCTION TRIM(CATEGORY(WS-CAT-IX)) "',"
               WS-HOURS "," WS-TOTAL ",'" WS-WEEK
               "',datetime('now'));"
               DELIMITED BY SIZE INTO WS-LINE
           WRITE SQL-LINE FROM WS-LINE.

       SET-UP.
           MOVE FUNCTION CURRENT-DATE TO WS-NOW
           CALL "C$GETPID" RETURNING WS-PID
           MOVE WS-PID TO WS-PID-TEXT
      * The run id is the timestamp plus the process id, so runs in
      * the same hundredth of a second still get different ids.
           MOVE SPACES TO WS-RUN-ID
           STRING WS-NOW(1:16) "-" FUNCTION TRIM(WS-PID-TEXT)
               DELIMITED BY SIZE INTO WS-RUN-ID
      * RANDOM with an argument seeds the generator; later calls
      * without one continue the sequence.
           COMPUTE WS-SEED = FUNCTION MOD(
               FUNCTION NUMVAL(WS-NOW(9:8)) * 7919 + WS-PID,
               999999937)
           COMPUTE WS-IGNORED = FUNCTION RANDOM(WS-SEED)
           PERFORM WORK-OUT-WEEK
           ACCEPT WS-BASE FROM ENVIRONMENT "XDG_DATA_HOME"
           IF WS-BASE = SPACES
               ACCEPT WS-HOME FROM ENVIRONMENT "HOME"
               STRING FUNCTION TRIM(WS-HOME) "/.local/share"
                   DELIMITED BY SIZE INTO WS-BASE
           END-IF
           STRING FUNCTION TRIM(WS-BASE) "/Cobol"
               DELIMITED BY SIZE INTO WS-DIR
           STRING FUNCTION TRIM(WS-DIR) "/demo-timecards.db"
               DELIMITED BY SIZE INTO WS-DB-PATH
           STRING FUNCTION TRIM(WS-DIR) "/run-"
               FUNCTION TRIM(WS-RUN-ID) ".sql"
               DELIMITED BY SIZE INTO WS-SQL-PATH.

      * INTEGER-OF-DATE counts days from 1601-01-01 (day 1), which was
      * a Monday, so MOD(day - 1, 7) is 0 on Mondays. An ISO week
      * belongs to the year its Thursday falls in, and week 1 is the
      * week holding that year's first Thursday.
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

      * The shell is used twice: to create the data folder here, and
      * to hand the finished script to sqlite3 in COMMIT-SCRIPT. The
      * DEMO ONLY rule lives in the table: CHECK(demo_only=1) means a
      * non-demo row cannot be stored.
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
           WRITE SQL-LINE FROM "BEGIN;".

      * The script is deleted only if sqlite3 succeeded, so a failed
      * run leaves it behind to look at.
       COMMIT-SCRIPT.
           WRITE SQL-LINE FROM "COMMIT;"
           CLOSE SQL-SCRIPT
           MOVE SPACES TO WS-CMD
           STRING "sqlite3 -bail '" FUNCTION TRIM(WS-DB-PATH)
               "' < '" FUNCTION TRIM(WS-SQL-PATH)
               "' && rm -f '" FUNCTION TRIM(WS-SQL-PATH) "'"
               DELIMITED BY SIZE INTO WS-CMD
           CALL "SYSTEM" USING WS-CMD
           IF RETURN-CODE NOT = 0
               DISPLAY "sqlite3 failed; the script is still at "
                   FUNCTION TRIM(WS-SQL-PATH) UPON SYSERR
               MOVE 1 TO RETURN-CODE
               STOP RUN
           END-IF.
