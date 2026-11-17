---
title: "Integrity constraints"
chapter: 7
order: 50
---
An integrity constraint is a rule that the database itself enforces: `NOT NULL`, `UNIQUE`, `FOREIGN KEY`, `CHECK`. It exists because "we validate in the application" is only as good as every application. A constraint makes bad data *impossible*, not just unlikely. In this repository `CHECK(demo_only=1)` appears in nearly every entry: a table where a non-demo row cannot exist, which each `check.sh` tries to violate. Here constraints are also used as a stop rule (a violation ends the run) and as a guarantee. The second use is the one to keep in real programs.

- **Use it when:** a rule must hold no matter who writes the data. See also [[invariant]].
- **Avoid:** relying on constraints as your only validation (the messages are for programmers, not users), or building rules so complex that they need triggers.

**Read more:**

- [Integrity constraint](https://en.wikipedia.org/wiki/Integrity_constraint) (Wikipedia)
- [Check constraint](https://en.wikipedia.org/wiki/Check_constraint) (Wikipedia)
