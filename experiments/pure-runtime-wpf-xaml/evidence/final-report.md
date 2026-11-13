# Final report: pure runtime-WPF-XAML experiment (16 of 16 iterations used)

## 1. Executive finding
Owner decision recorded: SQL text embedded in the XAML counts as XAML.

- **Strict built-in:** the whole demo was reproduced under the strict grade, with one disclosed substitution: persistence is built-in `DataTable.WriteXml` (an XML file) because SQLite is not built-in. Demonstrated in strict built-in pure runtime XAML: window composition, looping storyboard, seeded `Random(42)` draws (16, 11, 11, 15), dynamic data flowing between calls through mutable carriers, `DataTable.Compute` arithmetic (total 53, prefix sums 0/16/27/38), `CompareTo(40)` driving a DataTrigger, a `DataView` row filter as the termination guard, XML persistence on a pool thread, an explicit background `Thread`, and byte-identical output across two runs. Caveats: the loop is unrolled to 4 draws; the conditional is an expression-engine filter, not a trigger-selected effect; no screenshot verification.
- **Package-backed pure:** demonstrated as package-backed pure declarative XAML; packages named: `Microsoft.Data.Sqlite` (via `Microsoft.EntityFrameworkCore.Sqlite` 10.0.14, unmodified). The seeded draws are inserted into SQLite (16, 11, 11, 15 = 53 h, guard in SQL text), the summary runs on a pool thread, two fresh runs identical. **Not demonstrated: EF Core `DbContext`/`Add`/`SaveChanges`** (a typed-object argument cannot be passed; two mechanisms failed; no usable model type).
- **Constrained:** not needed; no imperative capability remained.
- **Key finding (the interpreter vocabulary):** `ObjectDataProvider` plus `x:Arguments`/`x:FactoryMethod` gives construction and calls; document order gives sequencing; `Refresh` gives re-triggering; **mutable carrier arrays give late-bound data arguments**; BCL expression engines (`DataTable.Compute`, `DataView.RowFilter`, SQL) give arithmetic and conditionals.

## 2. Environment
Win11 Pro 10.0.26300; SDK 10.0.404 only; runtime 10.0.15; target `net10.0-windows`; .NET 11 **not evaluated: toolchain absent**. Package: Microsoft.EntityFrameworkCore.Sqlite 10.0.14 (unmodified). SQLite CLI 3.54.1 installed by the owner, used only for inspection.

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
```
Expected: package-backed DB rows Meetings 16, Coding 11, Debugging 11, Learning 15 and window text `Saved locally: 4 cards, 53.0 hours`; strict trace `obsTotal=53`, `obsVs40=1`, window texts `Total simulated hours: 53` / `over 40 h: batch complete`, and `artifacts/run-<id>/artifacts/strict-run/demo-timecards.xml` (sha256 prefix 94ac35b93f8248ab). Use a fresh run id each time (`run.ps1` refuses reuse). Inspect with `sqlite3 artifacts/run-r1/artifacts/pkg-run/demo-timecards.db "select * from DemoTimeCards"`. No test project (owner: not needed); verification is trace and DB inspection.

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
- Test environment: no visible-window verification, no .NET 11.

## 9. Recommended next experiments
1. **New strict hypothesis:** typed-object argument passing (needed for EF `DbContext(options)`): look for a built-in that stores a *receiver* object into a carrier or static, or a built-in static returning its argument that `x:FactoryMethod` accepts. Not found in two attempts.
2. **New strict hypothesis:** an unbounded loop. Candidates: `Refresh` chains gated by a data-driven expression, or recursion through nested `XamlReader.Parse` on a carrier-assembled string (assess against the plan's "no dynamic compilation" rule first; owner decision).
3. **Scope change needing owner approval:** whether a plain data class in the experiment may serve as the EF model type.
4. Optional: a visible smoke test with screenshots.
