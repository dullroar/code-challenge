---
title: "Referential transparency"
chapter: 4
order: 70
---
An expression is referentially transparent if you can replace it with its value and the program does not change. `2 + 3` is. `readLine()` is not, because it gives a different answer each time. It exists as the rule behind *pure* functions: they are easy to test, to cache, to run in parallel and to rearrange. Effects break it. That is the whole point of [[entry:haskell-weird]]: it hides input and output inside a list, so a list that looks like plain data is not plain data. Where it is allowed to be violated, the code must say so loudly.

```mermaid
flowchart LR
    accTitle: Pure expressions can be replaced by their values; a clock read cannot
    accDescr: Two parallel groups of calls. On the left, evaluating 2 plus 3 gives 5, and evaluating it again gives 5, so the value is the same and substitution is safe. On the right, calling now at time t0 gives 10:00:00, and calling it at time t1 gives 10:00:01, so the result depends on when it is evaluated, and replacing the call with one constant changes the behavior. The clock times are illustrative.
    subgraph CLOCK["Time-dependent call"]
        direction LR
        B2["now() at t₁"] --> W2["10:00:01"]
        B1["now() at t₀"] --> W1["10:00:00"]
        W1 --> NO["the result depends on when it is evaluated: one constant in its place changes the behavior"]
        W2 --> NO
    end
    subgraph STABLE["Replaceable expression"]
        direction LR
        A2["evaluate 2 + 3 again"] --> V2["5"]
        A1["evaluate 2 + 3"] --> V1["5"]
        V1 --> OK["same value: substitution is safe"]
        V2 --> OK
    end
```

The left side can be replaced by `5` anywhere. The right side cannot: the call's value depends on *when* it runs, and the times shown are only illustrative. This is about referential transparency, which is the same as repeatability here, and not about [[idempotence]]. A function that reads the clock changes nothing, so it is not "non-idempotent". It is just not repeatable. [[idempotence]] is about what an operation does to state.

- **Use it when:** as much as you can. Keep the pure core large and push effects to the edges.
- **Avoid pretending:** random numbers, clocks, files and networks are not transparent.

**Read more:**

- [Referential transparency](https://en.wikipedia.org/wiki/Referential_transparency) (Wikipedia)
- [Pure function](https://en.wikipedia.org/wiki/Pure_function) (Wikipedia)
- [Functional programming](https://en.wikipedia.org/wiki/Functional_programming) (Wikipedia)
