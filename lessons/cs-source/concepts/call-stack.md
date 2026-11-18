---
title: "The call stack"
chapter: 6
order: 20
---
The call stack is a stack of *frames*. Each active function call has one, holding its return address and its local variables. It exists so that functions can call functions, and recursion works. For most programmers the call stack *is* "where am I in the program". Several entries live without it, or work around it. A sed script has no calls at all. m4 and Make repeat by reading text again. The trigger recursion in [[entry:tcl-weird]] is limited by the database, not by a stack you can see.

```mermaid
flowchart TB
    accTitle: The call stack records where execution is and what each active call still needs
    accDescr: Two parts. On the left is a call stack with three frames, with the newest frame on top. The top frame is saveRow, with its argument, its local variable and a return address into drawCard. Below it is drawCard, with its locals and a return address into main. At the bottom is main, with its locals and a return address into the runtime. On the right are the returns in order. First saveRow returns and its frame is removed. Then drawCard returns. Then main returns.
    subgraph STACK["Call stack"]
        direction TB
        f3["top: saveRow(card). Locals: sql. Return into drawCard"] ~~~ f2["drawCard(). Locals: hours, category. Return into main"] ~~~ f1["bottom: main(). Locals: total, rows. Return into the runtime"]
    end
    subgraph RET["Returns, in order"]
        direction TB
        r1["1. saveRow returns, frame removed"] --> r2["2. drawCard returns, frame removed"] --> r3["3. main returns, stack empty"]
    end
    STACK ~~~ RET
```

Each active call owns one frame, and the newest frame is on top. When `saveRow` returns, its frame is removed and execution continues at the return address it stored, which is inside `drawCard`. The names here are examples, and the exact layout of a frame differs between languages and processors. The general idea of a stack is in [[stack-data-structure]].

- **Use it when:** you read a stack trace, or you reason about recursion depth.
- **Avoid:** unbounded recursion. A stack overflow ends the program, and in unsafe languages it can become a security hole.

**Read more:**

- [Call stack](https://en.wikipedia.org/wiki/Call_stack) (Wikipedia)
- [Stack buffer overflow](https://en.wikipedia.org/wiki/Stack_buffer_overflow) (Wikipedia)
- [Tail call](https://en.wikipedia.org/wiki/Tail_call) (Wikipedia)
