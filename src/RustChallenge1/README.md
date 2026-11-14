# One Statement, Rust Edition

A WSL/GTK 4 companion to Jim Lehmer's C# challenge and [Ken's Java, Kotlin, Python and Go versions](https://github.com/kastl/one-statement-challenge). The point is to explore expression mechanics through a deliberately ridiculous constraint, not to offer a production architecture.

## Install and run on Ubuntu under WSL 2

A working WSLg desktop session is required. In Ubuntu 24.04, install the APT toolchain and native libraries:

```bash
sudo apt-get update
sudo apt-get install -y build-essential pkg-config cargo rustc rustfmt \
    libgtk-4-dev libsqlite3-dev sqlite3
cd src/RustChallenge1
cargo run --locked
```

The locked dependencies are tested with Ubuntu's Rust and Cargo 1.75. Cargo needs network access to download crates on the first build. See Microsoft's [WSLg setup](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps) if the window cannot open.

The window displays the generated total over a gently shifting shade; closing it ends the program. Each run appends fictional records to `$XDG_DATA_HOME/RustChallenge1/demo-timecards.db` (by default `~/.local/share/RustChallenge1/demo-timecards.db`), the Linux counterpart of the C# version's `%LOCALAPPDATA%\ModernChallenge1`. Delete that directory to start over. The database is **DEMO ONLY**, with no connection to a real time-reporting system.

## How the stunt works

`main` is one empty-body `for` loop, and nothing inside it is a statement: no `;`, no `let`, no `return`. `tests/one_statement.rs` scans `src/main.rs` and fails if that stops being true. Helper types in `lib.rs` handle data generation and persistence, as the C# version's `DemoTimeCardContext` does.

Rust has no `;`-separated three-clause `for`, but `std::iter::successors(first, next)` has the same three jobs:

| `for` section | In the Rust version |
| --- | --- |
| Initializer | `first`: an immutable `DemoBatch` |
| Condition | `next` returns `None` to end the loop; as in the C#, the window is launched from inside it |
| Iterator | `next` returns `Some(batch.extended(hours))`, the batch plus one more card |

Two tricks stand in for the statements Rust would normally use:

- `match value { name => ... }` is a `let` that is an expression.
- `(a, b, c).2` is the comma operator: it evaluates `a`, `b`, `c` in order and yields the last.

The loop checks the running total before each record: while it is at most 40 and categories remain, it adds 10-19 hours for the next category. When the batch is finished, a scoped worker thread (which borrows the cards, with no clone) saves it in one SQLite transaction and is joined before the window claims anything was saved. Errors terminate with a message rather than reporting success, except inside the GTK draw callback, where Cairo errors are ignored because a panic there would abort across the C boundary. The calendar year and ISO week match the original's separate fields; around New Year the ISO week-based year can differ from the calendar year.

| Original and Ken's ports | Rust companion |
| --- | --- |
| C# and Java use the three sections of a `for` with an empty body; Kotlin builds a sequence | Rust builds an iterator with `successors`, also with an empty body |
| Anonymous state objects and Kotlin `also` chains | An immutable `DemoBatch`; `match x { name => ... }` binds names |
| Comma-separated iterator expressions | Tuples, projected with `.N` |
| Runtime XAML or Spring XML builds the window | Runtime GTK Builder XML builds the window; a GLib timer moves a soft background shade |
| EF Core or Spring Data and SQLite | `rusqlite` and a local transaction |
| Background save and reflective method calls | A joined scoped thread; no reflection is needed, since `()` is an ordinary value in Rust |
| `Environment.UserName` | `$USER`, then `$LOGNAME`, ignoring empty values, else "unknown" |

The worker does not touch GTK. The UI and its event loop stay on the main thread. This explicitly waits for persistence, unlike the original's intentionally awkward shared-context thread, so the thread is a nod to the original and not a source of concurrency. The application is a language exercise, not a recommendation to hide work inside iterator expressions.

## Check it

```bash
cargo fmt --check
cargo test --locked
cargo build --locked
```

Inspect the database with `sqlite3 data/demo-timecards.db 'select * from demo_timecards;'`.
