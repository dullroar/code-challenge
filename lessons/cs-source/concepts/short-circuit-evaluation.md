---
title: "Short-circuit evaluation"
chapter: 4
order: 40
---
Short-circuit evaluation means that `and` and `or` stop as soon as the answer is known. In `a && b`, if `a` is false, `b` never runs. It exists for speed, and for a very useful habit: guard first, then act (`x != null && x.length > 0`). The same idea can be a loop. In [[entry:lisp-weird]] the `or` method combination calls methods one after another and stops at the first one that returns a true value. A class hierarchy becomes the loop, and `or` becomes the stop rule.

```mermaid
flowchart TB
    accTitle: Short-circuiting is control flow that can suppress work and side effects
    accDescr: Two panels. In the first, false AND expensive() evaluates the left side, which is false. A false left side makes AND false whatever the right side is, so the result is false and the call to expensive() is skipped. In the second, true OR expensive() evaluates the left side, which is true. A true left side makes OR true whatever the right side is, so the result is true and the call to expensive() is skipped. In both panels the skipped call is drawn with a dashed border and an arrow that is never followed.
    subgraph P1["false AND expensive()"]
        direction TB
        l1["left side: false"] --> d1{{"false AND anything is false"}}
        d1 -->|"answer known"| r1(["result: false"])
        d1 -.->|"skipped"| x1["expensive(): never runs"]
    end
    subgraph P2["true OR expensive()"]
        direction TB
        l2["left side: true"] --> d2{{"true OR anything is true"}}
        d2 -->|"answer known"| r2(["result: true"])
        d2 -.->|"skipped"| x2["expensive(): never runs"]
    end
    P1 ~~~ P2
    classDef skip stroke-dasharray: 5 5
    class x1,x2 skip
```

In both panels the left operand settles the answer, so the right operand is skipped. Anything it would have done, such as a slow query, a write or a printed line, does not happen. That is why `x != null && x.length > 0` is safe. It also means that an effect in the right operand is not a promise. See [[side-effect]].

- **Use it when:** you guard a risky operation, or pick the first good answer.
- **Avoid it when:** the second operand has an effect you expect to always happen. It silently will not.

**Read more:**

- [Short-circuit evaluation](https://en.wikipedia.org/wiki/Short-circuit_evaluation) (Wikipedia)
- [Common Lisp Object System](https://en.wikipedia.org/wiki/Common_Lisp_Object_System) (Wikipedia)
- [Logical AND (`&&`)](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Logical_AND) (MDN), which describes short-circuiting in plain words
