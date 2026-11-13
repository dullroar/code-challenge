# Iteration log (15 of 16 budget used; 11-15 below, 12-15 under Continuation)

Environment for all: Win11 26300, SDK 10.0.404, generic host `probes/host` (no demo logic). Probe inputs are in `../probes/`; hashes in `xaml-hashes.txt`.

## 01 B1 window + storyboard (S) — pass
Hypothesis: EventTrigger/BeginStoryboard in loaded XAML animates. Observed content opacity 0.2 (held). Owner: XAML declares; WPF runtime executes.

## 02 C1 seeded Random via ObjectDataProvider (S) — pass / partial
- `x:Arguments` (XAML 2009) constructs `System.Random(42)`; `Next(10,20)` executes at **parse time** = 16. Pass.
- `ObjectInstance="{Binding ...}"` → XamlParseException "A 'Binding' cannot be set on the 'ObjectInstance' property" (not a DP). Blocked.
- `ObjectInstance="{StaticResource <provider>}"` and `{x:Reference}` both get **unwrapped to the provider's Data** (MissingMethodException `Int32.Refresh`). Blocked for provider-as-receiver (2 attempts, closed).

## 03 C2 re-trigger (S) — pass
The provider is smuggled inside an `x:Array` (so it is not unwrapped), fetched by a provider calling `GetValue(0)`, then a provider calling `Refresh` on it re-ran `Next` (16 → 11). Re-triggering a call needs only built-ins.

## 04 C3 dynamic method parameters (S) — blocked
`<Binding>` inside MethodParameters → parse error ("cannot be used within a 'ParameterCollection'"). `StaticResource` of a provider passes the provider object itself (ArrayList held the ODP), not its value. **Missing primitive: a late-bound scalar argument.** This is the main reason strict state/arithmetic cannot be chained.

## 05 C4 sequencing/determinism (S) — pass
Five providers draw 16,11,11,15,11 in document order on every run. Providers execute at parse (EndInit) in document order. Resource-dictionary enumeration order is process-randomized but does not affect execution order.

## 06 E1 arithmetic/comparison (S) — pass / blocked
`Enumerable.Sum(int[])` = 60; `Int32.CompareTo(40)` = 1 using receiver unwrapping. `Random.Shuffle` → MissingMethodException (generic methods unreachable). Blocked.

## 07 F1 SQLite (P) — pass
`SqliteConnection`/`SqliteCommand` constructed with x:Arguments; Open / ExecuteNonQuery by providers; the row (1,'Coding',12.0,1) was verified externally with python sqlite3. Provenance: Microsoft.Data.Sqlite via the EF Core Sqlite package, **not built-in**.

## 08 G1/G2 threading (S) — pass
`Delegate.CreateDelegate` via `x:FactoryMethod` produced a ThreadStart over `ArrayList.Clear` (void instance method). `Thread` with x:Arguments(delegate) and IsBackground=True; Start/Join providers; thread id 7 vs UI 2; ArrayList count 2 → 0 shows the delegate ran. An `IsAsynchronous` provider ran on pool thread 4 and delivered Data after dispatch. First try (provider-produced delegate in x:Arguments) failed because providers are not unwrapped there; fixed with x:FactoryMethod.

## 09 IsInitialLoadEnabled="False" (P) — blocked
A provider with the flag still executed at parse (1 row with no thread); attribute order did not matter; IsAsynchronous also ran once. Only a provider without MethodName stays idle. So there is no declarative "arm now, fire later" except Refresh. Host artifact also found: reading `Data` of a lazy provider triggers it (host now dumps only `obs*` keys when present). An earlier package-backed design (threads running Refresh) double-inserted (Meetings, Meetings, Coding) and was **discarded**, not reported as passing.

## 10 integrated strict-built-in — partial
Window + animation, seeded draws, Sum/CompareTo, background Thread. No DB, no data-dependent control flow.

