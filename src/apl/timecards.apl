⍝ ──────────────────────────────────────────────────────────────────────────
⍝ DEMO ONLY. Fictional timecards, written to a scratch SQLite file under
⍝ XDG_DATA_HOME. Nothing here touches a real time-reporting system.
⍝
⍝ Run:  apl --script -f timecards.apl
⍝
⍝ The whole challenge ("add 10-19 hour cards until the total passes 40") is
⍝ three array expressions.  There is no loop and no `if`; the rest of the
⍝ file is plumbing: seeding, a pipe to sqlite3, and printing.
⍝ ──────────────────────────────────────────────────────────────────────────

⍝ Style notes: one statement per line (⋄ is for the REPL), CamelCase names
⍝ for things we define, and no assumption about ⎕IO (the index origin).
⍝ The only origin-sensitive primitive used is ?, which rolls ⎕IO..⎕IO+9 for
⍝ ?10, so the draw below subtracts the origin back out.

⍝ GNU APL starts every session at ⎕RL=16807, so without this every run
⍝ would print the same "random" cards.  Fold the clock into a seed instead.
⎕RL←+/⎕TS×1 12 372 8928 535680 32140800 1894248000

Categories←'Meetings' 'Coding' 'Debugging' 'Learning'
NL←⎕UCS 10
TAB←⎕UCS 9

⍝ ── The challenge ─────────────────────────────────────────────────────────
⍝ 1. Draw hours.  Every card is at least 10 hours, so five of them always
⍝    pass 40 (5×10=50).  Drawing five up front is a *bound*, not a loop count.
⍝    (?5⍴10) gives five rolls from the first ten integers; the origin shift
⍝    and the +10 turn them into 10..19.
Drawn←(10-⎕IO)+?5⍴10

⍝ 2. Stop rule.  Running totals only ever grow, so "total is still ≤ 40"
⍝    is true for a prefix of the cards and then false forever.  Count that
⍝    prefix (+/40≥+\), add the one card that crosses the line, and take.
Hours←Drawn↑⍨1++/40≥+\Drawn

⍝ 3. Everything else is derived from Hours with no further decisions.
Totals←+\Hours                    ⍝ running total after each card
Kinds←(≢Hours)⍴Categories         ⍝ ⍴ recycles: Meetings Coding Debugging Learning Meetings …

⍝ ── Plumbing ──────────────────────────────────────────────────────────────
RunId←1↓∊'-',¨⍕¨⎕TS              ⍝ 2026-11-14-9-37-13-583

⍝ ISO week comes from date(1) so APL need not re-derive ISO-8601 calendars.
⍝ ⎕FIO[24] runs a command and returns a file handle, ⎕FIO[8] reads a line
⍝ from it, ⎕FIO[25] closes it.  ¯1↓ drops the trailing newline.
Date←⎕FIO[24] 'date +%G-W%V'
Week←¯1↓⎕UCS ⎕FIO[8] Date
_←⎕FIO[25] Date

⍝ Open a write-pipe to sqlite3.  ⎕FIO[24] with a left argument 'w' is popen.
⍝ The shell snippet only picks (and creates) the scratch directory.
Sqlite←'w' ⎕FIO[24] 'd=${XDG_DATA_HOME:-$HOME/.local/share}/Apl; mkdir -p "$d"; exec sqlite3 "$d/demo-timecards.db"'

⍝ The CHECK constraint makes "not demo" unrepresentable in this table.
Schema←'CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));BEGIN;'
_←(Schema,NL) ⎕FIO[23] Sqlite   ⍝ ⎕FIO[23] fwrites a string

⍝ ⎕FIO[22] is fprintf: a format string on the left, its arguments on the
⍝ right.  Values here are numbers or our own fixed words, never user input,
⍝ so formatting SQL with %s is safe in this one place; do not copy the habit.
Insert←'INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES(''%s'',''%s'',%d,%d,''%s'',datetime(''now''));',NL
Row←TAB,'%d',TAB,'%d',TAB,'%s',TAB,'DEMO ONLY',NL

⍝ One dfn per destination; ⍵ is a row number.  ⍳≢Hours produces row numbers
⍝ in the current origin and Kinds[⍵] indexes in that same origin, so the
⍝ pair is origin-proof.
SaveRow←{(Insert RunId (⊃Kinds[⍵]) Hours[⍵] Totals[⍵] Week) ⎕FIO[22] Sqlite}
ShowRow←{(('%s',Row) (⊃Kinds[⍵]) Hours[⍵] Totals[⍵] Week) ⎕FIO[22] 1}

_←SaveRow¨⍳≢Hours
_←('COMMIT;',NL) ⎕FIO[23] Sqlite
_←⎕FIO[25] Sqlite                ⍝ closing the pipe waits for sqlite3 to finish

⍝ ── Report ────────────────────────────────────────────────────────────────
_←(('# DEMO ONLY run %s',NL) RunId) ⎕FIO[22] 1
_←ShowRow¨⍳≢Hours
_←(('# committed total=%d entries=%d DEMO ONLY',NL,'# five rolls and one take-while; the rest were never needed',NL) (⊢/Totals) (≢Hours)) ⎕FIO[22] 1

)OFF
