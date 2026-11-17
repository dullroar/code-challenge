---
title: "Language-theoretic security"
chapter: 5
order: 100
---
Language-theoretic security (LangSec) is a way of thinking about security. Every input format is a formal language, and the code that reads it is that language's recognizer. Many attacks work because two parsers read the same bytes differently, or because the input language is so powerful that no one can say what it will do. The advice follows from that: keep formats simple (see [[turing-completeness]]), parse completely *before* acting, and use one well-tested parser. It also criticizes the old "robustness principle", *be liberal in what you accept*, because being liberal creates more meanings for the same bytes. The IETF has revisited that principle too.

- **Use it when:** you design a file format, a protocol or an API, or you review code that reads input.
- **Avoid:** accepting "almost valid" input, and mixing parsing with processing.

**Read more:**

- [Language-theoretic security](https://en.wikipedia.org/wiki/Language-theoretic_security) (Wikipedia)
- [Robustness principle](https://en.wikipedia.org/wiki/Robustness_principle) (Wikipedia)
- [RFC 9413: Maintaining Robust Protocols](https://www.rfc-editor.org/rfc/rfc9413), a modern IETF view of the principle
