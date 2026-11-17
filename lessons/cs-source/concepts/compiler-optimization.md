---
title: "Optimizers"
chapter: 8
order: 40
---
An optimizing compiler rewrites your program so that it runs faster or uses less memory, but it must keep the *observable behavior* that the language defines (the "as-if" rule). It exists so that you can write clear code and still get fast code. The leak is that anything the language does not count as observable may disappear. In [[entry:regex-pcre2]] callouts only mean something if the engine visits them, and the optimizer may skip them. So the program compiles the pattern with `PCRE2_NO_AUTO_POSSESS`, `PCRE2_NO_START_OPTIMIZE` and `PCRE2_NO_DOTSTAR_ANCHOR`, and it does not use the JIT, which has no callout support.

- **Use it when:** trust it for pure code, and measure before you hand-optimize.
- **Avoid:** depending on effects that the language does not promise to keep.

**Read more:**

- [Optimizing compiler](https://en.wikipedia.org/wiki/Optimizing_compiler) (Wikipedia)
- [As-if rule](https://en.wikipedia.org/wiki/As-if_rule) (Wikipedia)
- [Dead-code elimination](https://en.wikipedia.org/wiki/Dead-code_elimination) (Wikipedia)
