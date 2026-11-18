---
name: "XAML"
teaches: "how far a markup parser can be pushed before it stops describing a UI and starts *running* a program."
kind: weird
languages: [xaml, c-sharp]
lesson: "languages/csharp-linq-xaml.md#xaml"
loop-by: document-order
evaluation: declarative
assurance: accidentally-exploited
pairs-with: ModernChallenge1
machine: "An object-graph constructor that runs methods as it parses"
state: "Document order, plus \"carrier\" arrays"
tags: [arbitrary-code-execution, computation-versus-orchestration, declarative-programming, interpreter-and-virtual-machine, langsec, markup-language, parsing, reflection-and-metaprogramming, serialization-deserialization-pickling, side-effect, state, threat-model, weird-machine]
counterexamples: [event-driven-programming]
---
# XAML challenge: the program isn't even C# code

**Teaches you:** how far a markup parser can be pushed before it stops describing a UI and starts *running* a program.

XAML is supposed to describe a user interface: a tree of objects, declared, not executed. This entry treats that promise as a dare. The C# in this folder is a single expression that hands a `.xaml` file to the XAML parser:

```csharp
new Application().Run((Window)XamlReader.Load(File.OpenRead(args[0])));
```

Every piece of behavior - the random draws, the arithmetic, the stop rule, the database writes, a background thread, the fade animation - lives inside the `.xaml` file, and all of it runs **while the file is being parsed**. There is no code-behind and no event handler anywhere in this folder.

## Run it

You need Windows and the .NET 10 SDK.

```powershell
cd src\xaml
dotnet run -- strict.xaml     # only types that ship with .NET and WPF; saves an XML file
dotnet run -- sqlite.xaml     # talks to SQLite directly from XAML
dotnet run -- efcore.xaml     # EF Core: TimeCards.Add and SaveChanges, from XAML
```

Records land in `src\xaml\data`; delete that folder to start fresh (the stop rule counts rows already saved). The window says **DEMO ONLY**: nothing here touches a real time-reporting system.

![XAML demo window](../../docs/images/xaml-demo.png)

## Program Flow

```mermaid
sequenceDiagram
    accTitle: xaml: parsing the file is running the program
    accDescr: A sequence diagram of efcore.xaml. Loader.Main creates the data folder and calls XamlReader.Load. The XAML parser builds the nodes in document order, and each ObjectDataProvider fires as soon as it is built. Four unrolled passes each draw a random number into a carrier array, build a card from it, and insert it with EF Core. A SQL trigger deletes a row if the earlier rows already total more than 40. The parser returns the finished window. Application.Run then shows the window, a Loaded event trigger starts the fade storyboard, and the run ends when the window closes.
    participant L as Loader.Main
    participant P as XAML parser
    participant O as ObjectDataProvider nodes
    participant D as SQLite and its trigger
    participant W as Window and dispatcher
    L->>P: XamlReader.Load(file)
    loop four copies, in document order
        P->>O: build the next provider node: it fires at once
        O->>D: random hours, via a carrier array, then Add and SaveChanges
        D-->>D: trigger deletes the row if earlier rows total over 40
    end
    P-->>L: the finished Window object
    L->>W: Application.Run(window)
    W-->>W: Loaded event trigger starts the fade storyboard
    W-->>L: the window closes and Run returns
```

**What this shows:** there is no loop and no stop rule in the markup's control flow. The parser walks the document once, from top to bottom, and each provider does its work at the moment it is built. The four passes are four copies, and the 40-hour limit is a trigger inside SQLite, which removes a row that comes too late.

**Why this mechanism matters:** the program counter is document order. The only event in the picture is the `Loaded` trigger, and it only starts an animation. The program's logic does not subscribe to anything. This is a parser used as an interpreter, not event-driven code. Shown here is `efcore.xaml`; `strict.xaml` and `sqlite.xaml` share the shape.

## How the stunt works

A markup language has no `for`, no `if`, and no assignment - in theory. In practice, WPF's XAML parser ships with a few features that, combined, add up to a small interpreter:

- **`XamlReader.Load` is the interpreter.** The `.xaml` file is the program; parsing it *is* running it.
- **`ObjectDataProvider` is the instruction.** It can construct any object and call any method, and it fires the moment it is parsed. Document order becomes the program counter.
- **`Refresh` is the goto.** One provider can re-run another one. The call is passed through an `x:Array` so that XAML does not try to unwrap it first.
- **"Carrier" arrays are the variables.** One `ObjectDataProvider` call fills a `char[]` or `byte[]` in place; the next one reads it back. That is how a random number travels from `Random.Next` into a SQL parameter, an XML element, or an EF Core entity.
- **Expression engines are the ALU.** `DataTable.Compute("Sum(h)")`, `DataView.RowFilter`, and SQL itself do the arithmetic and the conditionals. A SQL string inside a XAML attribute is still XAML.
- **A `Thread` is built entirely in markup**, using `Delegate.CreateDelegate`, then started and joined - all as `ObjectDataProvider` calls. The window's fade is an ordinary WPF `Storyboard`.

## Gotchas worth knowing

Obfuscation is not the same as lying, so here is what the trick actually costs:

- **The loop is unrolled, not looped.** There is no loop construct anywhere in these files - only four copy-pasted passes. "Four categories" is baked into the markup, not computed.
- **Conditional *effects* come from the expression engines**, not from WPF's `Trigger`/`DataTrigger` system. `DataTable.Compute` and SQL branch on data; XAML triggers are not used for program logic here.
- **Three files, three flavors of the same program.** `strict.xaml` uses nothing outside .NET itself, so it saves XML rather than a database. `sqlite.xaml` adds the SQLite package. `efcore.xaml` adds EF Core, through two small model classes copied from the [C# original](../ModernChallenge1/README.md).

## Why this is weird

XAML's job is to *describe* a UI tree, declaratively, so a designer tool can read and write it without running any code. This entry shows what happens once you notice the parser does not actually enforce that: given the right combination of built-in types, parsing a file and running a program become the same act. It is not a technique to reuse - it is what happens when you take "XAML is just data" at its word and then push until it stops being true.

The idea is older than this repo. A [2013 blog post](../../docs/stacked-bar-charts.md) did the same thing on ASP.NET Web Forms: it built a stacked bar chart with no code-behind, just a SQL `PIVOT` and markup. That post is where the XAML entry came from. Microsoft never gives up on an idea.

---

See the [root README](../../README.md) for how this compares to the other entries, and [`CHALLENGE.md`](../../CHALLENGE.md) if you want to write your own.

## Run it in Windows Sandbox

Prerequisites: Windows Sandbox and this entry's toolchain on your machine, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#windows-sandbox).

```powershell
sandbox\windows\run.ps1 src\xaml -RunArgs strict.xaml
```

It runs the entry in a throwaway VM with networking off, screenshots the window, asks it to close, and prints what it saved.
