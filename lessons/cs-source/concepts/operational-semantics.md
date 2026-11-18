---
title: "Operational semantics"
chapter: 2
order: 110
---
**Operational semantics** says what a program means by saying how it runs: what a machine's *state* is, and what *one step* does to it. A language is then a set of rules of the form "in this state, this construct moves the machine to that state". It is the most direct way to answer "what does this actually do?", and it is what you do when you read a program one transition at a time.

Every entry that names its machine could be described this way. Three do it on the page. [[entry:tar-gnu-weird]] has one row of registers (the hours worked, the target, the total, the seed, a done flag) and one transition, run once per tar checkpoint. [[entry:javascript]] is the three clauses of a `for`: initialize once, then test, body, update, test, body, update. Its README traces one card through them. [[entry:ex-weird]] has marks and registers as its state, and each command line moves them.

- **Use it when:** you must explain, or check, exactly what a strange construct does. Write down the state and the step, and run it by hand.
- **Avoid it when:** you need to compare programs by what they compute and not by how. Then you want a semantics that ignores the steps.

**Read more:**

- [Operational semantics](https://en.wikipedia.org/wiki/Operational_semantics) (Wikipedia)
- [Transition system](https://en.wikipedia.org/wiki/Transition_system) (Wikipedia)
