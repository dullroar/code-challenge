---
title: "Logical clocks and event ordering"
chapter: 3
order: 100
---
A **logical clock** counts *events*, not seconds. It answers "what happened before what?" and "how many steps have passed?" without asking how long anything took. Distributed systems use logical clocks because real clocks on different machines disagree. A program can also use one on a single machine, to make its behavior independent of speed.

In [[entry:tar-gnu-weird]] one tar checkpoint is one hour of work. The clock is the number of records tar has written, and `check.sh` predicts the result of a run from the archive's layout alone. A faster or a slower machine makes no difference. A longer archive gives more ticks, a shorter one stalls the program, and a different checkpoint interval changes the count in a way the check calculates in advance. One detail is easy to miss: `TAR_CHECKPOINT` counts *records* (with `--checkpoint=2` it reads 2, 4, 6), while the machine counts *calls*. They are two clocks, and the entry says which one it uses. [[entry:make-gnu]] has a counter of a similar kind: `MAKE_RESTARTS` counts rounds of the build, not time.

- **Use it when:** you need to order events, to make a run repeatable, or to test timing without waiting.
- **Avoid it when:** the real duration is the thing you need. A logical clock cannot tell you how long anything took.

**Read more:**

- [Logical clock](https://en.wikipedia.org/wiki/Logical_clock) (Wikipedia)
- [Lamport timestamp](https://en.wikipedia.org/wiki/Lamport_timestamp) (Wikipedia)
