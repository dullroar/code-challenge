# C#, LINQ and XAML (plus the one-statement ports)

Entries: [`ModernChallenge1`](../../src/ModernChallenge1/README.md), [`LinqChallenge1`](../../src/LinqChallenge1/README.md), [`LinqChallenge2`](../../src/LinqChallenge2/README.md), [`xaml`](../../src/xaml/README.md), and the ports [Java](../../src/JavaChallenge1/README.md), [Kotlin](../../src/KotlinChallenge1/README.md), [Python](../../src/PythonChallenge1/README.md), [Go](../../src/GoChallenge1/README.md), [Rust](../../src/RustChallenge1/README.md).

C# is the *canonical* language of the repo: the challenge began as a 2008 classroom exercise showing off C# 3.0 and .NET 3.x features. It is also where the [blocking problems](../blocking-problems.md) are measured from.

## The original: ModernChallenge1

### 1. Behold the monstrosity

```powershell
cd src\ModernChallenge1
dotnet run          # Windows + .NET 10; or: sandbox\windows\run.ps1 src\ModernChallenge1
```

A WPF window fades in and out. `Main` holds exactly one `for` whose body is empty ([`Program.cs` L132](../../src/ModernChallenge1/Program.cs#L132): `{ /* Intentionally empty. */ }`).

### 2. How the hell does that work?

Read the `for` header as a tiny language of three slots.

| Clause | Where | What lives there |
| --- | --- | --- |
| **Initializer** | [L37-58](../../src/ModernChallenge1/Program.cs#L37-L58) | One `var i = new { ... }` anonymous object holding all state: EF Core context, `Random`, category enumerator, WPF `Application`, a `Mutex`, an `XElement` that becomes a `DoubleAnimation`. A `for` initializer allows one declaration, so the anonymous object is the one legal container. |
| **Condition** | [L66-98](../../src/ModernChallenge1/Program.cs#L66-L98) | `(from hours in i.totalHours select hours).Sum() <= 40d && i.categories!.MoveNext() ? true : new Func<bool>(() => Double.IsNaN(i.app.Run(...))).Invoke()`. While the total is 40 or less the loop continues. Once it is not, the condition builds and shows the window inline and returns false. |
| **Iterator** | [L106-130](../../src/ModernChallenge1/Program.cs#L106-L130) | Draws hours, adds a row to EF Core, and starts a background `Thread` that calls `Mutex.WaitOne`, `SaveChanges` and `ReleaseMutex` *through `MethodInfo.Invoke`*. |

The window is built from a string of raw XAML via `XamlReader.Load` at run time ([L77](../../src/ModernChallenge1/Program.cs#L77)).

### 3. What did we just learn?

- `for` is three expressions plus a body, and the body is optional.
- An **anonymous type** is a way to pack mixed state into one expression.
- A `void` side effect can be turned into a value with a `Func<T>` invoked in place. That is the move every later entry reuses.

### 4. Do this in production and you're fired

- **`DbContext` is not thread-safe.** The `Mutex` exists only to keep the thread-plus-reflection shape working at all ([README](../../src/ModernChallenge1/README.md#one-caveat-left-visible-on-purpose)); it is a historical artifact.
- **Reflection and a thread add nothing.** They are a deliberate 2008-style time capsule; modern code would `await SaveChangesAsync()`.
- **WPF needs `[STAThread]`** and a single UI thread ([L30](../../src/ModernChallenge1/Program.cs#L30)).
- **Readability, testing, debugging**: nothing in that `for` header can be stepped through, unit-tested or reused.

Legitimate uses: none for the header as written. The *ideas* (state in an object, pure queries over a list, effects at the edge) are ordinary.

## Deferred execution and the void-to-value trick

### LinqChallenge1: one fluent chain

One `;`-terminated expression statement, built from LINQ calls, starting at [`Program.cs` L45](../../src/LinqChallenge1/Program.cs#L45) and ending in `.Aggregate(...)` that forces the lazy tail. Stages:

| Stage | Operator | Lesson |
| --- | --- | --- |
| 1 | `Aggregate` over a fixed work week, `ctx.Add(...)` inside `new Func<...>(() => {...}).Invoke()` | `Aggregate` is **eager**; it runs first. |
| tuple | `(..., ctx.SaveChanges())` ([L66-68](../../src/LinqChallenge1/Program.cs#L66-L68)) | Tuple elements evaluate **left to right**, which sequences the save after every entity is tracked. |
| 2 | `Enumerable.Repeat(x, 1).SelectMany(...)` and `.AsEnumerable()` ([L72-78](../../src/LinqChallenge1/Program.cs#L72-L78)) | The `IQueryable<T>` to `IEnumerable<T>` boundary: EF translates `Where/OrderBy/Select` to SQL, and `AsEnumerable()` is where it stops. |
| 3-5 | `Aggregate`, `Select` builds the WPF window, `Select` pulses and calls `Application.Run()` | Lazy `Select` stages do nothing until enumerated. |
| final | `.Aggregate(0, (count, _) => count + 1)` | An eager operator at the end drags the whole lazy pipeline through. |

Why two nested `Enumerable.Repeat(..., 1)`? C# allows only a few expression shapes as a statement (invocation, assignment, `await`...), not `x is var r && ...`. So each stage is nested directly as the argument to the next `Repeat`, which turns a single value back into a one-element sequence so the next step can stay a LINQ operator.

### LinqChallenge2: query syntax all the way down

[`LinqChallenge2/Program.cs` L53](../../src/LinqChallenge2/Program.cs#L53) onward is the same demo as nearly all `from`/`where`/`let`/`select`. Where a `let` has to smuggle in a `void` call ([L71-72](../../src/LinqChallenge2/Program.cs#L71-L72)), it is wrapped in a throwaway one-row query: `from _track in Enumerable.Repeat(0, 1) ...`. Turtles all the way down, on purpose. Things that cannot be query syntax (`Aggregate`, `Repeat`, `ToList`, `Sum`, `Single`, `AsEnumerable`) are listed in the [README](../../src/LinqChallenge2/README.md).

### What did we just learn?

- **LINQ is an execution pipeline, not just a query language.** Which stages are eager, which are lazy, and which provider (SQL vs. objects) runs each one decide *when your side effects happen*. See the same question in [Haskell](haskell.md#lazy-io-as-control-flow).
- **Provider boundaries are real.** Everything before `AsEnumerable()` becomes SQL; everything after is C# running in your process.
- **Side effects in a lazy pipeline are a bug magnet**, and the entries make that visible.

Tags: deferred vs. immediate execution of each operator is **guaranteed** (documented). Tuple left-to-right evaluation is **guaranteed** by the C# spec. EF translating a given expression is **provider-dependent**.

### Do this in production and you're fired

- **Hidden mutation.** Both `Aggregate` accumulators are mutated in place (`list.Add`) - a pragmatic shortcut, not LINQ purity.
- **Re-enumeration runs the effects again.** A query with a side effect in a `Select` that is enumerated twice does the side effect twice.
- **UI thread affinity.** Building and pumping a WPF window from inside a `Select` lambda only works because of the STA thread and `Application.Run()`; `ShutdownMode` is `OnExplicitShutdown` so the animation's `Completed` handler, not "last window closed", ends the app.
- **Fixed data.** Both LINQ entries generate a *fixed* five 8-hour-day work week, not random 10-19 hour cards. See [blocking problems](../blocking-problems.md#c-and-linq).

### Break it yourself

See [exercises](../exercises.md#linq-enumerate-twice).

## XAML

[`xaml/Loader.cs` L10-15](../../src/xaml/Loader.cs#L10-L15) is a single expression: `new Application().Run((Window)XamlReader.Load(File.OpenRead(args[0])))`. Everything else is in the `.xaml` file, and it runs **while the file is parsed**.

### How is that even possible?

| Mechanism | Role |
| --- | --- |
| `XamlReader.Load` | the interpreter: parsing *is* running |
| `ObjectDataProvider` | the instruction: constructs any object, calls any method, fires when parsed. Document order is the program counter. |
| "Carrier" arrays | the variables: one provider fills a `char[]` or `byte[]` in place, the next reads it back ([`efcore.xaml` L15-30](../../src/xaml/efcore.xaml#L15-L30) shows the chain `Next` -> `ToString` -> `CopyTo`) |
| Expression engines (`DataTable.Compute("Sum(h)")`, `DataView.RowFilter`, SQL) | the ALU and the conditionals |
| `Delegate.CreateDelegate` in markup | a `Thread`, built, started and joined from XAML |

### Honest fine print

- **The loop is unrolled**: four copy-pasted passes. "Four categories" is baked into the markup.
- **The branching is done by SQL or `DataTable`**, not by WPF triggers.
- **`Random(42)` is fixed-seeded** in the `.xaml` files, so the hours are the same on every run.
- **`XamlChallenge1.csproj` has `<Page Remove="**/*.xaml" />`**, so the files are loaded at run time, never compiled. That *is* the point.
- **Three flavors**: `strict.xaml` (only .NET types, saves XML), `sqlite.xaml`, `efcore.xaml`. The stop rule is a SQL `WHERE` clause or a SQLite trigger.

### What did we just learn?

XAML is supposed to *describe* a tree of objects. The parser does not enforce that: given `ObjectDataProvider` and a few built-in types, parsing and executing become the same act. A 2013 Web Forms [blog post](../../docs/stacked-bar-charts.md) pushed the same idea (a chart with no code-behind), so the lineage is real.

**Tags**: `ObjectDataProvider` calling methods on construction is **documented WPF behavior**; relying on document-order evaluation and in-place carrier arrays is **accidentally exploited**.

**Fired in production**: arbitrary method invocation from a markup file is a code-execution surface. Loading untrusted XAML with `XamlReader.Load` is a well-known risk. Any tooling (designers, linters) assumes the file is data.

## The one-statement ports: same trick, different machinery

Ken's ports keep the bodiless-loop rule and swap in each language's own parts. A good exercise is to find each language's three clauses.

| Port | Header mechanism | Quirk worth stealing |
| --- | --- | --- |
| [Java](../../src/JavaChallenge1/README.md) | `for` header; anonymous class holds state; Swing window assembled from Spring XML with SpEL | A text block of XML as the UI; the README has a side-by-side of all four ports |
| [Kotlin](../../src/KotlinChallenge1/README.md) | `for (pass in generateSequence(...) {...})`; a null from `takeIf` ends the sequence | The body runs once before the first check, a documented difference |
| [Python](../../src/PythonChallenge1/README.md) | `for _ in iter(<lambda>, False): ...` | No `;` loops, so a tuple plus `[-1]` stands in for the comma operator; Tk widgets built from an XML string with `getattr(tk, e.tag)` |
| [Go](../../src/GoChallenge1/README.md) | a real three-clause `for`; helpers like `Seq` and `After` in `helpers.go` | Statement-only operations had to be hidden in a helper file, the stated cost of the Go version |
| [Rust](../../src/RustChallenge1/README.md) | `for _ in std::iter::successors(...) {}` ([`main.rs` L19](../../src/RustChallenge1/src/main.rs#L19)) | No `;`, `let` or `return` in `main`; `match x { name => ... }` stands in for `let`; a test scans the source to enforce it |

## Under what circumstances would this terrible idea become reasonable?

Putting everything in a `for` header: never. But knowing that LINQ is lazy, that `IQueryable` and `IEnumerable` are different worlds, that `DbContext` is not thread-safe, and that XAML's parser can call methods are all things you want to learn *before* the production bug that teaches them.
