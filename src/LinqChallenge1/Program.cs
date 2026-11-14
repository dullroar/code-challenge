using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;

// LINQ challenge, Variant A: one fluent LINQ method-chain expression statement.
//
// Everything the challenge requires - capping a fixed timecard at 40 hours, tracking
// and saving it through EF Core, crossing the IQueryable<T> -> IEnumerable<T> boundary,
// and building/showing/pulsing/closing a WPF "terminal" window - happens inside the one
// expression statement marked below. Only entity/DbContext classes, static fixture data,
// and the minimal STA/Application/DbContext shell in Main live outside it.
//
// DEMO ONLY: the timecard is fictional, fixed, and capped at 40 hours. It is not
// connected to, and must not be used for, a real time-reporting system.
namespace LinqChallenge1;

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
        // The whole challenge workflow is the argument tree and method chain below, ending
        // in the single invocation .Aggregate(...) that Main's statement calls - C# requires
        // a top-level expression statement to be an invocation, so every stage nests inside
        // that one final call rather than being bound to intermediate local variables.
        Enumerable.Repeat(
            Enumerable.Repeat(
                (
                    // Stage 1 (LINQ to Objects, eager): fold the fixed work week into tracked
                    // entities, refusing any day that would push the running total past 40.
                    WorkWeek.Aggregate(
                        (Total: 0d, Entries: new List<TimecardEntry>()),
                        (state, day) => state.Total + day.Hours > MaxWeeklyHours
                            ? state
                            : (Total: state.Total + day.Hours,
                               Entries: new Func<List<TimecardEntry>>(() =>
                               {
                                   state.Entries.Add(ctx.Timecards.Add(new TimecardEntry
                                   {
                                       WorkDate = day.Date,
                                       Hours = day.Hours,
                                       Description = day.Description,
                                       RunId = runId
                                   }).Entity);
                                   return state.Entries;
                               }).Invoke())).Entries,
                    // SaveChanges runs after every entity above is tracked (tuple elements
                    // evaluate left to right), still inside this one expression.
                    ctx.SaveChanges()
                ),
                1)
                // Stage 2: cross from the in-memory fold into EF Core's IQueryable<T>, then
                // explicitly back to IEnumerable<T> with AsEnumerable(). SelectMany runs the
                // EF query exactly once because the outer sequence has exactly one element.
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
                // Stage 4: create, style, and show the terminal window inline.
                .Select(r => new Func<Window>(() =>
                {
                    Console.WriteLine($"PERSISTED {r.Lines.Count} rows, total={r.Total:F1}h");
                    r.Lines.ForEach(Console.WriteLine);

                    var window = new Window
                    {
                        Title = "LINQ Challenge Terminal (Variant A: fluent chain) - DEMO ONLY",
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
                                Text = "LINQ ONE-STATEMENT CHALLENGE - VARIANT A - DEMO ONLY\n" +
                                       "------------------------------------------------------\n" +
                                       string.Join("\n", r.Lines) +
                                       "\n------------------------------------------------------\n" +
                                       $"TOTAL: {r.Total:F1}h  (cap: {MaxWeeklyHours:F0}h)"
                            }
                        }
                    };
                    window.Show();
                    return window;
                }).Invoke())
                // Stage 5: pulse the window with a finite animation, then pump the
                // dispatcher until the completion handler closes the window and shuts
                // the application down.
                .Select(window => new Func<Window>(() =>
                {
                    var pulse = new DoubleAnimation(1.0, 0.35, TimeSpan.FromMilliseconds(500))
                    {
                        AutoReverse = true,
                        RepeatBehavior = new RepeatBehavior(3)
                    };
                    pulse.Completed += (_, _) =>
                    {
                        window.Close();
                        app.Shutdown();
                    };
                    window.BeginAnimation(UIElement.OpacityProperty, pulse);
                    app.Run();
                    return window;
                }).Invoke())
                // Terminal operation: forces the whole lazy tail of the pipeline to run.
                // (An invocation, as C# requires for a top-level expression statement.)
                .Aggregate(0, (count, _) => count + 1);
        // ============================= END ONE STATEMENT ===============================
    }
}
