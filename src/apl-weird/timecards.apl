⍝ ──────────────────────────────────────────────────────────────────────────
⍝ DEMO ONLY. Fictional timecards, written to a scratch SQLite file under
⍝ XDG_DATA_HOME. Nothing here touches a real time-reporting system.
⍝
⍝ Run:  apl --script -f timecards.apl
⍝
⍝ THE STUNT: the host defines exactly one function, Card0.  Every other card
⍝ is a function that the previous card *wrote*: it reads its own source with
⍝ ⎕CR, swaps in a header and four "gene" lines (card number, category, hours,
⍝ running total), hands the copy to ⎕FX, and calls it.  The rule "keep going
⍝ while the total is 40 or less" is a compress (/) over the child's source
⍝ text: once the total passes 40 the child is zero lines long, ⎕FX defines
⍝ nothing, and there is nothing to call.  No ⍣, no →, no loop, no `if`.
⍝ The state is not in variables, it is in the program text.
⍝ ──────────────────────────────────────────────────────────────────────────

⎕IO←0
⎕RL←+/⎕TS×1 12 372 8928 535680 32140800 1894248000    ⍝ GNU APL always starts at 16807

Categories←'Meetings' 'Coding' 'Debugging' 'Learning'
NL←⎕UCS 10
TAB←⎕UCS 9
RunId←1↓∊'-',¨⍕¨⎕TS

Date←⎕FIO[24] 'date +%G-W%V'
Week←¯1↓⎕UCS ⎕FIO[8] Date
_←⎕FIO[25] Date

Sqlite←'w' ⎕FIO[24] 'd=${XDG_DATA_HOME:-$HOME/.local/share}/AplWeird; mkdir -p "$d"; exec sqlite3 "$d/demo-timecards.db"'
_←('CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));BEGIN;',NL) ⎕FIO[23] Sqlite
Insert←'INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES(''%s'',''%s'',%d,%d,''%s'',datetime(''now''));',NL
Show←'%s',TAB,'%d',TAB,'%d',TAB,'%s',TAB,'DEMO ONLY',NL

⍝ Local names every copy declares in its header, so a child's N, C, H, T cannot
⍝ trample its parent's.
Locals←';N;C;H;T;D;Alive;Kid;Genes'

_←('# DEMO ONLY run %s',NL) RunId ⎕FIO[22] 1

⍝ ── The only function the host ever writes ───────────────────────────────
⍝ Lines 1-4 are the genes (they are replaced in every copy); line 5 onwards is
⍝ the body, which every copy inherits verbatim.
∇Card0;N;C;H;T;D;Alive;Kid;Genes
N←0
C←0
H←10+?10
T←H
_←(Show (⊃Categories[C]) H T Week) ⎕FIO[22] 1
_←(Insert RunId (⊃Categories[C]) H T Week) ⎕FIO[22] Sqlite
D←10+?10                                         ⍝ next card's hours, drawn now
Genes←('N←',⍕N+1) ('C←',⍕4|C+1) ('H←',⍕D) ('T←',⍕T+D)
Alive←40≥T                                       ⍝ 1 until the total passes 40
Kid←⎕FX Alive/(⊂'Card',(⍕N+1),Locals),Genes,5↓⊂[1]⎕CR 'Card',⍕N
⍎Alive/'Card',⍕N+1
∇

Card0

⍝ ── What the program wrote ────────────────────────────────────────────────
⍝ ⎕NL 3 lists every function in the workspace.  Card0 is ours; the rest were
⍝ written at run time, and line 3 of each is the hours it was born with.
Names←⊂[1]⎕NL 3
Mine←{'Card'≡4↑⍵}¨Names
Last←↑⌽Mine/Names
Total←⍎2↓(⎕CR Last~' ')[4;]~' '                  ⍝ the T←41 gene of the final card
_←{(('# %s ⇐ %s',NL) (⍵~' ') ((⎕CR ⍵~' ')[3;]~' ')) ⎕FIO[22] 1}¨Mine/Names
_←('COMMIT;',NL) ⎕FIO[23] Sqlite
_←⎕FIO[25] Sqlite
_←(('# committed total=%d entries=%d DEMO ONLY',NL,'# the host wrote Card0 and nothing else; each later card was written by the one before it',NL) Total (≢Mine/Names)) ⎕FIO[22] 1
)OFF
