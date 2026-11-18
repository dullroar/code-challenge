---
title: "First-class and higher-order functions"
chapter: 4
order: 85
---
A language has **first-class functions** when a function is a value: you can store it, pass it as an argument, return it from another function and keep it in a data structure. A **higher-order function** is a function that takes a function, returns one, or both. `map`, `filter` and `reduce` take functions. A function that builds a configured function, such as a counter factory, returns one.

It exists because it lets you separate *what to do to each item* from *how to walk the items*. The walk can then be lazy, eager, parallel or early-stopping, and the code that says what to do does not change. [[entry:haskell]] describes the cards with `zipWith3` and `scanl1`. [[entry:LinqChallenge1]] chains `Select` and `Aggregate`. [[entry:RustChallenge1]] steers a loop with iterators and closures. [[entry:javascript-weird]] is built the same way throughout: a pipeline of `map` calls that take closures, ended by `toArray`, and a `reduce` over the finished list.

The price is a different kind of reading. When the walk is hidden in a library call, you cannot see in what order the callbacks run, how many times, or whether the walk stops early. That matters when the callback has an effect. `reduce` cannot stop early, `some` can, and the lazy `map` of an iterator runs one value at a time while an array's `map` finishes each stage before the next one begins ([[entry:javascript-weird]] shows both orders).

- **Use it when:** the work on each item is separate from the walk, or you want to reuse one walk with many callbacks.
- **Avoid it when:** the callback has hidden effects and the order matters. Write the order down, or use a plain loop and say why.

**Read more:**

- [First-class function](https://en.wikipedia.org/wiki/First-class_function) (Wikipedia)
- [Higher-order function](https://en.wikipedia.org/wiki/Higher-order_function) (Wikipedia)
- [Functions](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Functions) (MDN)
