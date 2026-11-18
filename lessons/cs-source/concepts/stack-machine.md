---
title: "Stack machines"
chapter: 2
order: 60
---
A stack machine keeps its working values on a stack. An instruction takes its inputs from the top and puts its result back. There are no named registers. It exists because the instructions can be tiny (`+` needs no operands) and a compiler can generate them easily. That is why the JVM, .NET's IL, WebAssembly, PostScript and Forth all use the idea. In [[entry:forth-weird]] the data stack is the *only* memory: the program has no `variable` at all.

```mermaid
flowchart TB
    accTitle: Stack machines compute by pushing and popping values at the top of a LIFO stack
    accDescr: Three snapshots of a stack, top to bottom, each drawn from the stack's bottom on the left to its top on the right. At the start the stack holds 19 with 23 on top. The instruction ADD pops the top two values and pushes their sum, so the stack holds only 42. Then PUSH 10 puts 10 on top, and the stack holds 42 with 10 on top. Every step touches only the top of the stack, and no instruction names a location.
    subgraph S1["Start (bottom on the left, top on the right)"]
        direction LR
        a1["19"] ~~~ a2["23 (top)"]
    end
    subgraph S2["After ADD"]
        direction LR
        b1["42 (top)"]
    end
    subgraph S3["After PUSH 10"]
        direction LR
        c1["42"] ~~~ c2["10 (top)"]
    end
    S1 -->|"ADD: pop two values, push their sum"| S2
    S2 -->|"PUSH 10: push one value"| S3
```

Read the picture from top to bottom. `ADD` does not say where its inputs are: it pops the top two values and pushes one result. A real stack machine still has other memory (the JVM has local variables and a heap, for example). The stack only holds the values that the next instruction needs.

- **Use it when:** you build a small virtual machine or interpreter, or you want compact code.
- **Avoid it when:** you need random access to many values. Shuffling the stack with `dup`, `swap` and `rot` becomes unreadable fast.

**Read more:**

- [Stack machine](https://en.wikipedia.org/wiki/Stack_machine) (Wikipedia)
- [Reverse Polish notation](https://en.wikipedia.org/wiki/Reverse_Polish_notation) (Wikipedia)
- [Forth (programming language)](https://en.wikipedia.org/wiki/Forth_(programming_language)) (Wikipedia)
