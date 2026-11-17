---
title: "Domain-specific languages"
chapter: 5
order: 70
---
A domain-specific language (DSL) is a small language for one kind of job. SQL is for queries, regular expressions for patterns, Make for builds, AWK for records, LINQ query syntax for collections. It exists because a tool that speaks the vocabulary of the problem is shorter, easier to read and often safer than general code. There is a classic danger. Users ask for variables, then conditions, then loops, and the DSL grows into a general language by accident, with fewer tools and worse error messages. Programmers call this the *inner-platform effect*. Most entries here are DSLs that crossed that line, which is why they were fun to write.

- **Use it when:** the domain has a stable vocabulary and many people use it.
- **Avoid it when:** a library in a normal language does the same job. If your DSL needs loops, think again about embedding it in a general language.

**Read more:**

- [Domain-specific language](https://en.wikipedia.org/wiki/Domain-specific_language) (Wikipedia)
- [Inner-platform effect](https://en.wikipedia.org/wiki/Inner-platform_effect) (Wikipedia)
