# LINQ challenge, Variant A: one fluent method-chain statement

**Teaches you:** LINQ method chains, end to end.

One `;`-terminated expression statement, built entirely from LINQ method calls. It generates a fixed 40-hour timecard, tracks and saves it through EF Core and SQLite, crosses the `IQueryable<T>` → `IEnumerable<T>` boundary, and builds, shows, pulses, and closes a WPF **DEMO ONLY** terminal window - all inside that one statement. No `RunEverything`-style helper does the real work; `Main` only sets up the STA thread, the `DbContext`, and the `Application` before calling it.

## Run it

Needs Windows and the .NET 10 SDK.

```powershell
cd src\LinqChallenge1
dotnet restore
dotnet run
```

A small terminal-styled window appears, pulses three times, and closes itself; the process then exits on its own. Records land in `%LOCALAPPDATA%\LinqChallenge1\timecards.db`; delete that file to start fresh (each run's rows are tagged with a fresh `RunId`, so the window's report always shows just that run's 40.0h, even though the file keeps every run's history, like the other entries in this repo).

```powershell
.\check.ps1    # build, structural check, one end-to-end run against a throwaway DB
```

## How the stunt works

The fixed work week (`WorkWeek`, five 8-hour days: Planning / Implementation / Review / Testing / Documentation) and the challenge statement live in [`Program.cs`](Program.cs). Reading top to bottom, the one statement is:

| Stage | LINQ operator | What it does |
| --- | --- | --- |
| 1 | `Aggregate` | Folds the fixed days into tracked `TimecardEntry` entities, refusing any day that would push the running total past 40h. Eager, so it runs first. |
| - | tuple `(…, ctx.SaveChanges())` | Tuple elements evaluate left to right, so `SaveChanges()` only runs once every entity above is tracked. |
| 2 | `Enumerable.Repeat(…, 1).SelectMany` | Crosses from the in-memory fold into EF Core's `IQueryable<T>` (`Where`/`OrderBy`/`Select` - all SQL-translatable), then explicitly back with `AsEnumerable()`. The outer sequence has exactly one element, so the query runs exactly once. |
| 3 | `Aggregate` | Back on LINQ to Objects: folds the persisted rows into a report (`Lines`, `Total`). |
| 4 | `Enumerable.Repeat(…, 1).Select` | Builds, styles, and shows the WPF window, inline. |
| 5 | `.Select` | Starts a finite pulse (`DoubleAnimation`, `AutoReverse`, three repeats), then calls `Application.Run()` to pump the dispatcher until the completion handler closes the window and shuts the app down. |
| final | `.Aggregate(0, …)` | Forces the whole lazy tail (stages 2-5) to actually execute. |

## The `void`-to-value trick

WPF and EF Core are full of `void` methods - `Add`, `Show`, `BeginAnimation`, `Close`, `Shutdown` - and a LINQ chain only has room for values. Every side effect above sits inside an inline `new Func<T>(() => { sideEffect(); return value; }).Invoke()`, immediately invoked right where the chain needs its return value. It is a deliberate compromise, not a recommendation: ordinary code would just write a statement.

## Why two nested `Enumerable.Repeat(…, 1)` calls

C# only allows a handful of expression shapes as a top-level expression statement - invocation, object creation, assignment, increment/decrement, `await` - not an arbitrary `&&` or `is` expression. That rules out binding intermediate stages to a pattern-matched local (`x is var report && …`) at the top level: the statement has to *end* in an invocation. So instead of naming the fold-result or the report, each is nested directly as the argument to the next `Enumerable.Repeat(…, 1)`, which turns a single computed value back into a one-element sequence so the next stage can stay a genuine LINQ operator (`SelectMany`, `Select`) rather than a bare method call. The whole statement is one deeply nested expression tree whose outermost call is `.Aggregate(…)` - an invocation, which is legal.

## Honest fine print

- `SaveChanges()` is called once, eagerly, at the point where the outer `Enumerable.Repeat(…, 1)` call evaluates its argument - before any of the lazy LINQ-to-Objects/EF stages begin enumerating. That is still entirely inside the one statement; it just is not deferred to the final `Aggregate`'s enumeration the way `Select`/`SelectMany` stages are. `Aggregate` is an eager LINQ operator by definition, so some eagerness here is unavoidable.
- The accumulator state in both `Aggregate` calls is mutated in place (`list.Add(...)`) rather than rebuilt immutably. That mirrors the mutation shortcut the original `ModernChallenge1` takes with `i.totalHours.Add(...)`, and is called out here for the same reason: it is a pragmatic shortcut, not a LINQ-purity claim.
- `Application.Run()` (no window argument) is called from inside a `.Select` lambda, which is what actually pumps WPF dispatcher messages so the window paints and the animation ticks. `ShutdownMode` is set to `OnExplicitShutdown` so the animation's `Completed` handler, not an implicit "last window closed" rule, decides when the app (and `Run()`) exits.
- `Console.WriteLine` calls inside the window-creation stage exist purely so `check.ps1` can verify the persisted report from stdout, without needing a SQLite CLI tool on the test machine.

See [the root README](../../README.md#the-results-so-far) for how this compares to the other one-statement entries, and [`src/LinqChallenge2`](../LinqChallenge2/README.md) for the query-expression variant of the same idea.
