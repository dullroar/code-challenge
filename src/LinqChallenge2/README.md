# LINQ challenge, Variant B: one SQL-like query-expression statement

The same demo as [`src/LinqChallenge1`](../LinqChallenge1/README.md) - a fixed 40-hour timecard, tracked and saved through EF Core and SQLite, crossing the `IQueryable<T>` → `IEnumerable<T>` boundary, and a WPF **DEMO ONLY** terminal window that shows, pulses, and closes itself - but written so nearly every component, not just the headline data-shaping stage, is phrased as a C# query expression (`from` / `where` / `let` / `select`). Where a `let` has to smuggle a `void`-returning WPF/EF call into a value, the inline `Func<T>.Invoke()` wrapper is itself nested inside a throwaway one-row query. Turtles all the way down, on purpose.

## Run it

Needs Windows and the .NET 10 SDK.

```powershell
cd src\LinqChallenge2
dotnet restore
dotnet run
```

Same behavior as Variant A: one terminal-styled window appears, pulses three times, and closes itself; the process exits on its own. Records land in `%LOCALAPPDATA%\LinqChallenge2\timecards.db`.

```powershell
.\check.ps1    # build, structural check (genuine query syntax at every layer), one end-to-end run
```

## How the stunt works

C# query syntax is surface sugar over the same `Select`/`SelectMany`/`Where` calls Variant A uses directly - it is not a different execution engine. [`Program.cs`](Program.cs) pushes that sugar as far as it goes, in two headline places and then everywhere else for good measure:

**The two places query syntax genuinely carries the EF Core round trip:**

```csharp
from day in WorkWeek                                   // FROM the real five-row work week
where (from d in WorkWeek.Take(Array.IndexOf(WorkWeek, day) + 1) select d.Hours).Sum() <= MaxWeeklyHours
let tracked = /* ctx.Timecards.Add(...), wrapped to return the entity */
select tracked
```

caps the week with a `where` clause that recomputes the running total as a prefix sum - no mutable accumulator - and

```csharp
from persisted in
    (
        from e in ctx.Timecards
        where e.RunId == runId
        orderby e.WorkDate
        select new { e.WorkDate, e.Hours, e.Description }
    ).AsEnumerable()
```

is a genuine second `from` clause crossing the `IQueryable<T>` → `IEnumerable<T>` boundary - exactly the shape the plan's own sketch calls for ("`from persisted item in DbContext.Timecards ...`"). The inner query is not a stand-in for a fluent `Where`/`OrderBy`/`Select` chain; `where`/`orderby`/`select` lower to exactly those calls, so EF Core's SQLite provider translates it exactly as it would the fluent version. `AsEnumerable()` is still the one piece no query keyword replaces - it stays a trailing call, like `ToList`/`Sum`/`Single` elsewhere, marking the boundary explicitly.

**Everywhere else, for the sake of the bit:** every `let` that needs a value back from a `void` WPF/EF call (`tracked`, `saved`, `line`, `window`, `pulse`) wraps its `new Func<T>(() => {...}).Invoke()` inside its own `from _x in Enumerable.Repeat(0, 1) select ....Invoke()` one-row query, then calls `.Single()` to pull the value back out. The window's text join (`string.Join("\n", from l in r.Lines select l)`) is the same idea applied to code that did not need it at all. None of this makes the program more correct; all of it makes the point that query syntax *can* reach into almost every corner, once you stop asking whether it should.

The whole thing is two nested query expressions (the second supplies the single already-folded report to the window/pulse `let`s, because `Aggregate` - folding many persisted rows into one report - has no query-syntax keyword and has to happen as a trailing method call in between), ending in one `.Single()`, which both forces the lazy pipeline to run and extracts the one value the outer pseudo-row was always going to produce.

## Important language constraint

Three things in this file cannot be query syntax, because the language simply has no keyword for them, and each is called out in a comment where it appears:

- **`Aggregate`** - folding N persisted rows into one `(Lines, Total)` report. There is no `fold`/`reduce` query clause.
- **`Enumerable.Repeat` / `.Take` / `.Sum` / `.ToList` / `.Single`** - every place a value needs to become a one-row sequence, be capped, be summed, be forced, or be pulled back out. Query syntax lowers to these same calls; it never replaces them.
- **`ctx.Timecards.Add(...)`, `window.Show()`, `app.Run()`, `window.BeginAnimation(...)`, `app.Shutdown()`** - the actual WPF/EF Core side effects. No syntax, query or fluent, turns a `void` method into an expression; that is what every inline `Func<T>.Invoke()` wrapper is for, with or without a throwaway query around it.

## Honest fine print

- The embedded one-row queries around `tracked`, `saved`, `line`, `window`, `pulse`, the `Lines` fold step, and the window's text join are gratuitous. Removing any of them and calling the wrapped expression directly would behave identically and read more plainly. They exist because the challenge asked for maximum, deliberate perversity - "twisted thinking is good thinking" - not because they improve the code. The EF phase's `where`/`orderby`/`select`, by contrast, is not gratuitous: it replaced an actual fluent `Where`/`OrderBy`/`Select` chain that was doing real work.
- Same prefix-sum cap and mutation-in-place caveats from the earlier draft apply here; see [Variant A's README](../LinqChallenge1/README.md#honest-fine-print) for the shared ones (eager `SaveChanges()` timing, in-place list mutation inside `Aggregate`).
- `Console.WriteLine` calls inside the `window` `let` exist purely so `check.ps1` can verify the persisted report from stdout.

See [the repository README](../../README.md#the-family) for how this compares to the other one-statement entries, and [`src/LinqChallenge1`](../LinqChallenge1/README.md) for the fluent-chain variant of the same idea.
