// DEMO ONLY. Fictional timecards, written to a scratch file under XDG_DATA_HOME. See README.md.
//
// The host draws four random hour counts (a regex cannot), hands them over as a unary "tape",
// fires ONE Regex.Match, and reports what the pattern captured. No loops, no callbacks, no
// MatchEvaluator. The pattern walks the categories, accumulates hours, and decides when to stop.
using System.Globalization;
using System.Text.RegularExpressions;

string Draw() => new('a', Random.Shared.Next(10, 20));

var m = Regex.Match(
    $"Meetings:{Draw()};Coding:{Draw()};Debugging:{Draw()};Learning:{Draw()};",
    @"\A(?:(?<b>)){41}(?:(?(b)(?<cat>(?(fm)(?(fc)(?(fd)(?(fl)(?!)|(?<fl>)Learning)|(?<fd>)Debugging)|(?<fc>)Coding)|(?<fm>)Meetings)):(?<hrs>(?:(?(b)(?<-b>))(?<s>)a){10,19});|(?!)))*");

var week = $"{ISOWeek.GetYear(DateTime.Now)}-W{ISOWeek.GetWeekOfYear(DateTime.Now):00}";
var report = string.Concat(
    $"# DEMO ONLY {DateTime.Now:s}\n",
    string.Concat(m.Groups["cat"].Captures.Zip(m.Groups["hrs"].Captures,
        (c, h) => $"{c.Value}\t{h.Length}\t{week}\tDEMO ONLY\n")),
    $"# captured total={m.Groups["s"].Captures.Count} entries={m.Groups["cat"].Captures.Count} DEMO ONLY\n");

var path = Path.Combine(
    Environment.GetEnvironmentVariable("XDG_DATA_HOME") ?? Path.Combine(Environment.GetEnvironmentVariable("HOME")!, ".local", "share"),
    "RegexDotnet", "demo-timecards.tsv");
Directory.CreateDirectory(Path.GetDirectoryName(path)!);
File.AppendAllText(path, report);

Console.Write($"match returned: {(m.Success ? "true" : "false")}\nrecords at {path} (latest run below)\n{report}");
return m.Success ? 0 : 1;
