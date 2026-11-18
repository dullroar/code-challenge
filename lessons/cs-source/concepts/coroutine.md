---
title: "Coroutines"
chapter: 3
order: 60
---
A coroutine is a function that can pause in the middle and resume later, with its local variables intact. Ordinary functions run from start to finish. A coroutine can hand a value to its caller, wait, and carry on when asked. It exists for producers and consumers, for generators and for cooperative multitasking (`async`/`await` is built on the idea). Several entries are coroutines wearing a different hat. A Rust iterator made with `successors`, a Kotlin `generateSequence` and Python's `iter(step, False)` each produce the next value only when the loop asks for it.

```mermaid
sequenceDiagram
    accTitle: Coroutines suspend and resume cooperatively, keeping their own local state between yields
    accDescr: A sequence diagram with a caller and two coroutines, A and B. The caller starts A. A runs and yields to B. B runs and yields back to A. A resumes just after its yield, with its local variables intact, runs more, and yields to B again. B resumes just after its own yield. B yields back to A, A finishes and returns to the caller. Only one routine runs at a time, and control moves only when a routine yields.
    participant C as Caller
    participant A as Coroutine A
    participant B as Coroutine B
    C->>A: start
    Note over A: runs until its first yield
    A->>B: yield to B
    Note over B: starts, runs until its first yield
    B->>A: yield back to A
    Note over A: resumes after its yield, locals intact
    A->>B: yield to B again
    Note over B: resumes after its yield, not from the top
    B->>A: yield back to A
    A->>C: finishes, returns to the caller
    Note over A,B: one runs at a time: nothing preempts it
```

Control moves only when a coroutine yields, so only one routine runs at a time. That is the difference from threads: nothing preempts a coroutine, and nothing runs in parallel. A coroutine that resumes continues after its last `yield`, with its local variables as it left them. An ordinary call would start again from the top.

- **Use it when:** you process a stream, or you want two pieces of code to take turns without threads.
- **Avoid it when:** you need real parallelism, or when the many pause points make the program hard to follow.

**Read more:**

- [Coroutine](https://en.wikipedia.org/wiki/Coroutine) (Wikipedia)
- [[generators]] in "Evaluation and demand"
