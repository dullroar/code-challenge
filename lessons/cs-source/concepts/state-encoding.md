---
title: "Representing state"
chapter: 2
order: 30
---
Any state must be written down in something. A number can be tally marks (unary), digits (decimal or binary) or even a single huge integer that encodes a whole program (Gödel numbering). The choice of *representation* decides what is easy. Tally marks are easy to rewrite with find-and-replace, but long. In [[entry:regex-sed]] the whole program state is one line of text, and numbers are rows of marks that substitutions grow and shrink. COBOL's `PIC` clauses are also a representation: the picture of a field decides its size, rounding and range.

- **Use it when:** your medium has no numbers or no variables, and you must decide for yourself what "a count" looks like.
- **Avoid unary for large numbers:** one million needs one million marks.

**Read more:**

- [Unary numeral system](https://en.wikipedia.org/wiki/Unary_numeral_system) (Wikipedia)
- [Gödel numbering](https://en.wikipedia.org/wiki/G%C3%B6del_numbering) (Wikipedia)
