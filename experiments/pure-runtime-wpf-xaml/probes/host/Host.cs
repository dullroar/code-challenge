// GENERIC probe host: loads a .xaml file with XamlReader at runtime, pumps the dispatcher for N ms,
// then dumps resources / named-element state at several lifecycle points.
// It contains NO demo/time-card logic.
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Markup;
using System.Windows.Threading;

internal static class Host
{
    [STAThread]
    private static int Main(string[] a)
    {
        var path = a[0]; var ms = a.Length > 1 ? int.Parse(a[1]) : 1500;
        Console.WriteLine($"host thread={Environment.CurrentManagedThreadId} sta={Thread.CurrentThread.GetApartmentState()}");
        object root;
        try { using var s = File.OpenRead(path); root = XamlReader.Load(s); }
        catch (Exception e) { Console.WriteLine("LOAD-FAIL " + e.GetType().Name + ": " + e.Message); for (var i = e.InnerException; i != null; i = i.InnerException) Console.WriteLine("  inner " + i.GetType().Name + ": " + i.Message); return 2; }
        Console.WriteLine("loaded root=" + root.GetType().FullName);
        Dump(root, "after-load(parse-time)");
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        if (root is FrameworkElement r0) r0.Loaded += (_, _) => Dump(root, "Loaded-event");
        Dispatcher.CurrentDispatcher.BeginInvoke(DispatcherPriority.ContextIdle, () => Dump(root, "context-idle"));
        if (root is Window w) w.Show();
        var t = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(ms) };
        t.Tick += (_, _) =>
        {
            Dump(root, "final");
            var png = Environment.GetEnvironmentVariable("HOST_PNG");
            if (png != null && root is Window win) Snap(win, png);
            app.Shutdown();
        };
        t.Start();
        app.Run();
        return 0;
    }
    static void Dump(object root, string when)
    {
        Console.WriteLine("--- " + when);
        if (root is not FrameworkElement fe) return;
        var keys = fe.Resources.Keys.Cast<object>().ToList();
        if (keys.Any(k => k.ToString()!.StartsWith("obs"))) keys = keys.Where(k => k.ToString()!.StartsWith("obs")).ToList(); // reading Data can trigger a lazy provider
        foreach (var k in keys.OrderBy(k => k.ToString()))
        {
            var v = fe.Resources[k];
            if (v is ObjectDataProvider odp) Console.WriteLine($"ODP[{k}] data={Fmt(odp.Data)} error={odp.Error?.GetType().Name}:{odp.Error?.Message}");
            else Console.WriteLine($"RES[{k}] {Fmt(v)}");
        }
        if (fe is Window ww && ww.Content is TextBlock tb) Console.WriteLine($"content.Text={tb.Text} tag={tb.Tag} style={(tb.Style==null?"null":"set")}");
        foreach (var tx in Texts(fe)) Console.WriteLine("TEXT: " + tx);
        foreach (var nm in Named(fe)) Console.WriteLine("NAMED: " + nm);
        Console.WriteLine($"root.Opacity={fe.Opacity} tag={Fmt(fe.Tag)}");
        if (fe is ContentControl cc && cc.Content is FrameworkElement c) Console.WriteLine($"content.Opacity={c.Opacity}");
    }
    // generic: render the window content to a PNG (visible smoke evidence); no demo logic
    static void Snap(Window w, string path)
    {
        if (w.Content is not FrameworkElement c) return;
        c.Measure(new Size(w.Width, w.Height)); c.Arrange(new Rect(0, 0, w.Width, w.Height)); c.UpdateLayout();
        var rtb = new System.Windows.Media.Imaging.RenderTargetBitmap((int)w.Width, (int)w.Height, 96, 96, System.Windows.Media.PixelFormats.Pbgra32);
        rtb.Render(c);
        var enc = new System.Windows.Media.Imaging.PngBitmapEncoder(); enc.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(rtb));
        using var f = File.Create(path); enc.Save(f);
        Console.WriteLine("PNG: " + path);
    }
    static IEnumerable<string> Named(DependencyObject d)
    {
        if (d is FrameworkElement fe && !string.IsNullOrEmpty(fe.Name)) yield return $"{fe.Name}.Opacity={fe.Opacity:F3}";
        foreach (var c in LogicalTreeHelper.GetChildren(d).OfType<DependencyObject>()) foreach (var x in Named(c)) yield return x;
    }
    static IEnumerable<string> Texts(DependencyObject d)
    {
        if (d is TextBlock t) yield return t.Text;
        foreach (var c in LogicalTreeHelper.GetChildren(d).OfType<DependencyObject>()) foreach (var x in Texts(c)) yield return x;
    }
    static string Fmt(object? o) => o is System.Collections.IEnumerable e && o is not string
        ? "[" + string.Join(",", e.Cast<object?>().Select(x => x?.ToString())) + "]" : (o?.ToString() ?? "null");
}
