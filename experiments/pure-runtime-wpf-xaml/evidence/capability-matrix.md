# Capability matrix

Pass = demonstrated from runtime-loaded XAML under that grade. S = strict built-in, P = package-backed pure, C = constrained (not built).

| Capability | S | P | C | Evidence |
|---|---|---|---|---|
| Runtime XAML load / object graph | pass | pass | not built | iteration-log 01, 10, 11 |
| Window composition | pass (object graph + TEXT dump + screenshot) | pass | not needed | runs/*/trace.txt, runs/*/screenshot.png |
| Animation | pass: B1 and final runs (`g.Opacity` ~0.655 at 700 ms, looping 1 -> 0.45) | pass: same | – | iteration 01; runs/*/trace.txt NAMED lines |
| Framework method invocation | pass | pass | – | iterations 02, 05 |
| Object creation / collection mutation | pass: construction (x:Arguments, x:FactoryMethod), in-place mutation of carriers/collections (char[], byte[], ArrayList.Clear, DataTable rows, Columns.Add) | pass (SQLite rows, BLOB parameters) | not needed | iterations 02, 08, 16 |
| Generic state transition / re-trigger | pass within bounds: doc-order sequencing, Refresh re-trigger, Sum/Compute arithmetic over dynamic data, CompareTo to DataTrigger visible branch, DataView row-filter guard (conditional inclusion); **limits**: unrolled (no unbounded loop), conditional effect selection only via expression engines, trigger-to-CLR write blocked (D2/D3) | pass: guard is SQL `WHERE` in the XAML (owner: counts as XAML) | not needed | 03-06, 12-14, 16 |
| Deterministic random-card equivalent | **pass**: Random(42).Next(10,20) = 16,11,11,15; values flow through carriers into Sum/Compute and the XML output (byte-identical across runs) | **pass**: same seeded draws inserted into SQLite (16,11,11,15 = 53 h) | not needed | 02, 05, 16 |
| Persist to SQLite | blocked by provenance (no built-in SQLite); **strict analogue passes**: `DataTable.WriteXml` of the guarded rows | pass via Microsoft.Data.Sqlite directly **and via EF Core** (`DemoTimeCardContext.TimeCards.Add` + `SaveChanges` from XAML, seeded values, owner-approved model copy) | not needed | 07, 11, 16, 17 |
| Threading / background work | pass: Thread(IsBackground) built/started/joined (thread 7 vs UI 2); WriteXml on a pool thread via IsAsynchronous | pass: SQLite summary on a pool thread, result bound to UI | – | 08, 16 |
| Clean termination & repeatability | pass: two runs identical, XML byte-identical | pass: two fresh runs identical rows | – | run-t1/t2, run-p1/p2 |

Additional columns of evidence: all three compositions pass on **net10.0-windows (two runs) and net11.0-windows (one run)** with identical results; the package-backed EF variant (`package-backed-ef`) is a second P composition. Screenshots: `runs/<tfm>-<run>-<grade>/screenshot.png` (host-rendered PNG of the window content; the storyboard fades the content, so shots are mid-animation).
