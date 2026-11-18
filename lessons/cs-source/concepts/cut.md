---
title: "The cut: committing to a choice"
chapter: 7
order: 70
---
The *cut* is a Prolog idea: once the program has passed this point, commit to the choices made so far and discard the alternatives. It exists for speed and for determinism: you do not want a search to explore, or repeat, work you already know is settled. Regex engines have the same tools: PCRE's `(*COMMIT)`, atomic groups and possessive quantifiers. [[entry:regex-pcre2]] and its siblings end the pattern with `(*COMMIT)(*FAIL)`. Without `(*COMMIT)` the engine would retry shorter loops, and the finalizer would run more than once. Prolog programmers distinguish "green" cuts (only speed) from "red" cuts (they change the answer).

```mermaid
flowchart TB
    accTitle: The cut changes the search space itself, so abandoned alternatives are no longer considered
    accDescr: A search tree with a cut. From the start there are two choices, A and B. The search takes A and reaches the cut, which commits to A. Choice B is drawn with a dashed border and marked pruned, because the cut removed it, and plain backtracking would have tried it later. After the cut, the search can still try the alternatives that come after the cut, A1 and then A2. A1 is a dead end and A2 succeeds. If A2 had failed as well, the whole search would fail and B would still never be tried.
    S(["Start: two choices"]) -->|"1. try A"| A["A"]
    A --> C{{"CUT: commit to A"}}
    C --> A1["A1: dead end"]
    C --> A2(["A2: success"])
    S -.->|"B is cut off"| B["B: pruned, never tried"]
    classDef pruned stroke-dasharray: 5 5
    class B pruned
```

Compare this picture with plain backtracking. There, `B` would be tried after `A` failed. Here the cut commits to `A` first, so `B` is pruned. After the cut the search can still try the alternatives that come *after* it (`A1`, then `A2`). If all of them fail, the whole search fails. It does not go back to `B`. That is what "the cut changes the search space" means. Prolog's cut also discards choices made earlier in the same clause, and the picture shows only the simplest case.

- **Use it when:** you know that later failure should never lead to a retry.
- **Avoid it when:** you are not sure which kind of cut you have. A red cut hides a logic change inside a speed trick.

**Read more:**

- [Cut (logic programming)](https://en.wikipedia.org/wiki/Cut_(logic_programming)) (Wikipedia)
- [Prolog](https://en.wikipedia.org/wiki/Prolog) (Wikipedia)
