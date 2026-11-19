---
title: "Iterators and generators"
chapter: 4
order: 60
---
An *iterator* is an object that answers "give me the next one". A *generator* is a function you write as ordinary straight-line code that hands out values one at a time with `yield`. Both exist so that you can handle a sequence that is too big to store, or has no end, and so that the code that produces values stays separate from the code that uses them. Four entries are built on the idea: Rust's `successors`, Kotlin's `generateSequence`, Python's `iter(step, False)` and Haskell's lazy lists. In each one, the loop "stops" because the consumer stops asking. JavaScript spells the idea out as the **iteration protocol**: an iterable has a `[Symbol.iterator]()` method that answers an object with a `next()` method, and `next()` answers `{ value, done }`. [[entry:javascript-weird]] writes one by hand around a closure, and a consumer such as `toArray()` or `take(1)` decides how many values ever exist. It also shows the one-shot trap: a second pass over the same iterator finds it already used up.

```mermaid
sequenceDiagram
    accTitle: Generators answer one next-value request at a time, resuming from where they last yielded
    accDescr: A sequence diagram with a consumer and a generator. The consumer calls next. The generator runs to its first yield and hands back 19. The consumer calls next again, and the generator resumes after the yield and hands back 23. Another call gives 17. On the fourth call the generator has nothing left and signals done. The consumer drives every step, and the generator keeps its internal state between yields.
    participant C as Consumer
    participant G as Generator
    C->>G: next()
    G-->>C: yield 19
    C->>G: next()
    Note right of G: resumes after the last yield
    G-->>C: yield 23
    C->>G: next()
    G-->>C: yield 17
    C->>G: next()
    G-->>C: done
    Note right of G: internal state is kept between yields
```

The consumer asks and the generator answers. This is *pull*: nothing runs until `next()` is called, and the generator does only enough work to reach its next `yield`. A push design, such as a callback, would draw the arrows the other way (see [[callback]]). The consumer can also stop early by not asking again.

- **Use it when:** you stream data, or describe an unlimited series and take a prefix.
- **Avoid it when:** the iterator has hidden effects or callers expect to reuse a one-shot iterator.

**Read more:**

- [Iterator](https://en.wikipedia.org/wiki/Iterator) (Wikipedia)
- [Generator (computer programming)](https://en.wikipedia.org/wiki/Generator_(computer_programming)) (Wikipedia)
- [Stream (computing)](https://en.wikipedia.org/wiki/Stream_(computing)) (Wikipedia)
- [Iterators and generators](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Iterators_and_generators) (MDN), a clear tutorial on the idea
