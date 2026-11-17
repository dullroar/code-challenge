---
title: "Term and string rewriting"
chapter: 5
order: 40
---
Rewriting means replacing parts of a structure according to rules, again and again, until no rule applies. A *term* is a tree, such as an arithmetic expression. A *string* is the special case where the structure is a line of text. It exists because many kinds of computation are really simplification: algebra, the lambda calculus, an optimizing compiler, a spell-fixing text filter. Two properties matter. Does it always stop (*termination*)? Does every order of rewriting give the same answer (*confluence*)? In this repository [[entry:regex-sed]] and [[entry:m4]] are rewriting systems, and the answer is simply the text that is left.

- **Use it when:** you simplify, normalize or translate structures with clear rules.
- **Avoid it when:** rule order matters but is not written down, or when termination is not obvious.

**Read more:**

- [Rewriting](https://en.wikipedia.org/wiki/Rewriting) (Wikipedia)
- [Confluence (abstract rewriting)](https://en.wikipedia.org/wiki/Confluence_(abstract_rewriting)) (Wikipedia)
- [[markov-algorithm]] in "What counts as a machine?"
