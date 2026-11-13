# AUTHORING AID (not part of any grade's source): expands the per-draw provider pipeline into plain XAML.
import sys

N = 4
CATS = ["Meetings", "Coding", "Debugging", "Learning"]
THRESHOLD = int(sys.argv[1]) if len(sys.argv) > 1 else 40
OUT = sys.argv[2] if len(sys.argv) > 2 else "package-backed-ef/program.xaml"


def odp(key, inst, meth, params="", extra=""):
    if params:
        return f'<ObjectDataProvider x:Key="{key}" {extra}ObjectInstance="{inst}" MethodName="{meth}"><ObjectDataProvider.MethodParameters>{params}</ObjectDataProvider.MethodParameters></ObjectDataProvider>'
    return f'<ObjectDataProvider x:Key="{key}" {extra}ObjectInstance="{inst}" MethodName="{meth}"/>'


def I(v):
    return f"<sys:Int32>{v}</sys:Int32>"


def S(v):
    return f"<sys:String>{v}</sys:String>"


def R(k):
    return f'<StaticResource ResourceKey="{k}"/>'


def SR(k):
    return "{StaticResource " + k + "}"


def chars(key, n):
    return f'<x:Array x:Key="{key}" Type="{{x:Type sys:Char}}">' + "<sys:Char>0</sys:Char>" * n + "</x:Array>"


L = []
a = L.append
a("""<!-- PACKAGE-BACKED PURE DECLARATIVE XAML, EF Core variant.
     Existing model types (owner-approved copy, internal->public and DB path only): Challenge1.DemoTimeCard / Challenge1.DemoTimeCardContext (assembly EfModel).
     Package: Microsoft.EntityFrameworkCore.Sqlite 10.0.14 (EF Core + Microsoft.Data.Sqlite), unmodified. No application code in this file's logic.
     Dynamic values reach typed entity properties as RAW typed nodes: carrier array -> new String(char[]) -> Double/Int32.Parse, declared AFTER the
     providers that fill the carriers (nodes are constructed in document order). Guard = SQL trigger text (owner: SQL in XAML counts as XAML). -->""")
a("""<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:sys="clr-namespace:System;assembly=System.Runtime" xmlns:glob="clr-namespace:System.Globalization;assembly=System.Runtime"
        xmlns:sql="clr-namespace:Microsoft.Data.Sqlite;assembly=Microsoft.Data.Sqlite"
        xmlns:m="clr-namespace:Challenge1;assembly=EfModel"
        Title="Only One STATEMENT (package-backed pure XAML, EF Core)" Width="520" Height="320" ResizeMode="NoResize" ShowActivated="False">
<Window.Resources>""")
a('<sys:Random x:Key="rnd"><x:Arguments><sys:Int32>42</sys:Int32></x:Arguments></sys:Random>')
a('<m:DemoTimeCardContext x:Key="ctx"/>')  # ctor: Database.EnsureCreated() -> table TimeCards
a('<sql:SqliteConnection x:Key="conn"><x:Arguments><sys:String>Data Source=artifacts/ef-run/demo-timecards.db</sys:String></x:Arguments></sql:SqliteConnection>')
a(odp("open", SR("conn"), "Open"))
trig = ("CREATE TRIGGER IF NOT EXISTS DemoGuard AFTER INSERT ON TimeCards "
        f"WHEN (SELECT COALESCE(SUM(Hours),0) FROM TimeCards WHERE Id &lt; NEW.Id) &gt; {THRESHOLD} "
        "BEGIN DELETE FROM TimeCards WHERE Id = NEW.Id; END")
