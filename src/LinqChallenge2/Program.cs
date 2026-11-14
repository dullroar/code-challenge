using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;

// LINQ challenge, Variant B: one SQL-like C# query-expression statement, plus exactly one
// terminal materialization call outside it (still the same expression statement).
//
// The data-shaping narrative - cap the fixed work week at 40 hours and track each
// surviving entry - is genuine query syntax: FROM the work week, WHERE the running total
// so far does not exceed the cap (a prefix sum recomputed per row; query syntax has no
// mutable accumulator), LET the tracked entity, SELECT it. That query expression's own
// terminal op, .ToList(), is the one the plan allows "outside the query expression but in
// the same statement" - it just happens to also be where the persistence/EF/WPF tail
// begins, because query syntax has nothing left to offer once each row is already
// materialized: crossing the IQueryable<T> -> IEnumerable<T> boundary exactly once (not
// once per surviving row) and showing exactly one window both need a single pass over the
// already-finished row list, which is what the chained Enumerable.Repeat(..., 1) stages do.
//
// DEMO ONLY: the timecard is fictional, fixed, and capped at 40 hours. It is not
// connected to, and must not be used for, a real time-reporting system.
namespace LinqChallenge2;

internal static class Program
{
    private const double MaxWeeklyHours = 40d;

    private static readonly (DateOnly Date, double Hours, string Description)[] WorkWeek =
    [
        (new DateOnly(2024, 1, 1), 8d, "Planning"),
        (new DateOnly(2024, 1, 2), 8d, "Implementation"),
        (new DateOnly(2024, 1, 3), 8d, "Review"),
        (new DateOnly(2024, 1, 4), 8d, "Testing"),
        (new DateOnly(2024, 1, 5), 8d, "Documentation"),
    ];

    [STAThread]
    private static void Main()
    {
        // Entry-point shell: STA thread, DbContext, and Application are scaffolding,
        // not the challenge workflow itself.
        var ctx = new TimecardDbContext();
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        var runId = Guid.NewGuid();

        // ============================== THE ONE STATEMENT ==============================
        // C# requires a top-level expression statement to be an invocation, so every stage
        // nests inside the arguments of the next call rather than being bound to an
        // intermediate local - the same reason Variant A nests two Enumerable.Repeat calls.
        Enumerable.Repeat(
            Enumerable.Repeat(
                (
                    // Stage 1: genuine FROM/WHERE/LET/SELECT, driven by the real five-row
                    // work week (no pseudo-table). WHERE recomputes the prefix sum up to
                    // and including this row - a running total without a mutable
                    // accumulator - and LET tracks the entity through EF Core.
                    (
                        from day in WorkWeek
                        where WorkWeek
                            .Take(Array.IndexOf(WorkWeek, day) + 1)
                            .Sum(d => d.Hours) <= MaxWeeklyHours
                        let tracked = new Func<TimecardEntry>(() => ctx.Timecards.Add(new TimecardEntry
                        {
                            WorkDate = day.Date,
                            Hours = day.Hours,
                            Description = day.Description,
                            RunId = runId
                        }).Entity).Invoke()
                        select tracked
                    )
                        // The query expression's own terminal op: forces FROM/WHERE/LET/
                        // SELECT to run, in row order, right here - still "outside the
                        // query expression but in the same statement", exactly as the
                        // plan allows.
                        .ToList(),
                    // Tuple elements evaluate left to right, so SaveChanges runs once
                    // every entity above is tracked - not once per row.
                    ctx.SaveChanges()
                ),
                1)
                // Stage 2: cross from the in-memory, already-materialized row list into EF
                // Core's IQueryable<T>, then explicitly back with AsEnumerable().
                // SelectMany runs the EF query exactly once because the outer sequence has
                // one element.
                .SelectMany(_ => ctx.Timecards
                    .Where(e => e.RunId == runId)
                    .OrderBy(e => e.WorkDate)
                    .Select(e => new { e.WorkDate, e.Hours, e.Description })
                    .AsEnumerable())
                // Stage 3 (back on LINQ to Objects): fold the persisted rows into a report.
                .Aggregate(
                    (Lines: new List<string>(), Total: 0d),
                    (acc, row) => (
                        Lines: new Func<List<string>>(() =>
                        {
                            acc.Lines.Add($"{row.WorkDate:yyyy-MM-dd}  {row.Hours,4:F1}h  {row.Description}");
                            return acc.Lines;
                        }).Invoke(),
                        Total: acc.Total + row.Hours)),
            1)
                // Stage 4: create, style, and show the terminal window inline - once, not
                // once per row.
                .Select(r => new Func<Window>(() =>
                {
                        Console.WriteLine($"PERSISTED {r.Lines.Count} rows, total={r.Total:F1}h");
                        r.Lines.ForEach(Console.WriteLine);

                        var w = new Window
                        {
                            Title = "LINQ Challenge Terminal (Variant B: query expression) - DEMO ONLY",
                            Width = 560,
                            Height = 360,
                            Background = Brushes.Black,
                            ResizeMode = ResizeMode.NoResize,
                            WindowStartupLocation = WindowStartupLocation.CenterScreen,
                            Content = new Border
                            {
                                BorderBrush = Brushes.LimeGreen,
                                BorderThickness = new Thickness(2),
                                Child = new TextBlock
                                {
                                    FontFamily = new FontFamily("Consolas"),
                                    FontSize = 15,
                                    Foreground = Brushes.LimeGreen,
                                    Margin = new Thickness(20),
                                    Text = "LINQ ONE-STATEMENT CHALLENGE - VARIANT B - DEMO ONLY\n" +
                                           "-----------------------------------------------------\n" +
                                           string.Join("\n", r.Lines) +
                                           "\n-----------------------------------------------------\n" +
                                           $"TOTAL: {r.Total:F1}h  (cap: {MaxWeeklyHours:F0}h)"
                                }
                            }
                        };
                        w.Show();
                        return w;
                    }).Invoke())
                    // Stage 5: pulse the window with a finite animation, then pump the
                    // dispatcher until the completion handler closes the window and shuts
                    // the application down.
                    .Select(window => new Func<Window>(() =>
                    {
                        var anim = new DoubleAnimation(1.0, 0.35, TimeSpan.FromMilliseconds(500))
                        {
                            AutoReverse = true,
                            RepeatBehavior = new RepeatBehavior(3)
                        };
                        anim.Completed += (_, _) =>
                        {
                            window.Close();
                            app.Shutdown();
                        };
                        window.BeginAnimation(UIElement.OpacityProperty, anim);
                        app.Run();
                        return window;
                    }).Invoke())
                    // Terminal operation: forces the whole lazy tail to run. (An
                    // invocation, as C# requires for a top-level expression statement.)
                    .Aggregate(0, (count, _) => count + 1);
        // ============================= END ONE STATEMENT ===============================
    }
}
