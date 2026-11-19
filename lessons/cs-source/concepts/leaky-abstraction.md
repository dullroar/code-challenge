---
title: "Leaky abstractions"
chapter: 8
order: 10
---
An abstraction hides details so that you can think at a higher level. A *leaky* abstraction lets the hidden details show through when something goes wrong, or when speed matters. Joel Spolsky named the "Law of Leaky Abstractions" in 2002: every non-trivial abstraction leaks, at least a little. This book is a collection of leaks, found on purpose. "Matching text" leaks its backtracking cost. A build tool's "dependency" leaks file timestamps. LINQ's "query" leaks the limits of its SQL provider. You do not need to give up the abstraction. You need to know one layer below it.

- **Use it when:** you learn a tool: ask "what is under this, and when will it show?"
- **Avoid it when:** correctness depends on a leak you cannot document.

**Read more:**

- [Leaky abstraction](https://en.wikipedia.org/wiki/Leaky_abstraction) (Wikipedia)
- [Abstraction (computer science)](https://en.wikipedia.org/wiki/Abstraction_(computer_science)) (Wikipedia)
