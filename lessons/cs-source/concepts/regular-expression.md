---
title: "Regular expressions"
chapter: 5
order: 20
---
A regular expression is a compact pattern for a set of strings. Stephen Kleene described the idea in the 1950s. Ken Thompson put it into text editors, and from there it reached `grep`, `sed`, `awk` and every modern language. It exists because searching text is one of the most common jobs there is. Modern "regex" engines add features such as backreferences, lookaround and code callouts. Most of them work by *backtracking*: they try a path, and if it fails they go back and try another. That design makes the engine powerful, and it makes some patterns very slow. This repository uses five engines as five different computers. See [the regular-expression lesson](../languages/regex.md).

- **Use it when:** you tokenize, validate a simple format or search logs.
- **Avoid it when:** the data is nested, or when an attacker chooses the input and the engine backtracks (see [[redos]]).

**Read more:**

- [Regular expression](https://en.wikipedia.org/wiki/Regular_expression) (Wikipedia)
- [Thompson's construction](https://en.wikipedia.org/wiki/Thompson%27s_construction) (Wikipedia)
- [Kleene star](https://en.wikipedia.org/wiki/Kleene_star) (Wikipedia)
- [Regular expressions](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_expressions) (MDN), a practical guide to the notation
