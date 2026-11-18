---
title: "Recursion"
chapter: 3
order: 40
---
A recursive definition uses itself. A function calls itself on a smaller problem until the problem is so small that the answer is obvious. It exists because many things are naturally nested: trees, folders, grammars, arithmetic expressions. Loops and recursion are equally powerful, and functional languages use recursion instead of loops. Several entries here recurse in disguise. In [[entry:m4]] a macro whose replacement text contains itself is read again, which makes a loop. In [[entry:tcl-weird]] a database trigger inserts a row, which fires the same trigger again. The stop rule is a query that finds nothing.

```mermaid
flowchart LR
    accTitle: Recursion moves toward a base case, then unwinds with the accumulated results
    accDescr: Two columns for sum of 3. The left column, read downward, shows the calls moving inward. Sum of 3 calls sum of 2, which calls sum of 1, which calls sum of 0. Sum of 0 is the base case and returns 0 without calling anything. The right column, read upward, shows the results coming back outward. Sum of 1 is 1 plus 0, which is 1. Sum of 2 is 2 plus 1, which is 3. Sum of 3 is 3 plus 3, which is 6.
    subgraph DOWN["Calls go down"]
        direction TB
        n3["sum(3)"] -->|calls| n2["sum(2)"] -->|calls| n1["sum(1)"] -->|calls| n0(["sum(0): base case"])
    end
    subgraph UP["Results come back up"]
        direction BT
        u0["sum(0) = 0"] -->|returns| u1["sum(1) = 1 + 0 = 1"] -->|returns| u2["sum(2) = 2 + 1 = 3"] -->|returns| u3["sum(3) = 3 + 3 = 6"]
    end
    DOWN --> UP
```

On the way down, each call hands a smaller problem to the next call. The base case, `sum(0)`, is the only call that answers without calling again. Without it the calls never stop. On the way up, each call finishes the work it was waiting to do. [[call-stack]] shows where those waiting calls are kept.

- **Use it when:** the data is nested, or the problem splits into smaller copies of itself.
- **Avoid it when:** the depth is unbounded and the language does not remove tail calls. The stack can run out. Always know the stop rule, and know what happens if it never fires.

**Read more:**

- [Recursion (computer science)](https://en.wikipedia.org/wiki/Recursion_(computer_science)) (Wikipedia)
- [Tail call](https://en.wikipedia.org/wiki/Tail_call) (Wikipedia)
- [Recursion](https://developer.mozilla.org/en-US/docs/Glossary/Recursion) (MDN glossary)
