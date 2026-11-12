# Capability matrix

Pass = demonstrated from runtime-loaded XAML under that grade. S = strict built-in, P = package-backed pure, C = constrained (not built).

| Capability | S | P | C | Evidence |
|---|---|---|---|---|
| Runtime XAML load / object graph | pass | pass | not built | iteration-log 01, 10, 11 |
| Window composition | pass | pass | not built | run traces (root = System.Windows.Window); automated only, no screenshot taken |
| Animation | pass (B1: opacity 1 → 0.2, held) | storyboard declared; value not asserted in P | – | iteration 01 |
| Framework method invocation | pass | pass | – | iterations 02, 05 |
| Object creation / collection mutation | partial: construction passes (x:Arguments, x:FactoryMethod); mutation only with static args (ArrayList.Clear 2 → 0) | pass (SQLite rows) | – | iterations 02, 08 |
| Generic state transition / re-trigger | **partial**: re-trigger (Refresh) pass; document-order sequencing pass; Sum + CompareTo + DataTrigger data-driven *visible* branch pass (D1); **conditional effect selection blocked** (D2, D3); no loop construct | pass: termination guard is SQL embedded in XAML (counted as XAML-owned per owner) | – | 03-06, 10-14 |
| Deterministic random-card equivalent | partial: seeded Random(42).Next(10,20) = 16,11,11,15,11 on every run, but values cannot flow into later calls; the strict composition's int[] {16,11,14} is hand-copied constants | partial (owner accepts SQL-in-XAML as XAML): hours come from SQL formula 10+((count*7+5)%10) → 15,12,19, not from the seeded Random | – | 02, 05, 11 |
| Persist to SQLite | blocked by provenance (no built-in SQLite) | pass via Microsoft.Data.Sqlite directly; EF Core `DbContext` blocked at constructor argument (provider not unwrapped) and no usable model type (iteration 15) | – | 07, 11 |
| Threading / background work | pass: Thread(IsBackground) built, started, joined in XAML (thread 7 vs UI 2); IsAsynchronous provider on pool thread | pass: async summary on pool thread, result bound to UI | – | 08 |
| Clean termination & repeatability | pass (2 identical runs) | pass (2 runs, identical rows) | – | run-s1/s2, run-r1/r2 |
