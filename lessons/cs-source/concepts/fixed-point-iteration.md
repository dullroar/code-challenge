---
title: "Fixed-point iteration"
chapter: 3
order: 50
---
A *fixed point* of a function is a value that the function leaves unchanged: f(x) = x. Fixed-point iteration finds one by applying the function again and again until nothing changes. It exists because many problems are really "keep going until it settles": balance an equation, compute a closure, or simplify an expression. This repository is full of it. [[entry:regex-sed]] applies substitutions until none matches. [[entry:make-gnu]] remakes its own makefile until the makefile is up to date. A compiler's optimizer does the same, passing over the code until no more improvements appear.

```mermaid
flowchart TB
    accTitle: Fixed-point iteration means keep transforming until one more pass changes nothing
    accDescr: A chain of values, top to bottom. The start value x0 goes through f to give x1, through f again to give x2, and through f again to give x-star. Applying f to x-star gives x-star again, so the value is unchanged. Because the output equals the input, the iteration stops. That unchanged value is the fixed point.
    x0["x0: start"] -->|"apply f"| x1["x1"] -->|"apply f"| x2["x2"] -->|"apply f"| xs["x*"]
    xs -->|"apply f"| same["x*: unchanged"]
    same ==>|"output equals input: stop"| done(["Fixed point: f(x*) = x*"])
```

Every pass applies the same function `f`. The run stops when a pass returns its own input, so that `f(x*) = x*`. The value `x` does not have to be a number. It can be a line of text (as in [[entry:regex-sed]]), a makefile or a piece of code. A real program also needs a limit, in case the values never settle.

- **Use it when:** each step is a clear improvement and "no change" is a clear signal to stop.
- **Avoid it when:** the process might never settle. It can bounce between two states forever. Always add a limit, or a timeout. The sandbox gives every `check.sh` a time limit.

**Read more:**

- [Fixed-point iteration](https://en.wikipedia.org/wiki/Fixed-point_iteration) (Wikipedia)
- [Fixed point (mathematics)](https://en.wikipedia.org/wiki/Fixed_point_(mathematics)) (Wikipedia)
