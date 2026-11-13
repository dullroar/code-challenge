# Final report: pure runtime-WPF-XAML experiment (16 of 16 iterations plus follow-ups H3, I1, J1 and .NET 11)

## 1. Executive finding
Owner decision recorded: SQL text embedded in the XAML counts as XAML.

- **Strict built-in:** the whole demo was reproduced under the strict grade, with one disclosed substitution: persistence is built-in `DataTable.WriteXml` (an XML file) because SQLite is not built-in. Demonstrated in strict built-in pure runtime XAML: window composition, looping storyboard, seeded `Random(42)` draws (16, 11, 11, 15), dynamic data flowing between calls through mutable carriers, `DataTable.Compute` arithmetic (total 53, prefix sums 0/16/27/38), `CompareTo(40)` driving a DataTrigger, a `DataView` row filter as the termination guard, XML persistence on a pool thread, an explicit background `Thread`, and byte-identical output across two runs. Caveats: the loop is unrolled to 4 draws; the conditional is an expression-engine filter, not a trigger-selected effect; screenshots are host-rendered PNGs.
- **Package-backed pure:** demonstrated as package-backed pure declarative XAML; packages named: `Microsoft.Data.Sqlite` (via `Microsoft.EntityFrameworkCore.Sqlite` 10.0.14, unmodified). The seeded draws are inserted into SQLite (16, 11, 11, 15 = 53 h, guard in SQL text), the summary runs on a pool thread, two fresh runs identical. A second package-backed composition drives **EF Core** (`DemoTimeCardContext.TimeCards.Add` + `SaveChanges`) from XAML with the seeded draws as raw typed values; see `package-backed-ef/`. It names EF Core 10.0.14 and the two existing model types, used as an owner-approved copy with only `internal`→`public` and the DB folder changed (the baseline context cannot be redirected by environment, verified in I1). Guard is a SQL trigger in the XAML.
- **Constrained:** not needed; no imperative capability remained.
- **Whole demo, EF variant:** reproduced (window, animation, seeded cards, EF persistence, guard, async summary), two identical fresh runs.
- **Key finding (the interpreter vocabulary):** `ObjectDataProvider` plus `x:Arguments`/`x:FactoryMethod` gives construction and calls; document order gives sequencing; `Refresh` gives re-triggering; **mutable carrier arrays give late-bound data arguments** and, because raw nodes are constructed in document order, `String(char[])` + `Parse` turns them into **raw typed values** that can populate entity properties; BCL expression engines (`DataTable.Compute`, `DataView.RowFilter`, SQL) give arithmetic and conditionals.

## 2. Environment
Win11 Pro 10.0.26300; SDKs 10.0.404 and 11.0.100; runtimes 10.0.15 and 11.0.0; targets `net10.0-windows` (verified) and `net11.0-windows` (**compatible**: baseline copy builds; all compositions identical results). Package: Microsoft.EntityFrameworkCore.Sqlite 10.0.14 (unmodified). SQLite CLI 3.54.1 installed by the owner, used only for inspection.

## 3. Capability matrix
See `capability-matrix.md`; per-iteration evidence in `iteration-log.md`.

## 4. Architecture
```
program.xaml  (XML program: resources are instructions, document order is the program counter)
   -> XamlReader.Load  (generic interpreter: parse-time construction + ObjectDataProvider invocation)
        -> built-ins: Random, Enumerable, Int32, Delegate, Thread, ArrayList, Storyboard, DataTrigger
        -> package effect target: Microsoft.Data.Sqlite (SqliteConnection/SqliteCommand) -> SQLite file
probes/host/Host.cs = generic loader/dumper only (no demo logic; not part of the program)
rejected: custom converters, code-behind, helper types, compiled BAML, Process
```

