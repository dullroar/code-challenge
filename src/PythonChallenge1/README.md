# One Statement, Python Edition

Ken's Python port of Jim Lehmer's C# challenge. It is one of four sibling ports, along with [Java](../JavaChallenge1/README.md), [Kotlin](../KotlinChallenge1/README.md) and [Go](../GoChallenge1/README.md). The Java README has [what every version does](../JavaChallenge1/README.md#what-every-version-does) and the [side-by-side comparison](../JavaChallenge1/README.md#side-by-side) of all four.

The constraint: `main` contains exactly one statement, a `for` loop with an empty body. This is a stunt in expression mechanics, not good production code. Nothing here connects to a real time-reporting system: the cards are flagged `is_demo`.

## Run

You need Python 3 only: `tkinter` and `sqlite3` are built in.

```powershell
py src\PythonChallenge1\program.py
```

Or, from the repo root, through Gradle: `.\gradlew.bat runPython`.

The window is a Tk window. Records land in `src/PythonChallenge1/data/demo-timecards.db`, beside `program.py`, whatever the working directory. Delete `data` to start over.

## Layout

[program.py](program.py) is the whole port. The entity and repository classes sit in the same file, above `main`.

## How the one statement is built

The work splits three ways: an **initializer** that builds the loop's state, a **condition** that decides whether to keep going (and, on the last check, shows the window), and an **update** that does one pass of work. Comment banners in the source mark the boundaries.

Python has no three-part `for`, no comma expressions and no statements inside expressions, so the loop is `for _ in iter(step, False): ...`. Calling `step` again and again is the loop. It stops when `step` returns the sentinel `False`.

- **Initializer.** A `SimpleNamespace` holds the state. It is passed to a lambda that builds `step`.
- **Condition.** One conditional expression: `(update ...) if total <= 40 and categories else (show the window ...)`.
- **Update.** A tuple of calls whose last element is `True`; `[-1]` picks it. Tuples evaluate left to right, which stands in for the comma list. It locks, adds hours, stages a card, unlocks, and starts a `threading.Thread`.
- **Empty body.** `...` is a bare constant expression. A `pass` would be a second statement.
- **Window.** A Tk window described by an XML string parsed at runtime with `xml.etree.ElementTree`, one widget per element via `getattr(tkinter, tag)`. `after()` repeats a timer that blends each label's color toward the background (Tk labels have no alpha). `mainloop()` blocks until the window closes.
- **Saving.** Standard-library `sqlite3`. `getattr(repo, "save_all")` is the reflection stand-in.
- **Caveat.** `main` is exactly one `for` statement, but the lambdas and comprehensions inside it are expressions only. Imports, the entity and the repository sit outside `main`.
