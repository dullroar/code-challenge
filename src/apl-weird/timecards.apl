⍝ DEMO ONLY. Fictional timecards, written to a scratch SQLite file under XDG_DATA_HOME.
⍝ Run: apl --script -f timecards.apl
⍝ Only F0 is ever instantiated by the host. Every other function is written by its predecessor,
⍝ and "keep going while the total is 40 or less" is a compress over the text that writes it.
⎕IO←0 ⋄ ⎕RL←+/⎕TS×1 12 372 8928 535680 32140800 1894248000
C←'Meetings' 'Coding' 'Debugging' 'Learning' ⋄ N←⎕UCS 10 ⋄ X←⎕UCS 9
R←1↓∊'-',¨⍕¨⎕TS ⋄ W←¯1↓⎕UCS ⎕FIO[8] D←⎕FIO[24] 'date +%G-W%V' ⋄ _←⎕FIO[25] D
S←'w' ⎕FIO[24] 'd=${XDG_DATA_HOME:-$HOME/.local/share}/AplWeird; mkdir -p "$d"; exec sqlite3 "$d/demo-timecards.db"'
_←('CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));BEGIN;',N) ⎕FIO[23] S
I←'INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES(''%s'',''%s'',%d,%d,''%s'',datetime(''now''));',N
O←'%s',X,'%d',X,'%d',X,'%s',X,'DEMO ONLY',N
P←'Z←F¤ A;H;K' 'H←10+?10 ⋄ Z←A,H ⋄ K←⊃C[4|¯1+≢Z]' '_←(O K H (+/Z) W) ⎕FIO[22] 1' '_←(I R K H (+/Z) W) ⎕FIO[22] S' '⍎(40≥+/Z)/''_←Mk ¢ ⋄ Z←F¢ Z'''
Sub←{⎕UCS (⎕UCS ⍵)+(⍵=⍺[0])×(⎕UCS ⍺[1])-⎕UCS ⍺[0]}
Mk←{⎕FX (⊂'¢',⍕⍵+1) Sub¨ (⊂'¤',⍕⍵) Sub¨ P}
_←Mk 0
_←(('# DEMO ONLY run %s',N) R) ⎕FIO[22] 1
Z←F0 ⍬
_←('COMMIT;',N) ⎕FIO[23] S ⋄ _←⎕FIO[25] S
_←(('# committed total=%d entries=%d DEMO ONLY',N,'# the host wrote F0 and nothing else; each later F was written by the one before it',N) (+/Z) (≢Z)) ⎕FIO[22] 1
)OFF
