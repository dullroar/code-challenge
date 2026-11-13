# generator for probe H2 (build-time convenience only; output is plain XAML committed alongside)
import base64
N=4
tmpl="<r>"+"".join(f"<c><id>{i+1}</id><h>00</h></c>" for i in range(N))+"</r>"
offs=[tmpl.index("<h>00</h>",0 if i==0 else 0) for i in range(1)]
pos=[];start=0
for i in range(N):
    k=tmpl.index("<h>00</h>",start)+3; pos.append(k); start=k+1
b64=base64.b64encode(tmpl.encode()).decode()
x=f'''<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:sys="clr-namespace:System;assembly=System.Runtime" xmlns:txt="clr-namespace:System.Text;assembly=System.Runtime"
        xmlns:io="clr-namespace:System.IO;assembly=System.Runtime" xmlns:sd="clr-namespace:System.Data;assembly=System.Data.Common"
        Width="10" Height="10" ShowActivated="False"><Window.Resources>
  <sys:Random x:Key="rnd"><x:Arguments><sys:Int32>42</sys:Int32></x:Arguments></sys:Random>
  <!-- XML document carrier: template bytes (base64 via Convert.FromBase64String factory), digits overwritten at run time -->
  <sys:Array x:Key="xml" x:FactoryMethod="FromBase64String"/>
'''
# x:FactoryMethod needs a declaring type: use Convert
x=x.replace('<sys:Array x:Key="xml" x:FactoryMethod="FromBase64String"/>',f'<sys:Convert x:Key="unused"/>')
x=x.replace('<sys:Convert x:Key="unused"/>','')
x+=f'''  <x:Array x:Key="xml" Type="{{x:Type sys:Byte}}">{"".join(f"<sys:Byte>{b}</sys:Byte>" for b in tmpl.encode())}</x:Array>
'''
for i in range(N):
    x+=f'''  <ObjectDataProvider x:Key="next{i}" ObjectInstance="{{StaticResource rnd}}" MethodName="Next"><ObjectDataProvider.MethodParameters><sys:Int32>10</sys:Int32><sys:Int32>20</sys:Int32></ObjectDataProvider.MethodParameters></ObjectDataProvider>
  <ObjectDataProvider x:Key="fmt{i}" ObjectInstance="{{StaticResource next{i}}}" MethodName="ToString"><ObjectDataProvider.MethodParameters><sys:String>0</sys:String></ObjectDataProvider.MethodParameters></ObjectDataProvider>
  <x:Array x:Key="chars{i}" Type="{{x:Type sys:Char}}"><sys:Char>x</sys:Char><sys:Char>x</sys:Char></x:Array>
  <ObjectDataProvider x:Key="copy{i}" ObjectInstance="{{StaticResource fmt{i}}}" MethodName="CopyTo"><ObjectDataProvider.MethodParameters><sys:Int32>0</sys:Int32><StaticResource ResourceKey="chars{i}"/><sys:Int32>0</sys:Int32><sys:Int32>2</sys:Int32></ObjectDataProvider.MethodParameters></ObjectDataProvider>
  <ObjectDataProvider x:Key="enc{i}" ObjectInstance="{{x:Static txt:Encoding.ASCII}}" MethodName="GetBytes"><ObjectDataProvider.MethodParameters><StaticResource ResourceKey="chars{i}"/><sys:Int32>0</sys:Int32><sys:Int32>2</sys:Int32><StaticResource ResourceKey="xml"/><sys:Int32>{pos[i]}</sys:Int32></ObjectDataProvider.MethodParameters></ObjectDataProvider>
'''
x+='''  <io:MemoryStream x:Key="ms"><x:Arguments><StaticResource ResourceKey="xml"/></x:Arguments></io:MemoryStream>
  <sd:DataTable x:Key="tbl" TableName="c"/>
  <sd:DataColumn x:Key="cid" ColumnName="id" DataType="{x:Type sys:Int32}"/>
  <sd:DataColumn x:Key="ch" ColumnName="h" DataType="{x:Type sys:Int32}"/>
  <ObjectDataProvider x:Key="cols" ObjectInstance="{StaticResource tbl}" MethodName="get_Columns"/>
  <ObjectDataProvider x:Key="addId" ObjectInstance="{StaticResource cols}" MethodName="Add"><ObjectDataProvider.MethodParameters><StaticResource ResourceKey="cid"/></ObjectDataProvider.MethodParameters></ObjectDataProvider>
  <ObjectDataProvider x:Key="addH" ObjectInstance="{StaticResource cols}" MethodName="Add"><ObjectDataProvider.MethodParameters><StaticResource ResourceKey="ch"/></ObjectDataProvider.MethodParameters></ObjectDataProvider>
  <ObjectDataProvider x:Key="read" ObjectInstance="{StaticResource tbl}" MethodName="ReadXml"><ObjectDataProvider.MethodParameters><StaticResource ResourceKey="ms"/></ObjectDataProvider.MethodParameters></ObjectDataProvider>
  <ObjectDataProvider x:Key="obsSum" ObjectInstance="{StaticResource tbl}" MethodName="Compute"><ObjectDataProvider.MethodParameters><sys:String>Sum(h)</sys:String><sys:String></sys:String></ObjectDataProvider.MethodParameters></ObjectDataProvider>
  <ObjectDataProvider x:Key="obsRows" ObjectInstance="{StaticResource tbl}" MethodName="get_Rows"/>
</Window.Resources></Window>
'''
open('probes/H2-carrier-datatable-sum.xaml','w').write(x)
print(tmpl,pos)
