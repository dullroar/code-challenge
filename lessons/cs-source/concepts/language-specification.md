---
title: "Specification versus implementation"
chapter: 1
order: 70
---
A language specification says what programs *mean*. An implementation is one particular program that tries to follow it. The two can differ, and the difference is where this book lives. Each lesson tags a trick as **guaranteed** (the specification promises it), **implementation-permitted** (one compiler or platform allows it) or **accidentally exploited** (it works today, and nobody promised it). The IETF gave engineers a useful vocabulary for the same idea: MUST, SHOULD and MAY, defined in RFC 2119. A specification that uses those words carefully tells you exactly how much you can lean on it.

- **Use it when:** before you rely on any behavior, ask which of the three kinds of promise stands behind it.
- **Avoid it when:** you need performance evidence. A run on one machine establishes only what happened there.

**Read more:**

- [Programming language specification](https://en.wikipedia.org/wiki/Programming_language_specification) (Wikipedia)
- [RFC 2119: key words for use in RFCs](https://www.rfc-editor.org/rfc/rfc2119), two pages that fix the meaning of MUST, SHOULD and MAY
- [[undefined-behavior]] and [[hyrums-law]] in "Abstraction leaks and implementation dependence"
