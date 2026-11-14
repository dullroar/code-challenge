⍝ DEMO ONLY. Fictional timecards, written to a scratch SQLite file under XDG_DATA_HOME.
⍝ Run: apl --script -f timecards.apl
⎕IO←0 ⋄ ⎕RL←+/⎕TS×1 12 372 8928 535680 32140800 1894248000
C←'Meetings' 'Coding' 'Debugging' 'Learning'
H←10+?5⍴10                                  ⍝ five draws always overshoot 40
H←(1+(40<+\H)⍳1)↑H                          ⍝ keep up to the first running total over 40
T←+\H ⋄ K←C[4|⍳≢H] ⋄ R←1↓∊'-',¨⍕¨⎕TS ⋄ N←⎕UCS 10 ⋄ X←⎕UCS 9
W←¯1↓⎕UCS ⎕FIO[8] D←⎕FIO[24] 'date +%G-W%V' ⋄ _←⎕FIO[25] D
S←'w' ⎕FIO[24] 'd=${XDG_DATA_HOME:-$HOME/.local/share}/Apl; mkdir -p "$d"; exec sqlite3 "$d/demo-timecards.db"'
_←('CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));BEGIN;',N) ⎕FIO[23] S
I←'INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES(''%s'',''%s'',%d,%d,''%s'',datetime(''now''));',N
_←{(I R (⊃K[⍵]) H[⍵] T[⍵] W) ⎕FIO[22] S}¨⍳≢H
_←('COMMIT;',N) ⎕FIO[23] S ⋄ _←⎕FIO[25] S
_←(('# DEMO ONLY run %s',N) R) ⎕FIO[22] 1
_←{(('%s',X,'%d',X,'%d',X,'%s',X,'DEMO ONLY',N) (⊃K[⍵]) H[⍵] T[⍵] W) ⎕FIO[22] 1}¨⍳≢H
_←(('# committed total=%d entries=%d DEMO ONLY',N,'# five rolls and one take-while; the rest were never needed',N) (⊢/T) (≢H)) ⎕FIO[22] 1
)OFF
