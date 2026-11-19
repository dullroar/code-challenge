---
title: "The Chomsky hierarchy"
chapter: 5
order: 10
---
In 1956 Noam Chomsky sorted formal languages into four classes by power: regular, context-free, context-sensitive and unrestricted. Each class needs a stronger machine to recognize it: a finite automaton, a pushdown automaton (a finite machine plus a stack), a bounded Turing machine and a full Turing machine. It exists to answer a practical question: *how much machine does this notation need?* A regular expression, in the classic sense, cannot check that brackets are balanced, because that needs a stack. Real regex engines go beyond the classic class. .NET's balancing groups in [[entry:regex-dotnet]] give the engine a stack of captures, and that is exactly the extra power.

- **Use it when:** you choose a parsing tool, or you wonder whether a pattern can do the job.
- **Avoid it when:** you need to parse nested formats such as HTML with a plain regular expression.

**Read more:**

- [Chomsky hierarchy](https://en.wikipedia.org/wiki/Chomsky_hierarchy) (Wikipedia)
- [Formal language](https://en.wikipedia.org/wiki/Formal_language) (Wikipedia)
- [Pushdown automaton](https://en.wikipedia.org/wiki/Pushdown_automaton) (Wikipedia)
