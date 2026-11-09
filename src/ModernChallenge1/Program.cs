using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;
using System.Xml.Linq;

// A modernized, intentionally eccentric version of Jim Lehmer's 2008 C# 3.0 challenge.
//
// The objective remains: make a small WPF program using exactly one C# statement - a
// for statement whose body is empty. The point is comparison, not production style.
//
// Modern substitutions:
//   - SDK-style .NET project targeting net10.0-windows.
//   - EF Core + local SQLite rather than LINQ-to-SQL + Northwind.
//   - System.Random.Shared rather than a short-lived Random instance.
//
// The program only writes clearly identified *demo* time cards into a SQLite database
// under LocalApplicationData. It is not connected to, and must not be used for, a real
// time-reporting system.
namespace Challenge1;

internal static class Program
{
    [STAThread] // Still required for WPF.
    private static void Main()
    {
        for // Still the only statement.
        (
            // The anonymous object is still the iterator-state wrapper: the for
            // initializer permits only one declaration, even when several types are needed.
            var i = new
            {
                // XElement is still deliberately gratuitous, but now its text becomes part
                // of ordinary runtime XAML rather than an external resource.
                xmlAnim = new XElement(
                    "DoubleAnimation",
                    new XAttribute("Storyboard.TargetName", "myVB"),
                    new XAttribute("Storyboard.TargetProperty", "(Viewbox.Opacity)"),
                    new XAttribute("From", "1"),
                    new XAttribute("To", "0.45"),
                    new XAttribute("Duration", "0:0:1.2"),
                    new XAttribute("AutoReverse", "True"),
                    new XAttribute("RepeatBehavior", "Forever")),
                totalHours = new List<double>(),
                user = Environment.UserName,
                ctx = new DemoTimeCardContext(),
                rnd = Random.Shared,
                categories = new List<string> { "Meetings", "Coding", "Debugging", "Learning" }
                    .GetEnumerator() as IEnumerator<string>,
                app = new Application { ShutdownMode = ShutdownMode.OnLastWindowClose },
                mutex = new Mutex(false, "ModernChallenge1DemoMutex")
            }
                //   *
                //  *
        ;   // **************** FIRST SEMICOLON ****************
                //  *
                //   *
            // LINQ to Objects is deliberately retained. When the demo batch reaches
            // approximately one work week, show the result and terminate the loop.
            ((from hours in i.totalHours select hours).Sum()) <= 40d && i.categories!.MoveNext()
                ? true
                : new Func<bool>(
                    () => Double.IsNaN(
                        i.app.Run(
                            new Window
                            {
                                Title = "Only One STATEMENT (modern .NET demo)",
                                Width = 520,
                                Height = 320,
                                ResizeMode = ResizeMode.NoResize,
                                Content = (Viewbox)XamlReader.Load(
                                    new MemoryStream(
                                        Encoding.UTF8.GetBytes(
                                            "<Viewbox xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' " +
                                            "xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' " +
                                            "Name='myVB' Width='520' Height='320'>" +
                                            "<Grid Background='#172033' Margin='10'>" +
                                            "<Grid.RowDefinitions><RowDefinition Height='Auto'/><RowDefinition/></Grid.RowDefinitions>" +
                                            "<TextBlock Margin='28,24,28,0' Foreground='#FFCE56' FontWeight='Bold' " +
                                            "FontSize='18' TextAlignment='Center' Text='DEMO ONLY - no real time system is involved'/>" +
                                            "<TextBlock Grid.Row='1' Margin='28' Foreground='White' FontWeight='Bold' " +
                                            "FontSize='24' TextAlignment='Center' Text='Total simulated hours: " +
                                            (from hours in i.totalHours select hours).Sum().ToString("F1") +
                                            "&#x0a;&#x0a;Saved locally for the modernization exercise.'/>" +
                                            "<FrameworkElement.Triggers><EventTrigger RoutedEvent='FrameworkElement.Loaded'>" +
                                            "<BeginStoryboard><Storyboard>" +
                                            i.xmlAnim +
                                            "</Storyboard></BeginStoryboard></EventTrigger>" +
                                            "</FrameworkElement.Triggers>" +
                                            "</Grid></Viewbox>")),
                                    new ParserContext { BaseUri = new Uri("pack://siteoforigin:,,,") })
                            }))).Invoke()
               //   *
               //  *
        ;  // **************** LAST SEMICOLON ****************
               //  *
               //   *
            // The data access shape intentionally resembles InsertOnSubmit/SubmitChanges.
            // Mutex ownership prevents concurrent access to EF Core's non-thread-safe context.
            i.mutex.WaitOne(),
            i.totalHours.Add(i.rnd.Next(10, 20)),
            i.ctx.TimeCards.Add(
                new DemoTimeCard
                {
                    Category = i.categories!.Current,
                    Hours = i.totalHours.Last(),
                    UserId = i.user,
                    Year = DateTime.Now.Year,
                    Week = System.Globalization.ISOWeek.GetWeekOfYear(DateTime.Now),
                    IsDemo = true
                }),
            i.mutex.ReleaseMutex(),
            // The gratuitous background thread and reflection are retained as a historic
            // contrast. The mutex keeps SaveChanges from overlapping the next Add operation.
            new Thread(
                new ThreadStart(
                    () => new StringBuilder(
                        i.mutex.GetType().GetMethod(nameof(Mutex.WaitOne), Type.EmptyTypes)!
                            .Invoke(i.mutex, Array.Empty<object>())!.ToString()!.Length +
                        (int)(i.ctx.GetType().GetMethod(nameof(DemoTimeCardContext.SaveChanges), Type.EmptyTypes)!
                            .Invoke(i.ctx, null) is null ? 0 : 1) +
                        (int)(i.mutex.GetType().GetMethod(nameof(Mutex.ReleaseMutex), Type.EmptyTypes)!
                            .Invoke(i.mutex, Array.Empty<object>()) is null ? 0 : 1)).ToString()))
            { IsBackground = true }.Start()
        )
        { /* Intentionally empty. */ }
    }
}
