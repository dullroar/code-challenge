# AUTHORING AID (not part of any grade's source): expands the repetitive per-draw provider pipeline into plain XAML.
# The committed output (strict-built-in/program.xaml) is ordinary, readable XAML with no generator dependency.
N = 4
CATS = ["Meetings", "Coding", "Debugging", "Learning"]
tmpl1 = "<r>" + "".join(f"<c><id>{i+1}</id><h>00</h></c>" for i in range(N)) + "</r>"
rows2 = [f"<c><id>{i+1}</id><cat>{CATS[i]}</cat><user>DemoUser</user><h>00</h><b>00</b><demo>1</demo></c>" for i in range(N)]
tmpl2 = "<r>" + "".join(rows2) + "</r>"


def positions(t, tag, n):
    out = []
    s = 0
    for _ in range(n):
        k = t.index(f"<{tag}>00</{tag}>", s) + len(tag) + 2
        out.append(k)
        s = k + 1
    return out


h1 = positions(tmpl1, "h", N)
h2 = positions(tmpl2, "h", N)
b2 = positions(tmpl2, "b", N)


def bytes_xml(key, t):
    return f'<x:Array x:Key="{key}" Type="{{x:Type sys:Byte}}">' + "".join(f"<sys:Byte>{b}</sys:Byte>" for b in t.encode()) + "</x:Array>"


def chars(key):
    return f'<x:Array x:Key="{key}" Type="{{x:Type sys:Char}}"><sys:Char>0</sys:Char><sys:Char>0</sys:Char></x:Array>'


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


def col(tag, name, typ):
    a(f'<sd:DataColumn x:Key="{tag}" ColumnName="{name}" DataType="{{x:Type sys:{typ}}}"/>')


a("""<!-- STRICT BUILT-IN pure runtime XAML (v2). Only System.* / WPF types; no custom code.
     Dynamic data moves between calls through MUTABLE CARRIER arrays (char[]/byte[]) that providers overwrite in place:
       Random(42).Next -> ToString("0") -> string.CopyTo(char[]) -> ASCII.GetBytes(char[],..,byte[]) -> XML bytes
       -> MemoryStream -> DataTable.ReadXml -> DataTable.Compute("Sum(h)") -> CompareTo(40) -> DataTrigger / DataView filter -> WriteXml.
     Providers execute at parse time in document order (that order is the program). -->""")
a("""<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:sys="clr-namespace:System;assembly=System.Runtime" xmlns:txt="clr-namespace:System.Text;assembly=System.Runtime"
        xmlns:io="clr-namespace:System.IO;assembly=System.Runtime" xmlns:sd="clr-namespace:System.Data;assembly=System.Data.Common"
        xmlns:thr="clr-namespace:System.Threading;assembly=System.Threading.Thread" xmlns:col="clr-namespace:System.Collections;assembly=System.Runtime"
        Title="Only One STATEMENT (strict built-in pure XAML)" Width="520" Height="320" ResizeMode="NoResize" ShowActivated="False">
<Window.Resources>""")
a('<sys:Random x:Key="rnd"><x:Arguments><sys:Int32>42</sys:Int32></x:Arguments></sys:Random>')
a(bytes_xml("xml1", tmpl1))
a(bytes_xml("xml2", tmpl2))
for i in range(N):
    a(odp(f"next{i}", SR("rnd"), "Next", I(10) + I(20)))
    a(odp(f"fmt{i}", SR(f"next{i}"), "ToString", S("0")))
    a(chars(f"chars{i}"))
    a(odp(f"copy{i}", SR(f"fmt{i}"), "CopyTo", I(0) + R(f"chars{i}") + I(0) + I(2)))
    a(odp(f"enc1_{i}", ENC, "GetBytes", R(f"chars{i}") + I(0) + I(2) + R("xml1") + I(h1[i])))
    a(odp(f"enc2_{i}", ENC, "GetBytes", R(f"chars{i}") + I(0) + I(2) + R("xml2") + I(h2[i])))
a('<io:MemoryStream x:Key="ms1"><x:Arguments>' + R("xml1") + "</x:Arguments></io:MemoryStream>")
a('<sd:DataTable x:Key="tbl1" TableName="c"/>')
col("c1id", "id", "Int32")
col("c1h", "h", "Int32")
a(odp("cols1", SR("tbl1"), "get_Columns"))
a(odp("add1a", SR("cols1"), "Add", R("c1id")))
a(odp("add1b", SR("cols1"), "Add", R("c1h")))
a(odp("read1", SR("tbl1"), "ReadXml", R("ms1")))
a(odp("obsTotal", SR("tbl1"), "Compute", S("Sum(h)") + S("")))
for k in range(1, N):
    a(odp(f"pre{k}", SR("tbl1"), "Compute", S("Sum(h)") + S(f"id&lt;{k+1}")))
    a(odp(f"pfmt{k}", SR(f"pre{k}"), "ToString", S("0")))
    a(chars(f"pchars{k}"))
    a(odp(f"pcopy{k}", SR(f"pfmt{k}"), "CopyTo", I(0) + R(f"pchars{k}") + I(0) + I(2)))
    a(odp(f"penc{k}", ENC, "GetBytes", R(f"pchars{k}") + I(0) + I(2) + R("xml2") + I(b2[k])))
