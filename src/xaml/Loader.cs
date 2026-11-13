using System.IO;
using System.Windows;
using System.Windows.Markup;

// The entire "application" is one expression that hands a XAML file to the XAML parser.
// Every behavior of the demo lives in the .xaml program that gets loaded.
internal static class Loader
{
    [STAThread]
    private static void Main(string[] args) =>
        new Application().Run(
            // (CreateDirectory is never null; it just lets the data folder exist inside the same expression.)
            Directory.CreateDirectory("data") is null
                ? null
                : (Window)XamlReader.Load(File.OpenRead(args[0])));
}
