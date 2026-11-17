---
title: "Observability"
chapter: 2
order: 50
---
Observability is how much of a system's inside you can learn from the outside: through output, logs and traces. It exists because you cannot fix what you cannot see. Several entries have a trace switch for this reason. For example, `TRACE=1 ./timecards.sh` in [[entry:regex-sed]] prints the whole program state at every step. But watching can change what you watch. In a lazy language, printing a value *forces* it, so the act of looking makes the computation happen. Programmers call a bug that vanishes when you look at it a *heisenbug*.

- **Use it when:** you design anything you will have to debug later. Log state changes, not only errors.
- **Avoid:** logging secrets, and forgetting that observation has a cost (and sometimes an effect).

**Read more:**

- [Observability (software)](https://en.wikipedia.org/wiki/Observability_(software)) (Wikipedia)
- [Heisenbug](https://en.wikipedia.org/wiki/Heisenbug) (Wikipedia)
