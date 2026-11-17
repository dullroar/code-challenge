---
title: "A lazy sequence that someone keeps asking for"
order: 20
---
There is no loop. There is a sequence that someone keeps asking for, and the program stops when the asking stops. [[entry:haskell]] describes the cards as an infinite lazy list and takes a prefix with `span`. [[entry:haskell-weird]] puts the effects inside the list, so reading it does the work. LINQ builds a deferred pipeline that a final eager operator forces. Kotlin's `generateSequence`, Rust's `successors` and Python's `iter(step, False)` give a similar shape in other languages. The difference between the entries is *who forces the sequence*, and *when*.
