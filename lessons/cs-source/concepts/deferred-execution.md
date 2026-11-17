---
title: "Deferred execution"
chapter: 4
order: 50
---
Deferred execution means that you describe a query or a pipeline now, and it runs later, when someone asks for the results. In C#'s LINQ, `Where` and `Select` do no work by themselves. The work happens when a `foreach`, `ToList` or `Aggregate` reads the sequence. It exists so that pipelines can be composed cheaply, and so that a provider (such as Entity Framework) can translate the whole query into SQL. The surprises are real. The query runs *again* each time it is read, effects inside it happen late, and a variable captured by the query may have changed by then. [[entry:LinqChallenge1]] and [[entry:LinqChallenge2]] put effects inside the pipeline on purpose, and a final eager operator forces them.

- **Use it when:** you build queries and transformations that are free of effects.
- **Avoid it when:** a stage has side effects. Decide who forces the pipeline, and when.

**Read more:**

- [Language Integrated Query](https://en.wikipedia.org/wiki/Language_Integrated_Query) (Wikipedia)
- [Lazy evaluation](https://en.wikipedia.org/wiki/Lazy_evaluation) (Wikipedia)
- [Iterator](https://en.wikipedia.org/wiki/Iterator) (Wikipedia)
