---
title: "Eager evaluation"
chapter: 4
order: 20
---
Eager evaluation computes a value as soon as the code asks for it. It is the default in most languages. It exists because it is simple: cost and order are easy to predict, and effects happen exactly where you wrote them. [[entry:apl]] is eager in a strong sense: each primitive works on a whole array at once. The entry draws five numbers, a bound that can never be too small, although it often needs fewer. "Draw more than enough, then trim" replaces a loop that decides when to stop.

- **Use it when:** you need a predictable order of effects, or when the result will certainly be used.
- **Avoid it when:** the work might be wasted, or the source is huge or infinite.

**Read more:**

- [Eager evaluation](https://en.wikipedia.org/wiki/Eager_evaluation) (Wikipedia)
- [[lazy-evaluation]], the opposite idea
