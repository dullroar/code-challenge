# Final report: pure runtime-WPF-XAML experiment (15 of 16 iterations used)

## 1. Executive finding
Owner decision (recorded): SQL text embedded in the XAML counts as XAML.

- **Strict built-in:** not demonstrated for the whole demo. Demonstrated in strict built-in pure runtime XAML: window composition, storyboard animation, seeded `Random`, method invocation, re-triggering (`Refresh`), `Sum`/`CompareTo`, a `DataTrigger` data-driven branch, a background `Thread` (built, started, joined) and async provider execution. Blocked by: **no late-bound scalar argument** (results cannot feed later calls), **no conditional effect selection** (trigger-to-CLR-write attempts D2, D3 failed), generic methods unreachable, and provenance (no built-in SQLite).
- **Package-backed pure:** demonstrated as package-backed pure declarative XAML for the persistence/termination part. Packages named: `Microsoft.Data.Sqlite` (via `Microsoft.EntityFrameworkCore.Sqlite` 10.0.14, unmodified). 3 demo cards (46 h) are inserted, the 4th is suppressed by an SQL guard (the termination condition lives in XAML-embedded SQL), a summary runs on a pool thread, and two isolated runs were identical. Not demonstrated: the seeded `Random` feeding the DB (hours come from an SQL formula), and EF Core `DbContext`/`Add`/`SaveChanges` (blocked at `new DbContext(options)`, and no usable model type).
- **Constrained:** not built.
- **Whole demo:** package-backed pure reproduces the observable demo (window, animation, bounded cards, DB, background work) with the seeded-Random and EF-API substitutions above. Strict built-in does not.

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
Expected: DB rows Meetings 15, Coding 12, Debugging 19; window texts `Saved locally: 3 cards, 46.0 hours` (package-backed) and `last seeded draw: 11`, `sum of cards: 41`, `CompareTo(40): 1` (strict). Inspect with `sqlite3 artifacts/run-r1/artifacts/pkg-run/demo-timecards.db "select * from DemoTimeCards"`. No test project (owner: not needed); verification is trace and DB inspection.

## 6. Safety
Demo-only `Demo*` data and `DemoUser`; DBs only under `artifacts/run-*/` (git-ignored); no network, credentials or external systems. The baseline's LocalAppData database was never touched (the baseline was built but not executed).

## 7. Constraint audit and limitations
`constraint-audit.txt` plus a re-run after the final edits: no `x:Code`/converter/`x:Class`/`Process` hits in the two programs; the only C# file is the generic host; referenced assemblies are System.* and Microsoft.Data.Sqlite. Limitations: the host is needed to load XAML (counted as test infrastructure); no screenshots, so window and animation evidence is automated (TEXT dump, opacity value); the strict array {16,11,14} is hand-copied constants; the thread payload is `ArrayList.Clear`; the first window-text bindings were wrong (`Path=Data`) until iteration 12 corrected them.

## 8. Failure taxonomy
- Parser/type resolution: `x:Arguments` does not unwrap providers (DbContext ctor); Binding rejected on `ObjectInstance` and in `MethodParameters`; generic methods unreachable.
- Binding/trigger: a provider used as a Binding Source is unwrapped to its Data (`Path=Data` is wrong); OneWayToSource cannot push a chosen constant to a CLR property (D2/D3); a string `DataTrigger` Value does not match Int32; providers used as `ObjectInstance` unwrap to Data.
- Expression/state: only `Sum`/`CompareTo` found; no mutation with dynamic values; no loop construct.
- Persistence: SQLite is a package (provenance); `IsInitialLoadEnabled="False"` is ineffective once `MethodName` is set, so there is no "arm now, fire later".
- Threading: works in XAML via `x:FactoryMethod`; async provider results marshal to the UI.
- Test environment: no visible-window verification, no .NET 11.

## 9. Recommended next experiments
1. **New strict hypothesis:** extract a provider's `Data` as a raw object (needed for `x:Arguments` and dynamic parameters), for example via an `x:FactoryMethod` over a built-in static that returns its argument. That one primitive would unlock seeded values reaching the DB, EF `DbContext(options)` and chained state.
2. **New package-backed hypothesis:** once raw extraction exists, retry EF `DbContext`; an entity model type is still needed (owner call on whether a plain data class is allowed).
3. Optional: a visible smoke test with screenshots.