## 11 integrated package-backed-pure — partial, pass with caveat
3 cards (Meetings 15, Coding 12, Debugging 19 = 46 h) inserted in document order; the 4th is suppressed by an SQL `WHERE SUM(Hours) <= 40` guard; an async summary runs on a pool thread and is bound into the window. Two isolated runs gave identical rows. **Owner decision needed**: the threshold and hour formula are SQL text inside XAML, interpreted by SQLite. Whether that counts as "XAML owns the semantics" is the plan's section-10 ambiguity; I did not decide it.

---
# Continuation (iterations 12–15; total 15 of 16)

## 12 D1 data-dependent branch (S) — **pass**
`Sum(int[])` → `CompareTo(40)` → `DataTrigger` (typed `<sys:Int32>` Value) selected the TextBlock text "OVER-40: terminal" (and the -1 branch "UNDER-40: continue" exists but was not taken with this data). A string `Value="1"` never matched an Int32 — must be typed. A local `Text` attribute beat the trigger setter (precedence); defaults must live in the Style. So **state representation and a data-driven branch are expressible with built-ins, but only as visible property changes.**
**Correction found during this iteration:** when a `DataSourceProvider` is a Binding `Source`, WPF binds to its `Data` directly, so `Path=Data` resolved nothing. The window TextBlocks in both compositions were blank in iterations 10/11. Fixed (`Path=Data` removed); the host now prints every TextBlock, and traces show `last seeded draw: 11`, `sum of cards: 41`, `CompareTo(40): 1`, `Saved locally: 3 cards, 46.0 hours`.

## 13 D2 animation-driven write to a CLR property (S) — **blocked**
Hypothesis: a trigger animation sets `Tag`, whose OneWayToSource binding writes `ObjectDataProvider.MethodName` (a CLR property that re-runs the provider), giving a conditional effect. Observed: Tag became "Clear" but the binding did **not** push the animated value; the only write was the binding's initial null push (MethodName=null, provider Data became the instance). Writing a CLR property from OWTS is real; pushing a chosen constant is not.

