---
title: "Category theory"
chapter: 5
order: 120
---
Category theory is the mathematics of **things and the arrows between them**, and of how arrows compose. A **category** has *objects* and *morphisms* (arrows). Each morphism goes from one object to another. Two rules hold:

1. **Identity.** Every object has an arrow to itself that changes nothing: `id`.
2. **Composition.** If `f : A → B` and `g : B → C`, then `g ∘ f : A → C` exists. Composition is associative: `h ∘ (g ∘ f) = (h ∘ g) ∘ f`. And `f ∘ id = f = id ∘ f`.

In programming, the usual category has *types* as objects and *functions* as arrows. The rules then say something you already use: you can chain functions, you can wrap a chain in parentheses wherever you like, and a function that returns its input changes nothing.

```haskell
-- Haskell: composition is a function, and the laws are things you can test.
(show . (+ 1)) 41          -- "42"
(id . show) 42 == show 42   -- True: identity
```

```python
# Python: the same idea. compose(g, f)(x) is g(f(x)).
compose = lambda g, f: lambda x: g(f(x))
assert compose(str, lambda n: n + 1)(41) == "42"
```

Three honest warnings come with the vocabulary:

- **It is a lens, not a label.** You can *describe* many pipelines as arrows between types. That does not make every LINQ operator, every `map` or every `INSERT ... SELECT` a formal part of a category. A claim such as "this is a functor" is a claim with laws, and the laws must hold.
- **Syntax is not structure.** Two operations both called `map` can differ in laziness, in order of effects and in what they do to an empty input. Same name, same shape, different behavior. The laws decide, and the names do not.
- **A round trip is not an isomorphism by default.** An *isomorphism* is a pair of arrows `f` and `g` with `g ∘ f = id` and `f ∘ g = id`. An encoder and a decoder (see [[serialization-deserialization-pickling]]) form one only if both laws hold. Many codecs keep the second law only on some values.

This book uses the ideas where an entry gives them something real to hold. [[entry:haskell]] composes small pure functions. [[entry:LinqChallenge1]] chains query operators. The next pages, [[functor]] and [[monoid-and-fold]], name two of the laws that make such chains safe to rearrange.

- **Use it when:** you want to say precisely what a pipeline preserves, or when two designs look alike and you need to know if they behave alike.
- **Avoid it when:** the vocabulary replaces the explanation. If a plain sentence says the same thing, write the sentence.

**Read more:**

- [Category theory](https://en.wikipedia.org/wiki/Category_theory) (Wikipedia)
- [Category (mathematics)](https://en.wikipedia.org/wiki/Category_(mathematics)) (Wikipedia)
- [Function composition](https://en.wikipedia.org/wiki/Function_composition) (Wikipedia)
- [Isomorphism](https://en.wikipedia.org/wiki/Isomorphism) (Wikipedia)
