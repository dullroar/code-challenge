using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;

// LINQ challenge, Variant B: one SQL-like C# query-expression statement, plus exactly one
// terminal materialization call outside it (still the same expression statement).
//
// As much of this as C# will allow is written as "from"/"let"/"where"/"select", including
// the two places query syntax can genuinely carry the EF Core round trip: the FROM/WHERE
// that caps and tracks the real five-row work week, and the second FROM that crosses the
// IQueryable<T> -> IEnumerable<T> boundary into the persisted rows. Wherever a "let" has to
// smuggle a void-returning WPF/EF call into a value, the inline Func<T>.Invoke() wrapper is
// itself wrapped in a throwaway one-row query expression (`from _x in Enumerable.Repeat(0,
// 1) select ....Invoke()).Single()`) purely so that every component, not just the two
// headline stages, is phrased as a query - turtles all the way down, deliberately.
//
// Two things still cannot be query syntax, because the language has no keyword for them:
// Aggregate (folding many rows into one report) and Enumerable.Repeat/Sum/ToList/Single
// (collapsing a value back into a one-row sequence, or forcing/extracting one). Both are
// called out below, exactly where they appear.
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
        (
            // Second query expression: one pseudo-row carrying the already-folded report,
            // so the window and the pulse each run exactly once, as a "let" apiece.
            from r in Enumerable.Repeat(
                (
                    // First query expression: the real driving force. FROM the pseudo-row
                    // that carries the capped-and-tracked work week, LET SaveChanges run
                    // once every entity is tracked, FROM (a second, genuine "from") the
                    // persisted EF Core rows - the IQueryable<T> -> IEnumerable<T> crossing
                    // - LET each row's display line, SELECT the (hours, line) pair.
                    from _pseudo in Enumerable.Repeat(
                        (
                            // The innermost query: FROM the real five-row work week, WHERE
                            // the running total so far (a prefix sum over the rows up to
                            // and including this one - itself a tiny embedded query, since
                            // query syntax has no mutable accumulator) has not exceeded the
                            // cap, LET the entity be tracked through EF Core, SELECT it.
                            from day in WorkWeek
                            where (from d in WorkWeek.Take(Array.IndexOf(WorkWeek, day) + 1)
                                   select d.Hours)
                                      .Sum() <= MaxWeeklyHours
                            let tracked =
                                (from _track in Enumerable.Repeat(0, 1)
                                 select new Func<TimecardEntry>(() => ctx.Timecards.Add(new TimecardEntry
                                 {
                                     WorkDate = day.Date,
                                     Hours = day.Hours,
                                     Description = day.Description,
                                     RunId = runId
                                 }).Entity).Invoke())
                                    .Single()
                            select tracked
                        )
                            // The innermost query's own terminal op: forces FROM/WHERE/LET/
                            // SELECT to run, in row order, right here - still "outside the
                            // query expression but in the same statement", exactly as the
                            // plan allows. No query-syntax keyword exists for ToList, same
                            // as Sum and Single above.
                            .ToList(),
                        1)
                    let saved =
                        (from _save in Enumerable.Repeat(0, 1)
                         select ctx.SaveChanges())
                            .Single()
                    from persisted in
                        // A gratuitously embedded query around the EF Core phase: the
                        // "from" keyword is genuine (this is the real IQueryable<T> ->
                        // IEnumerable<T> crossing), the inner "select p" is pure theater.
                        from p in ctx.Timecards
                            .Where(e => e.RunId == runId)
                            .OrderBy(e => e.WorkDate)
                            .Select(e => new { e.WorkDate, e.Hours, e.Description })
                            .AsEnumerable()
                        select p
                    let line =
                        (from _line in Enumerable.Repeat(0, 1)
                         select $"{persisted.WorkDate:yyyy-MM-dd}  {persisted.Hours,4:F1}h  {persisted.Description}")
                            .Single()
                    select (Hours: persisted.Hours, Line: line)
                )
                    // No query-syntax keyword exists for Aggregate: folding many rows into
                    // one report has to be a method call, right where the plan expects the
                    // query expression's one terminal operation to sit.
                    .Aggregate(
                        (Lines: new List<string>(), Total: 0d),
                        (acc, row) => (
                            Lines: (from _fold in Enumerable.Repeat(0, 1)
                                    select new Func<List<string>>(() =>
                                    {
                                        acc.Lines.Add(row.Line);
                                        return acc.Lines;
                                    }).Invoke())
                                        .Single(),
                            Total: acc.Total + row.Hours)),
                1)
            let window =
                (from _win in Enumerable.Repeat(0, 1)
                 select new Func<Window>(() =>
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
                                 // Yet another gratuitous embedded query: a "from ... select"
                                 // identity pass over the already-built lines, purely so this
                                 // join is also phrased as query syntax.
                                 Text = "LINQ ONE-STATEMENT CHALLENGE - VARIANT B - DEMO ONLY\n" +
                                        "-----------------------------------------------------\n" +
                                        string.Join("\n", from l in r.Lines select l) +
                                        "\n-----------------------------------------------------\n" +
                                        $"TOTAL: {r.Total:F1}h  (cap: {MaxWeeklyHours:F0}h)"
                             }
                         }
                     };
                     w.Show();
                     return w;
                 }).Invoke())
                    .Single()
            let pulse =
                (from _pulse in Enumerable.Repeat(0, 1)
                 select new Func<Window>(() =>
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
                    .Single()
            select pulse
        )
            // Terminal operation, outside the (outer) query expression but inside this same
            // statement: forces the single pseudo-row - and everything nested inside it,
            // all the way down - to actually run. Also an invocation, as C# requires for a
            // top-level expression statement.
            .Single();
        // ============================= END ONE STATEMENT ===============================
    }
}
