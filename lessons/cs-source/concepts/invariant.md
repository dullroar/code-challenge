---
title: "Invariants"
chapter: 2
order: 40
---
An invariant is a fact that stays true at every step. It exists because you cannot test every possible state of a program, but you *can* prove two things: the fact is true at the start, and every step keeps it true. Then it is true forever. In this repository a database rule such as `CHECK(demo_only=1)` is an invariant of the data: a non-demo row cannot exist. Each `check.sh` tries to break it, to show that the rule is real. Loop invariants work the same way: "the total so far equals the sum of the cards drawn".

- **Use it when:** you design a loop, a data schema, a concurrent algorithm or an assertion.
- **Avoid:** invariants that nobody can check, or that are so weak they say nothing.

**Read more:**

- [Invariant (computer science)](https://en.wikipedia.org/wiki/Invariant_(computer_science)) (Wikipedia)
- [Loop invariant](https://en.wikipedia.org/wiki/Loop_invariant) (Wikipedia)
