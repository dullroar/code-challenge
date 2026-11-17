---
title: "Evaluation strategies"
chapter: 4
order: 10
---
An evaluation strategy answers one question: *when* is an argument computed? Before the call (call by value, also called eager)? When it is first needed, and then remembered (call by need, also called lazy)? Every time it is used (call by name)? It exists because the answer changes what a program means as soon as there are effects or infinite data. `f(g(x))` looks the same in every language. It does not behave the same. This whole chapter is about that gap: [[entry:haskell]] is lazy, [[entry:apl]] is eager, and LINQ is *deferred*.

- **Use it when:** you read any unfamiliar language. Find its default strategy first.
- **Avoid assuming** that your habits from one language apply in another.

**Read more:**

- [Evaluation strategy](https://en.wikipedia.org/wiki/Evaluation_strategy) (Wikipedia)
- [Call-by-need](https://en.wikipedia.org/wiki/Call-by-need) (Wikipedia)
- [Call-by-name](https://en.wikipedia.org/wiki/Call-by-name) (Wikipedia)
