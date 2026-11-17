---
title: "Monads and effect systems"
chapter: 7
order: 20
---
Pure functional languages have a neat answer to side effects: describe the effect as a *value*, and let the runtime perform it. In Haskell an `IO` action is such a value. A **monad** is the pattern that chains these actions in order ("do this, then use its result to decide the next thing"). An *effect system* goes further and records the possible effects in the type. The idea exists so that you can still test and reason about the pure parts. [[entry:haskell-weird]] breaks the pattern on purpose. `unsafeInterleaveIO` lets *reading* a list element perform input and output, which is exactly what the type system tries to prevent. The program stays correct only because card *n* cannot be read before card *n−1*.

- **Use it when:** in Haskell, or any language where effects are tracked, you want them visible in signatures.
- **Avoid `unsafePerformIO` and `unsafeInterleaveIO`** except deep inside a library, with a comment that explains why it is safe.

**Read more:**

- [Monad (functional programming)](https://en.wikipedia.org/wiki/Monad_(functional_programming)) (Wikipedia)
- [Effect system](https://en.wikipedia.org/wiki/Effect_system) (Wikipedia)
- [Haskell](https://en.wikipedia.org/wiki/Haskell) (Wikipedia)
