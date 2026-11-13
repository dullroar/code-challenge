# AUTHORING AID (not part of any grade's source): expands the per-draw provider pipeline into plain XAML.
N = 4
CATS = ["Meetings", "Coding", "Debugging", "Learning"]


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


ENC = "{x:Static txt:Encoding.ASCII}"
L = []
a = L.append
a("""<!-- PACKAGE-BACKED PURE DECLARATIVE XAML (v2).
     Non-built-in dependency: Microsoft.Data.Sqlite (+ SQLitePCLRaw) via Microsoft.EntityFrameworkCore.Sqlite 10.0.14, unmodified. No application code.
     Seeded Random(42) draws reach SQLite through MUTABLE CARRIER arrays:
       Next(10,20) -> ToString("0") -> string.CopyTo(char[]) -> ASCII.GetBytes(char[],..,byte[]) -> SqliteParameter(@h, byte[] BLOB) -> CAST(@h AS INTEGER).
     The termination guard (previous total <= 40) and the Demo* columns are SQL text in this XAML (owner: SQL in XAML counts as XAML).
     Sequencing = document order at parse time; the summary query runs on a pool thread (IsAsynchronous). -->""")
a("""<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:sys="clr-namespace:System;assembly=System.Runtime" xmlns:txt="clr-namespace:System.Text;assembly=System.Runtime"
        xmlns:sql="clr-namespace:Microsoft.Data.Sqlite;assembly=Microsoft.Data.Sqlite"
        Title="Only One STATEMENT (package-backed pure XAML)" Width="520" Height="320" ResizeMode="NoResize" ShowActivated="False">
<Window.Resources>""")
a('<sys:Random x:Key="rnd"><x:Arguments><sys:Int32>42</sys:Int32></x:Arguments></sys:Random>')
a('<sql:SqliteConnection x:Key="conn"><x:Arguments><sys:String>Data Source=artifacts/pkg-run/demo-timecards.db</sys:String></x:Arguments></sql:SqliteConnection>')
a(odp("open", SR("conn"), "Open"))
a('<sql:SqliteCommand x:Key="ddl"><x:Arguments><sys:String>CREATE TABLE IF NOT EXISTS DemoTimeCards(Id INTEGER PRIMARY KEY, Category TEXT NOT NULL, Hours REAL, UserId TEXT, Year INTEGER, Week INTEGER, IsDemo INTEGER NOT NULL)</sys:String>' + R("conn") + "</x:Arguments></sql:SqliteCommand>")
a(odp("doDdl", SR("ddl"), "ExecuteNonQuery"))
for i in range(N):
    a(odp(f"next{i}", SR("rnd"), "Next", I(10) + I(20)))
    a(odp(f"fmt{i}", SR(f"next{i}"), "ToString", S("0")))
    a(f'<x:Array x:Key="chars{i}" Type="{{x:Type sys:Char}}"><sys:Char>0</sys:Char><sys:Char>0</sys:Char></x:Array>')
    a(f'<x:Array x:Key="bytes{i}" Type="{{x:Type sys:Byte}}"><sys:Byte>0</sys:Byte><sys:Byte>0</sys:Byte></x:Array>')
    a(odp(f"copy{i}", SR(f"fmt{i}"), "CopyTo", I(0) + R(f"chars{i}") + I(0) + I(2)))
    a(odp(f"enc{i}", ENC, "GetBytes", R(f"chars{i}") + I(0) + I(2) + R(f"bytes{i}") + I(0)))
    a(f'<sql:SqliteParameter x:Key="p{i}"><x:Arguments><sys:String>@h</sys:String>{R(f"bytes{i}")}</x:Arguments></sql:SqliteParameter>')
    q = (f"INSERT INTO DemoTimeCards(Category,Hours,UserId,Year,Week,IsDemo) SELECT '{CATS[i]}', CAST(@h AS INTEGER), 'DemoUser', "
         "CAST(strftime('%Y','now') AS INTEGER), CAST(strftime('%W','now') AS INTEGER), 1 "
         "WHERE (SELECT COALESCE(SUM(Hours),0) FROM DemoTimeCards) &lt;= 40")
    a(f'<sql:SqliteCommand x:Key="ins{i}"><x:Arguments><sys:String>{q}</sys:String>{R("conn")}</x:Arguments></sql:SqliteCommand>')
    a(odp(f"params{i}", SR(f"ins{i}"), "get_Parameters"))
    a(odp(f"addp{i}", SR(f"params{i}"), "Add", R(f"p{i}")))
    a(odp(f"doIns{i}", SR(f"ins{i}"), "ExecuteNonQuery"))
a('<sql:SqliteCommand x:Key="cnt"><x:Arguments><sys:String>SELECT COUNT(*) || \' cards, \' || SUM(Hours) || \' hours\' FROM DemoTimeCards</sys:String>' + R("conn") + "</x:Arguments></sql:SqliteCommand>")
a(odp("obsSummary", SR("cnt"), "ExecuteScalar", extra='IsAsynchronous="True" '))
a("</Window.Resources>")
a("""<Viewbox><Grid x:Name="g" Background="#172033" Width="520" Height="320">
  <Grid.Triggers><EventTrigger RoutedEvent="FrameworkElement.Loaded"><BeginStoryboard><Storyboard>
    <DoubleAnimation Storyboard.TargetName="g" Storyboard.TargetProperty="Opacity" From="1" To="0.45" Duration="0:0:1.2" AutoReverse="True" RepeatBehavior="Forever"/>
  </Storyboard></BeginStoryboard></EventTrigger></Grid.Triggers>
  <StackPanel Margin="28">
    <TextBlock Foreground="#FFCE56" FontWeight="Bold" FontSize="18" Text="DEMO ONLY - no real time system is involved"/>
    <TextBlock Foreground="White" FontSize="22" Text="{Binding Source={StaticResource obsSummary}, StringFormat='Saved locally: {0}'}"/>
  </StackPanel>
</Grid></Viewbox>
</Window>""")
open("package-backed-pure/program.xaml", "w", encoding="utf-8").write("\n".join(L) + "\n")
print("ok", len(L))