a('<io:MemoryStream x:Key="ms2"><x:Arguments>' + R("xml2") + "</x:Arguments></io:MemoryStream>")
a('<sd:DataTable x:Key="tbl2" TableName="c"/>')
for t, ty in [("id", "Int32"), ("cat", "String"), ("user", "String"), ("h", "Int32"), ("b", "Int32"), ("demo", "Int32")]:
    col("c2" + t, t, ty)
a(odp("cols2", SR("tbl2"), "get_Columns"))
for t in ["id", "cat", "user", "h", "b", "demo"]:
    a(odp("add2" + t, SR("cols2"), "Add", R("c2" + t)))
a(odp("read2", SR("tbl2"), "ReadXml", R("ms2")))
a('<sd:DataView x:Key="view" RowFilter="b &lt;= 40"><x:Arguments>' + R("tbl2") + "</x:Arguments></sd:DataView>")
a(odp("filtered", SR("view"), "ToTable"))
a(odp("obsKept", SR("filtered"), "get_Rows"))
a(odp("write", SR("filtered"), "WriteXml", S("artifacts/strict-run/demo-timecards.xml"), extra='IsAsynchronous="True" '))
a(odp("obsVs40", SR("obsTotal"), "CompareTo", I(40)))
a('<col:ArrayList x:Key="target"><sys:String>pending</sys:String></col:ArrayList>')
a('<sys:Delegate x:Key="ts" x:FactoryMethod="CreateDelegate"><x:Arguments><x:Type TypeName="thr:ThreadStart"/>' + R("target") + "<sys:String>Clear</sys:String></x:Arguments></sys:Delegate>")
a('<thr:Thread x:Key="bg" IsBackground="True"><x:Arguments>' + R("ts") + "</x:Arguments></thr:Thread>")
a(odp("obsBgId", SR("bg"), "get_ManagedThreadId"))
a(odp("bgStart", SR("bg"), "Start"))
a(odp("bgJoin", SR("bg"), "Join"))
a(odp("obsPending", SR("target"), "get_Count"))
a("</Window.Resources>")
a("""<Viewbox><Grid x:Name="g" Background="#172033" Width="520" Height="320">
  <Grid.Triggers><EventTrigger RoutedEvent="FrameworkElement.Loaded"><BeginStoryboard><Storyboard>
    <DoubleAnimation Storyboard.TargetName="g" Storyboard.TargetProperty="Opacity" From="1" To="0.45" Duration="0:0:1.2" AutoReverse="True" RepeatBehavior="Forever"/>
  </Storyboard></BeginStoryboard></EventTrigger></Grid.Triggers>
  <StackPanel Margin="28">
    <TextBlock Foreground="#FFCE56" FontWeight="Bold" FontSize="18" Text="DEMO ONLY - no real time system is involved"/>
    <TextBlock Foreground="White" FontSize="22" Text="{Binding Source={StaticResource obsTotal}, StringFormat='Total simulated hours: {0}'}"/>
    <TextBlock Foreground="White" FontSize="22">
      <TextBlock.Style><Style TargetType="TextBlock"><Setter Property="Text" Value="working..."/><Style.Triggers>
        <DataTrigger Binding="{Binding Source={StaticResource obsVs40}}"><DataTrigger.Value><sys:Int32>1</sys:Int32></DataTrigger.Value><Setter Property="Text" Value="over 40 h: batch complete"/></DataTrigger>
        <DataTrigger Binding="{Binding Source={StaticResource obsVs40}}"><DataTrigger.Value><sys:Int32>-1</sys:Int32></DataTrigger.Value><Setter Property="Text" Value="under 40 h: would continue"/></DataTrigger>
      </Style.Triggers></Style></TextBlock.Style></TextBlock>
    <TextBlock Foreground="White" FontSize="22" Text="Saved locally (XML) for the modernization exercise."/>
  </StackPanel>
</Grid></Viewbox>
</Window>""")
open("strict-built-in/program.xaml", "w", encoding="utf-8").write("\n".join(L) + "\n")
print("ok", len(L))
