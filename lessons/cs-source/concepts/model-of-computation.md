---
title: "Models of computation"
chapter: 2
order: 10
applies-to: has:machine
applies-because: "Each of these entries states, in its machine and state fields, what kind of machine it really is and where its state lives, which is the habit this concept teaches."
---
A model of computation is a precise description of what "computing" means: what one step is, and what memory exists. It exists because you cannot prove anything about "a computer" in general. You need rules small enough to reason about. Then you can ask: what can this model compute, and how fast? Famous models are the Turing machine, the lambda calculus, register machines and string-rewriting systems. This chapter uses a simple habit: **name the machine**. When a regex engine, a build tool or a markup file starts to compute, ask what kind of machine it has become.

- **Use it when:** you want to explain what a strange system really is, or to argue that it can (or cannot) do something.
- **Avoid it when:** you need to describe actual hardware. A Turing machine has an infinite tape. Your laptop does not.

**Read more:**

- [Model of computation](https://en.wikipedia.org/wiki/Model_of_computation) (Wikipedia)
- [Abstract machine](https://en.wikipedia.org/wiki/Abstract_machine) (Wikipedia)
- [Church–Turing thesis](https://en.wikipedia.org/wiki/Church%E2%80%93Turing_thesis) (Wikipedia)
