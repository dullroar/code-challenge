# One Statement, Two Semicolons

An intentionally close modernization of Jim Lehmer's C# 3.0/.NET 3.x code challenge.

The original was a class exercise with a ridiculous constraint: `Main` gets exactly one C# statement, an empty-body `for` loop. The initializer, condition, and iterator expressions do all the work. The result is emphatically not an architectural pattern. It is a small, deliberate flex in C# expression mechanics and the then-new .NET 3.x feature set.

This repository keeps the stunt visible while making it runnable on current Windows .NET. The matching original presentation is included as `docs/My Code Challenge.pdf`; it has been lightly anonymized.

## Run it

This is a Windows WPF application targeting .NET 10.

```powershell
cd src\ModernChallenge1
dotnet restore
dotnet run
```

The window intentionally says **DEMO ONLY**. Generated records are stored only in a local SQLite file under `%LOCALAPPDATA%\ModernChallenge1`; the application has no connection to an actual time-reporting system.

![Modern WPF demo window](docs/images/modern-wpf-demo.png)

## The fun, the why, the flex

The fun is treating the three expression slots of a `for` statement as a tiny programming language. The why is historical: the original sample was built to exercise the C# 3.0 and .NET 3.x features that were new in class. The flex is not that this is good production code; it is that the code can make a lot of runtime machinery legible while obeying an intentionally absurd syntactic rule.

The two arrow blocks in `Program.Main` are intentional. They point at the first and last semicolons that delimit the three `for` sections.

## What changed, and what did not

The project deliberately stays close to the original's shape. A modern idiomatic application would use declarative XAML, view models, dependency injection, short-lived EF Core contexts, and `await SaveChangesAsync()`. Those improvements are intentionally deferred here so each historical construct has a recognizable contemporary counterpart.

| Original construct | Current construct | Rationale |
|---|---|---|
| C# 3.0 / .NET 3.x project | SDK-style `net10.0-windows` WPF project | Current Windows WPF target |
| `[STAThread]` and `Program.Main` | Preserved | WPF still needs an STA UI entry point |
| One empty-body `for` statement | Preserved | The challenge constraint |
| Anonymous object as iterator state | Preserved | Still bundles mixed state into one initializer declaration |
| `XElement` emits a `DoubleAnimation` | Preserved | Still injected into runtime XAML |
| `List<float>` + LINQ `Sum()` | `List<double>` + LINQ `Sum()` | `double` is the usual current default for accumulated values |
| `Environment.GetEnvironmentVariable("USERNAME")` | `Environment.UserName` | Direct typed API for the same value |
| LINQ to SQL / `NorthwindDataContext` | EF Core / `DemoTimeCardContext` / SQLite | LINQ to SQL is not supported by current .NET; SQLite makes the demo self-contained |
| `InsertOnSubmit` / `SubmitChanges` | `TimeCards.Add` / `SaveChanges` | Closest current unit-of-work rhythm |
| Live `TimeCard` records | local, marked `DemoTimeCard` records | Avoids treating generated values as time reporting |
| `new Random()` | `Random.Shared` | Avoids needless short-lived generators |
| `DayOfYear / 7` | `ISOWeek.GetWeekOfYear` | Defined ISO calendar-week calculation |
| Generic `IEnumerator<string>` | Preserved | Keeps the generics example visible |
| Runtime WPF window + `XamlReader.Load` | Preserved | Keeps the source recognizably code-first |
| `Viewbox.Triggers` | `FrameworkElement.Triggers` | Current runtime XAML accepts the inherited property syntax |
| `Bliss.jpg` | color-only panel | Removes an undeclared external asset |
| Named `Mutex` | Preserved | Serializes the intentionally awkward shared-context path |
| Lambda / anonymous delegate | Preserved | Still makes the expression-based loop test possible |
| Background `Thread` | Preserved for comparison | Modern code would normally use `Task`/`await` |
| Reflection to invoke void-returning methods | Preserved for comparison | Retains the original expression-side-effect workaround |

## Caveats, intentionally left visible

`DbContext` is not thread-safe. The mutex is only here to retain the original thread/reflection shape. It should not be read as a recommendation for modern data-access design.

## Repository layout

```text
docs/
  My Code Challenge.pdf       # anonymized source presentation
  images/
    modern-wpf-demo.png       # captured WPF demo window
src/
  ModernChallenge1/           # .NET 10 WPF modernization
  RustChallenge1/             # Rust + GTK 4 companion for WSL
LICENSE
```

## Rust companion for WSL

[`src/RustChallenge1`](src/RustChallenge1/README.md) translates the challenge into Rust's iterator and closure mechanics: an empty-body `for` with no `;`, `let` or `return` anywhere in `main` (enforced by a test), a GTK 4 window, and local SQLite demo records. It also compares the approach with [Ken Kastl's Java and Kotlin + Spring ports](https://github.com/kastl/one-statement-spring). The companion README contains Ubuntu APT setup and run instructions.

From WSL, run the Rust version and inspect its saved demo records with:

```bash
cd /home/lehmer/repos/code-challenge/src/RustChallenge1
cargo run --locked
sqlite3 data/demo-timecards.db 'select * from demo_timecards;'
```

The SQLite command runs after the window is closed. See the companion README for the Ubuntu packages and setup.
