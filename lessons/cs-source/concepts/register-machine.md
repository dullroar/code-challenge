---
title: "Register machines and counter machines"
chapter: 2
order: 70
---
A register machine stores its values in a few numbered boxes called registers. Real processors are register machines. The smallest version, a *counter machine*, has only two operations: add one to a register, or subtract one and jump if the result is zero. It exists as a thinking tool: it is simple enough to prove things about, yet powerful enough to compute anything (two counters are enough). Several entries are register machines in disguise. CMake's `CMAKE_MATCH_1` to `CMAKE_MATCH_5` are the registers of [[entry:cmake]]. .NET's balancing groups, in [[entry:regex-dotnet]], are a counter.

```mermaid
flowchart TB
    accTitle: A register machine names its storage cells; a counter machine needs only increment, decrement and a zero test
    accDescr: Two panels. In the register machine, registers R1 and R2 hold 19 and 23. The instruction ADD R1, R2 into R1 leaves R1 holding 42 and R2 still holding 23. In the counter machine, counters C1 and C2 start at 2 and 0. A loop decrements C1, increments C2 and tests C1 for zero. If C1 is not zero, the loop runs again. When C1 reaches zero, C1 is 0 and C2 is 2.
    subgraph CNT["Counter machine"]
        direction TB
        c1["C1 = 2, C2 = 0"] --> c2["DEC C1, INC C2"]
        c2 --> c3{{"C1 is zero?"}}
        c3 -->|"no: loop"| c2
        c3 -->|"yes"| c4["C1 = 0, C2 = 2"]
    end
    subgraph REG["Register machine"]
        direction TB
        r1["R1 = 19, R2 = 23"] -->|"ADD R1, R2 into R1"| r2["R1 = 42, R2 = 23"]
    end
```

On the left, the instruction names its cells (`R1` and `R2`). On the right, the machine has two counters and three moves: count down, count up and test for zero. Moving a count from `C1` to `C2` takes one pass of the loop for each unit, so a counter machine is slow on purpose. What it shows is how little machinery is enough.

- **Use it when:** you want to explain what a strange system *is*, by finding its registers.
- **Avoid it as a coding style:** it is a model for reasoning, not a way to write programs.

**Read more:**

- [Register machine](https://en.wikipedia.org/wiki/Register_machine) (Wikipedia)
- [Counter machine](https://en.wikipedia.org/wiki/Counter_machine) (Wikipedia)