## 14 D3 trigger-setter binding write (S) — **blocked**
Same goal with the OWTS binding as the DataTrigger Setter value and "Clear" as the style default: the binding pushed its own empty value, not the default. Two different mechanisms failed, so **conditional effect selection is closed for strict**. (Effects remain document-order or Refresh-driven; the only data-driven conditional effect found is SQL's own `WHERE`.)

## 15 F2 EF Core from XAML (P) — **partial / blocked**
`DbContextOptionsBuilder` constructed; `SqliteDbContextOptionsBuilderExtensions.UseSqlite(builder, "Data Source=ef.db", null)` invoked; `get_Options` returned `DbContextOptions<DbContext>` — all from XAML. Blocked at `new DbContext(options)`: `x:Arguments` receives the provider, not its Data ("No matching constructor", input kept as `F2-ef-core-ctx-fail.xaml.txt`). Independently, `Add`/`SaveChanges` would need an entity model type; the baseline's `DemoTimeCard` is `internal` to the baseline exe and adding a type is forbidden. So EF Core `Add/SaveChanges` is **not demonstrated**; raw `Microsoft.Data.Sqlite` (iteration 07/11) is the package-backed route.

---
# Iteration 16 — the "raw dynamic argument" experiment (several probes under one hypothesis)

Budget note: this is one capability-sized hypothesis ("the missing late-bound-argument primitive can be worked around") executed as sub-probes H1, H2, S2, P2, F3/F4. It is the 16th and final iteration; the sub-probes stretch the plan's "one probe per iteration" discipline, which I'm flagging rather than hiding.

## Hypothesis and mechanism: mutable carriers
`ObjectDataProvider` parameters are evaluated at call time and passed **by reference**. A raw `char[]`/`byte[]` declared in XAML is therefore a *carrier*: some earlier provider overwrites it in place, a later provider reads it. Writers found (all built-in, all with a dynamic *receiver*, which providers do unwrap): `string.CopyTo(int, char[], int, int)` (receiver = a dynamic string) and `Encoding.ASCII.GetBytes(char[], int, int, byte[], int)`. Dynamic number → text comes from `Int32.ToString("0")` (receiver = the draw).

## H1 carrier → SQLite (P) — pass
`Random(42).Next(10,20)` → `ToString("0")` → `CopyTo(chars)` → `ASCII.GetBytes(chars → bytes)` → `SqliteParameter("@h", bytes)` (BLOB, read at execute time) → `CAST(@h AS INTEGER)`. `select * from T` → **16**: a seeded draw reached the database. Carrier contents observed `chars=[1,6]`, `bytes=[49,54]`.

## H2 carrier → DataTable arithmetic (S) — pass
Four draws written into an XML byte[] carrier at fixed offsets → `MemoryStream(byte[])` → `DataTable.ReadXml` → `Compute("Sum(h)")` = **53** (16+11+11+15). Notes: `DataTable` has no schema inference from XML, so columns are added via providers calling `Columns.Add(DataColumn)` (XAML cannot populate `DataColumnCollection`: "Missing key value on DataColumn").

## S2 integrated strict-built-in — pass (strict grade, XML persistence instead of SQLite)
`strict-built-in/program.xaml` (generated by `tools/gen_strict.py`, committed output is plain XAML). Flow: 4 seeded draws → xml1 carrier → table1 → total (`Sum`) and prefix sums (`Compute("Sum(h)","id<k")`: 0, 16, 27, 38) → xml2 carrier with id/cat/user/h/b/demo → table2 → `DataView RowFilter="b <= 40"` (termination guard: a card is kept only if the total *before* it is ≤ 40) → `ToTable` → `WriteXml` on a pool thread (`IsAsynchronous`). Window shows `Total simulated hours: 53`, a DataTrigger shows "over 40 h: batch complete" (CompareTo(40)=1), storyboard animation as before, explicit background `Thread` id 7 started/joined. Two runs (t1, t2): identical traces and a **byte-identical** XML file (sha256 prefix 94ac35b93f8248ab). Guard is live: with `RowFilter="b <= 30"` only Meetings/Coding/Debugging are kept (checked in a throwaway copy, not committed).
Provenance: DataTable/DataView/Encoding/Random/Thread are BCL (built-in); no package needed. The conditional is a `DataView` filter / `DataTable.Compute` expression string — a built-in generic expression engine, analogous to the SQL case the owner accepted.

## P2 integrated package-backed-pure — pass
`package-backed-pure/program.xaml` (generated by `tools/gen_pkg.py`). Same draws, now inserted via BLOB parameter carriers; SQL guard `WHERE (SELECT COALESCE(SUM(Hours),0) FROM DemoTimeCards) <= 40`; summary on a pool thread bound into the window: `Saved locally: 4 cards, 53.0 hours`. Rows: Meetings 16, Coding 11, Debugging 11, Learning 15 (all `DemoUser`, IsDemo=1). Two fresh runs (p1, p2) identical. This supersedes the iteration-11 SQL-formula hours: the **seeded Random now feeds the DB**. (A stale run directory from the old design briefly produced 3 rows; `run.ps1` now refuses reused run ids.)

## F3/F4 EF Core `DbContext` — blocked (second mechanism, closed)
F2 (x:Arguments) failed earlier. F3 tried ODP `ConstructorParameters=[provider]`: F4 shows ODP does not unwrap providers there either (`obsRnd2` with a provider seed → Data null, no error). Carriers do not help because the argument must be a *typed raw object* (`DbContextOptions`), and carriers only move data (bytes/chars) — no built-in found that stores a receiver object itself. Two mechanisms failed → closed per the plan's rule. EF `Add/SaveChanges` additionally lacks a usable model type.

## What the carrier primitive changes
It removes "no late-bound scalar argument" as a blocker for **data** (numbers/text), not for **typed object** arguments. Remaining strict gaps: typed-object arguments (EF), an unbounded loop (all repetition is unrolled to 4 draws), and conditional *effect selection* is only available through expression engines (DataView filter, SQL WHERE), not through triggers (D2/D3).
