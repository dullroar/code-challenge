---
title: "Functors and mapping"
chapter: 4
order: 90
---
A **functor** is a container type with a `map` that applies a function to the values inside *without changing the container's shape*. To count as a functor, `map` must obey two laws:

- **Identity:** `map(id, xs) = xs`. Mapping a function that changes nothing changes nothing.
- **Composition:** `map(g ∘ f, xs) = map(g, map(f, xs))`. Mapping two functions in one pass equals mapping them one after the other.

Lists, `Maybe`, and functions themselves are functors in Haskell (`fmap`). JavaScript's `Array.prototype.map`, LINQ's `Select` and a Kotlin `Sequence.map` all *look* like this. Whether each one really obeys the laws depends on what the function does. If the function has a side effect, or reads a counter, the second law fails in practice: the effects happen in a different order. `[1,2,3].map(f).map(g)` runs `f` three times and then `g` three times. A lazy sequence interleaves them: `f(1), g(1), f(2), g(2), …`. With pure functions you cannot tell the difference. With effects you can. [[entry:javascript-weird]] saves a row inside a `map`, so the lazy order is the program, and its check script shows both orders.

Laziness differs too. Python's `map` and a LINQ `Select` are lazy and run nothing until asked. JavaScript's `Array.prototype.map` is eager and builds the whole result at once. Haskell's `fmap` on a list is lazy again. The type of `map` is the same in all of them. The *evaluation* is not.

- **Use it when:** you want to change every value in a structure and keep the structure, and you want a rule that says when two pipelines are interchangeable.
- **Avoid it when:** the function has effects. Use a loop or an effect-aware operation, and say so, so that the reader knows the order matters.

**Read more:**

- [Functor](https://en.wikipedia.org/wiki/Functor) (Wikipedia)
- [`Array.prototype.map()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/map) (MDN)
