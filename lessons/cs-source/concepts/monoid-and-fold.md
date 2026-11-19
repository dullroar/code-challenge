---
title: "Monoids and folds"
chapter: 4
order: 100
---
A **monoid** is a type with an *associative* combining operation and an *identity* value. Integers with `+` and `0` are a monoid. So are strings with concatenation and `""`. A **fold** (also called `reduce` or `Aggregate`) collapses a list into one value by combining the items one at a time, starting from a seed.

When the operation is associative, the grouping does not matter: `(a + b) + c = a + (b + c)`. That lets a fold be split across threads, or restarted from a partial result. When there is an identity, the fold of an empty list has a sensible answer: the seed.

A **scan** (`scanl` in Haskell) is a fold that keeps every partial result: `scanl (+) 0 [10,12,15]` is `[0,10,22,37]`. A running total is a scan. [[entry:haskell]] uses `scanl1` to get every running total of the card hours, then `span` to take the cards until one crosses 40. A fold gives only the last total, and cannot say where to stop. In JavaScript, `reduce` is a fold. It cannot stop early by itself, because it must walk the whole array (it has no `break`). Stopping needs `some`, `find`, a generator or a different tool. [[entry:javascript-weird]] shows each of these.

An associative operation is not the same as a commutative one. `"ab" + "c"` is not `"c" + "ab"`. Folds over non-commutative monoids depend on order.

- **Use it when:** you accumulate a result, and you want to know whether it can be split, merged or restarted.
- **Avoid it when:** you need the first item that satisfies a test. A fold that cannot stop early does too much work, or too much of the wrong work.

**Read more:**

- [Monoid](https://en.wikipedia.org/wiki/Monoid) (Wikipedia)
- [Fold (higher-order function)](https://en.wikipedia.org/wiki/Fold_(higher-order_function)) (Wikipedia)
- [Prefix sum](https://en.wikipedia.org/wiki/Prefix_sum) (Wikipedia)
- [`Array.prototype.reduce()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/reduce) (MDN)
