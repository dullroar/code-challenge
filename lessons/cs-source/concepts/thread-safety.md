---
title: "Thread safety and thread affinity"
chapter: 7
order: 100
---
Code is thread-safe if it behaves correctly when several threads use it at the same time. It exists as a problem because shared, changeable data plus parallel threads equals a race: the result depends on who gets there first. The entries on .NET and its ports touch two versions of the problem. In the C# entries, an EF Core `DbContext` is not thread-safe. In the one-statement ports, the code locks around the staged cards while a background thread saves them. And WPF has *thread affinity*: a window may only be touched by the thread that made it. Code that works once is not proof that it is safe.

- **Use it when:** you share data across threads: use locks, immutable data, or one context per thread.
- **Avoid:** sharing a changeable object between threads "just because it worked in the test".

**Read more:**

- [Thread safety](https://en.wikipedia.org/wiki/Thread_safety) (Wikipedia)
- [Race condition](https://en.wikipedia.org/wiki/Race_condition) (Wikipedia)
