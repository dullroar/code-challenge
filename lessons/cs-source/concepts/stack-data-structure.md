---
title: "The stack as a data structure"
chapter: 6
order: 30
---
A stack is a pile where you add and remove at the top only: last in, first out. It is the right shape for anything nested: undo, expression evaluation, bracket matching and backtracking. In this repository the stack appears in two unusual places. In [[entry:forth-weird]] the data stack is the only memory. In [[entry:regex-dotnet]] *balancing groups* push a capture when they see an opening mark and pop one when they see a closing mark. A stack of marks is a counter, so a regex can compare two counts.

```mermaid
flowchart TB
    accTitle: A stack is last-in, first-out, and only the top element can be pushed or popped
    accDescr: Three snapshots of a stack, top to bottom, each drawn from the stack's bottom on the left to its top on the right. At the start the stack holds only A. After push B and push C it holds A, B and C, with C on top. Two pops then return C first and B second, leaving only A. The most recent push is always the first to come back out.
    subgraph T1["Start (bottom on the left, top on the right)"]
        direction LR
        a1["A (top)"]
    end
    subgraph T2["After two pushes"]
        direction LR
        b1["A"] ~~~ b2["B"] ~~~ b3["C (top)"]
    end
    subgraph T3["After two pops"]
        direction LR
        c1["A (top)"]
    end
    T1 -->|"push B, then push C"| T2
    T2 -->|"pop gives C, pop gives B"| T3
```

Only the top can be reached. A push adds on top and a pop removes from the top, so the last item in is the first one out. [[call-stack]] is one use of this structure, with frames as the items. Undo lists, bracket matching and the data stack of [[entry:forth-weird]] are others.

- **Use it when:** the problem is nested, or you must undo in reverse order.
- **Avoid it when:** you need random access or first-in, first-out order. Use an array or a queue.

**Read more:**

- [Stack (abstract data type)](https://en.wikipedia.org/wiki/Stack_(abstract_data_type)) (Wikipedia)
- [Pushdown automaton](https://en.wikipedia.org/wiki/Pushdown_automaton) (Wikipedia)
