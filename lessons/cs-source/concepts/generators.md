---
title: "Iterators and generators"
chapter: 4
order: 60
---
An *iterator* is an object that answers "give me the next one". A *generator* is a function you write as ordinary straight-line code that hands out values one at a time with `yield`. Both exist so that you can handle a sequence that is too big to store, or has no end, and so that the code that produces values stays separate from the code that uses them. Four entries are built on the idea: Rust's `successors`, Kotlin's `generateSequence`, Python's `iter(step, False)` and Haskell's lazy lists. In each one, the loop "stops" because the consumer stops asking.

- **Use it when:** you stream data, or describe an unlimited series and take a prefix.
- **Avoid:** iterators with hidden effects, and the surprise of a one-shot iterator that is already used up.

**Read more:**

- [Iterator](https://en.wikipedia.org/wiki/Iterator) (Wikipedia)
- [Generator (computer programming)](https://en.wikipedia.org/wiki/Generator_(computer_programming)) (Wikipedia)
- [Stream (computing)](https://en.wikipedia.org/wiki/Stream_(computing)) (Wikipedia)
- [Iterators and generators](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Iterators_and_generators) (MDN), a clear tutorial on the idea