## 5. Reproduce
```powershell
cd experiments/pure-runtime-wpf-xaml
./run.ps1 package-backed-pure r1   # artifacts/run-r1/{program.xaml,trace.txt,program.sha256,artifacts/pkg-run/demo-timecards.db}
./run.ps1 strict-built-in s1
./run.ps1 package-backed-ef e1    # EF Core variant (needs the EfModel copy; builds with the host)
```
Expected: package-backed DB rows Meetings 16, Coding 11, Debugging 11, Learning 15 and window text `Saved locally: 4 cards, 53.0 hours`; strict trace `obsTotal=53`, `obsVs40=1`, window texts `Total simulated hours: 53` / `over 40 h: batch complete`, and `artifacts/run-<id>/artifacts/strict-run/demo-timecards.xml` (sha256 prefix 94ac35b93f8248ab). EF variant: `Saved via EF Core: 4 cards, 53.0 hours`, rows as above with year/week from the run date. Use a fresh run id each time (`run.ps1` refuses reuse). Inspect with `sqlite3 artifacts/run-r1/artifacts/pkg-run/demo-timecards.db "select * from DemoTimeCards"`. No test project (owner: not needed); verification is trace and DB inspection.

## 6. Safety
Demo-only `Demo*` data and `DemoUser`; DBs only under `artifacts/run-*/` (git-ignored); no network, credentials or external systems. The baseline's LocalAppData database was never touched (the baseline was built but not executed).

## 7. Constraint audit and limitations
`constraint-audit.txt` (re-run after the final edits). Authoring aids `tools/gen_strict.py` and `tools/gen_pkg.py` expand the repetitive provider pipelines; their committed outputs are plain XAML with no generator dependency, and they sit outside both graded source trees (disclosed because the plan lists generators as prohibited in strict source): no `x:Code`/converter/`x:Class`/`Process` hits in the two programs; the only C# file is the generic host; referenced assemblies are System.* and Microsoft.Data.Sqlite. Limitations: the host is needed to load XAML (counted as test infrastructure); no screenshots, so window and animation evidence is automated (TEXT dump, opacity value); the thread payload is `ArrayList.Clear`; the first window-text bindings were wrong (`Path=Data`) until iteration 12 corrected them.

## 8. Failure taxonomy
- Parser/type resolution: `x:Arguments` does not unwrap providers (DbContext ctor); Binding rejected on `ObjectInstance` and in `MethodParameters`; generic methods unreachable.
- Binding/trigger: a provider used as a Binding Source is unwrapped to its Data (`Path=Data` is wrong); OneWayToSource cannot push a chosen constant to a CLR property (D2/D3); a string `DataTrigger` Value does not match Int32; providers used as `ObjectInstance` unwrap to Data.
- Expression/state: no unbounded loop; conditionals only via expression engines (`DataView.RowFilter`, `DataTable.Compute`, SQL), not trigger-selected effects. Dynamic *data* arguments are solved by carriers; dynamic *typed-object* arguments are not.
- Persistence: SQLite is a package (provenance); `IsInitialLoadEnabled="False"` is ineffective once `MethodName` is set, so there is no "arm now, fire later".
- Threading: works in XAML via `x:FactoryMethod`; async provider results marshal to the UI.
- Test environment: windows are rendered by the host to PNG (screenshots in `runs/`), not exercised by a human; no interactive input.

## 9. Recommended next experiments
1. **Closed:** EF `DbContext` was achieved once an instantiable model/context existed; a built-in route to an arbitrary typed object argument (e.g. `DbContextOptions`) was still not found.
2. **New strict hypothesis:** an unbounded loop. Candidates: `Refresh` chains gated by a data-driven expression, or recursion through nested `XamlReader.Parse` on a carrier-assembled string (assess against the plan's "no dynamic compilation" rule first; owner decision).
3. **Optional strict question:** can an EF context be reached without any copied type? (Current answer: no.)

## 10. EF addendum: constraint notes
`package-backed-ef` uses the copied model assembly `EfModel` (public C# types, not application logic: entity and context only, diff vs baseline limited to visibility and DB folder). Strict-grade claims are unaffected: the strict program references only BCL assemblies. The EF program is not strict and not claimed as such.

## 11. Evidence map
- Per-iteration notes (plan template): `iterations.md` -> `iteration-NN-*.md`; narrative history: `iteration-log.md`.
- Final runs: `runs/` (net10 x2, net11 x1 per grade: trace, DB dump / XML, screenshot, hashes). Regenerate with `tools/collect_evidence.sh`.
- Inventory and environment: `baseline-env.txt`, `toolchain.md`. Audit: `constraint-audit.txt`. Hashes: `../manifest.json`, `xaml-hashes.txt`.
- Disclosures: authoring aids in `tools/` (generators and doc writers) are outside every graded source tree; the baseline project was built but never run; the strict persistence substitution is XML.
