# By language

Each page covers what makes the language special, with pointers into the repo, then its quirks. Links look like `file#Lnn`: line numbers drift, so the key line is quoted too.

| Page | Entries | The weird trick | The deeper lesson |
| --- | --- | --- | --- |
| [C#, LINQ, XAML](csharp-linq-xaml.md) | `ModernChallenge1`, `LinqChallenge1/2`, `xaml`, plus Java, Kotlin, Python, Go, Rust | Everything inside a bodiless `for`; database writes and WPF animation inside a query; a parser that runs methods | Deferred execution, provider boundaries, side effects, UI thread affinity |
| [COBOL](cobol.md) | `cobol`, `cobol-weird` | `ALTER` changes a `GO TO` destination; an overflowing field is the stop rule | Mutable control flow, data-declared rules, historical runtime design |
| [Haskell](haskell.md) | `haskell`, `haskell-weird` | Evaluating a list element performs I/O | Laziness, evaluation order, referential transparency, unsafe operations |
| [Forth](forth.md) | `forth`, `forth-weird` | The text interpreter's parse position is the program counter | The interpreter is a program you can reach into |
| [Make and CMake](make-cmake.md) | `make-gnu`, `cmake` | Remaking makefiles becomes a loop; regex captures become registers | Dependency graphs, restart semantics, scope, stateful condition evaluation |
| [Regex](regex.md) | `regex-perl`, `regex-pcre2`, `regex-pcre2grep`, `regex-dotnet`, `regex-sed` | Substitutions implement arithmetic and state; matches that return false after doing the work | String-rewriting systems, backtracking as search, performance cliffs |
| [APL](apl.md) | `apl`, `apl-weird` | Five rolls and one take-while; functions that manufacture their successors | Code as data, metaprogramming, and a notation that was meant for the whiteboard |

Prefer to start from a mechanism instead? See [patterns](../patterns.md). Back to the [lessons index](../README.md).
