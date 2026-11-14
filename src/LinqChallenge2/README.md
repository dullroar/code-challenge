# LINQ challenge, Variant B: one SQL-like query-expression statement

The same demo as [`src/LinqChallenge1`](../LinqChallenge1/README.md) - a fixed 40-hour timecard, tracked and saved through EF Core and SQLite, crossing the `IQueryable<T>` → `IEnumerable<T>` boundary, and a WPF **DEMO ONLY** terminal window that shows, pulses, and closes itself - but written so the data-shaping narrative is a genuine SQL-like C# query expression (`from` / `where` / `let` / `select`), driven by the real five-row work week, plus exactly one terminal call outside it, in the same statement.

## Run it

Needs Windows and the .NET 10 SDK.

```powershell
cd src\LinqChallenge2
dotnet restore
dotnet run
```

Same behavior as Variant A: one terminal-styled window appears, pulses three times, and closes itself; the process exits on its own. Records land in `%LOCALAPPDATA%\LinqChallenge2\timecards.db`.

```powershell
.\check.ps1    # build, structural check (genuine from/where/let/select), one end-to-end run
```

## How the stunt works

C# query syntax is surface sugar over the same `Select`/`SelectMany`/`Where` calls Variant A uses directly - it is not a different execution engine. Query syntax also has no running-total accumulator across rows, but it does not need one: `where` can recompute the running total as a prefix sum over the rows up to and including the current one, with no mutable state at all. That is genuinely `FROM`/`WHERE`/`SELECT`, and it is driven by the real `WorkWeek` array, not a stand-in:

```csharp
from day in WorkWeek
where WorkWeek.Take(Array.IndexOf(WorkWeek, day) + 1).Sum(d => d.Hours) <= MaxWeeklyHours
let tracked = /* ctx.Timecards.Add(...), wrapped to return the entity */
select tracked
```

That query expression's own terminal operation - `.ToList()`, chained directly onto the parenthesized query - is exactly what the plan calls for: "use one terminal operation... outside the query expression but in the same expression statement." It also happens to be the natural place where the *rest* of the workflow has to pick up. [`Program.cs`](Program.cs), read stage by stage:

| Stage | Shape | What it does |
| --- | --- | --- |
| 1 | `from`/`where`/`let`/`select`, then `.ToList()` | The real query expression above. `where` caps the week at 40h without mutable state; `let` tracks each surviving day's entity through EF Core. `.ToList()` is its terminal op, forcing it to run, in row order, right here. |
| - | tuple `(…, ctx.SaveChanges())` | Tuple elements evaluate left to right, so `SaveChanges()` runs once every entity above is tracked - once total, not once per row. |
| 2 | `Enumerable.Repeat(…, 1).SelectMany` | Crosses from the materialized row list into EF Core's `IQueryable<T>` (`Where`/`OrderBy`/`Select` - SQL-translatable), then explicitly back with `AsEnumerable()`. The outer sequence has exactly one element, so the EF query runs exactly once, not once per surviving row. |
| 3 | `Aggregate` | Back on LINQ to Objects: folds the persisted rows into a report (`Lines`, `Total`). |
| 4 | `Enumerable.Repeat(…, 1).Select` | Builds, styles, and shows the WPF window, inline - once. |
| 5 | `.Select` | Starts a finite pulse, then calls `Application.Run()` to pump the dispatcher until the completion handler closes the window and shuts the app down. |
| final | `.Aggregate(0, …)` | Forces the whole lazy tail (stages 2-5) to actually execute. |

## Important language constraint

Once the query expression's job (shaping and capping the source rows) is done, query syntax has nothing left to offer: there is no second `from` that can cross into `ctx.Timecards` without re-running once per row already produced by stage 1, and no `let` that runs exactly once across every row rather than once per row. So stages 2-5 fall back to the identical `Enumerable.Repeat(…, 1)` collapse-and-chain technique, and the identical inline `new Func<T>(() => { sideEffect(); return value; }).Invoke()` pattern, that Variant A uses for its whole workflow. That is not an accident: it is the actual answer to "what does query syntax buy you here?" - a real, better-looking `FROM`/`WHERE`/`SELECT` for the part that is naturally row-shaped, and no advantage at all for the part that fundamentally needs to run exactly once.

An earlier draft of this variant dodged that by driving the *whole* query (including the EF read-back and the window) from a single fabricated one-row table, so every stage could be a `let`. It was rejected: it is a cop-out dressed as query syntax, the `where` clause it started from had no real multi-row source to filter, and it quietly contradicts the plan's own instruction to drive from "a fixed LINQ-to-Objects input" and avoid turning the query expression into something that "merely calls a fluent helper-like chain." Stage 1 above is real; the tail is honestly labeled as not benefiting from query syntax at all.

## Honest fine print

- Same mutation-free, prefix-sum cap as described above replaces the mutable-accumulator fold Variant A uses for the same job - a genuine difference in how the two variants express "cap at 40h," not just a syntax skin.
- The same eager-at-build-time `SaveChanges()` and `Aggregate`-mutates-in-place caveats from Variant A's README apply to stages 2-5 here (see [its README](../LinqChallenge1/README.md#honest-fine-print)), since those stages are the same technique.
- `Console.WriteLine` calls inside the window-creation stage exist purely so `check.ps1` can verify the persisted report from stdout.

See [the repository README](../../README.md#the-family) for how this compares to the other one-statement entries, and [`src/LinqChallenge1`](../LinqChallenge1/README.md) for the fluent-chain variant of the same idea.