a(f'<sql:SqliteCommand x:Key="guardCmd"><x:Arguments><sys:String>{trig}</sys:String>{R("conn")}</x:Arguments></sql:SqliteCommand>')
a(odp("doGuard", SR("guardCmd"), "ExecuteNonQuery"))
# year / week as raw typed ints
a("<sys:DateTime x:Key=\"unusedNow\" x:FactoryMethod=\"get_Now\"/>")
L.pop()
a(odp("yrFmt", "{x:Static sys:DateTime.Now}", "ToString", S("yyyy")))
a(chars("yrChars", 4))
a(odp("yrCopy", SR("yrFmt"), "CopyTo", I(0) + R("yrChars") + I(0) + I(4)))
a(odp("wkNum", "{x:Static glob:ISOWeek.GetWeekOfYear}", "x", ""))
L.pop()
a('<ObjectDataProvider x:Key="wkNum" ObjectType="{x:Type glob:ISOWeek}" MethodName="GetWeekOfYear"><ObjectDataProvider.MethodParameters><x:Static Member="sys:DateTime.Now"/></ObjectDataProvider.MethodParameters></ObjectDataProvider>')
a(odp("wkFmt", SR("wkNum"), "ToString", S("00")))
a(chars("wkChars", 2))
a(odp("wkCopy", SR("wkFmt"), "CopyTo", I(0) + R("wkChars") + I(0) + I(2)))
for i in range(N):
    a(odp(f"next{i}", SR("rnd"), "Next", I(10) + I(20)))
    a(odp(f"fmt{i}", SR(f"next{i}"), "ToString", S("0")))
    a(chars(f"chars{i}", 2))
    a(odp(f"copy{i}", SR(f"fmt{i}"), "CopyTo", I(0) + R(f"chars{i}") + I(0) + I(2)))
# raw typed values (declared after every carrier writer)
a(f'<sys:String x:Key="yrStr"><x:Arguments>{R("yrChars")}</x:Arguments></sys:String>')
a(f'<sys:Int32 x:Key="year" x:FactoryMethod="Parse"><x:Arguments>{R("yrStr")}</x:Arguments></sys:Int32>')
a(f'<sys:String x:Key="wkStr"><x:Arguments>{R("wkChars")}</x:Arguments></sys:String>')
a(f'<sys:Int32 x:Key="week" x:FactoryMethod="Parse"><x:Arguments>{R("wkStr")}</x:Arguments></sys:Int32>')
for i in range(N):
    a(f'<sys:String x:Key="hStr{i}"><x:Arguments>{R(f"chars{i}")}</x:Arguments></sys:String>')
    a(f'<sys:Double x:Key="hours{i}" x:FactoryMethod="Parse"><x:Arguments>{R(f"hStr{i}")}</x:Arguments></sys:Double>')
    a(f'<m:DemoTimeCard x:Key="card{i}" Category="{CATS[i]}" UserId="DemoUser" IsDemo="True"><m:DemoTimeCard.Hours>{R(f"hours{i}")}</m:DemoTimeCard.Hours><m:DemoTimeCard.Year>{R("year")}</m:DemoTimeCard.Year><m:DemoTimeCard.Week>{R("week")}</m:DemoTimeCard.Week></m:DemoTimeCard>')
a(odp("sets", SR("ctx"), "get_TimeCards"))
for i in range(N):
    a(odp(f"add{i}", SR("sets"), "Add", R(f"card{i}")))
a(odp("save", SR("ctx"), "SaveChanges"))
a('<sql:SqliteCommand x:Key="cnt"><x:Arguments><sys:String>SELECT COUNT(*) || \' cards, \' || SUM(Hours) || \' hours\' FROM TimeCards</sys:String>' + R("conn") + "</x:Arguments></sql:SqliteCommand>")
a(odp("obsSummary", SR("cnt"), "ExecuteScalar", extra='IsAsynchronous="True" '))
a("</Window.Resources>")
a("""<Viewbox><Grid x:Name="g" Background="#172033" Width="520" Height="320">
  <Grid.Triggers><EventTrigger RoutedEvent="FrameworkElement.Loaded"><BeginStoryboard><Storyboard>
    <DoubleAnimation Storyboard.TargetName="g" Storyboard.TargetProperty="Opacity" From="1" To="0.45" Duration="0:0:1.2" AutoReverse="True" RepeatBehavior="Forever"/>
  </Storyboard></BeginStoryboard></EventTrigger></Grid.Triggers>
  <StackPanel Margin="28">
    <TextBlock Foreground="#FFCE56" FontWeight="Bold" FontSize="18" Text="DEMO ONLY - no real time system is involved"/>
    <TextBlock Foreground="White" FontSize="22" Text="{Binding Source={StaticResource obsSummary}, StringFormat='Saved via EF Core: {0}'}"/>
  </StackPanel>
</Grid></Viewbox>
</Window>""")
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("ok", len(L))
