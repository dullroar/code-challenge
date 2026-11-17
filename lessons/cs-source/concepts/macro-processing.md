---
title: "Macros and text expansion"
chapter: 5
order: 50
---
A macro is a name that is replaced by text, or by code, *before* the real language sees it. The C preprocessor is the best-known one. m4 is a general macro processor. Lisp macros work on code as data, not as text. They exist to let you build abstractions that functions cannot: repeated boilerplate, new syntax, code generated at compile time. [[entry:m4]] has no loop statement and no variable. It builds a loop from a macro whose replacement text contains itself, so the output is scanned again. [[entry:lisp-weird]] uses a `defcard` macro to write five similar classes and methods, at compile time.

- **Use it when:** you generate repetitive code, or define a small language on top of a bigger one.
- **Avoid it when:** a plain function would do. Macro bugs are hard to debug, and text macros can capture names by accident. Lisp-style *hygienic* macros reduce this danger.

**Read more:**

- [Macro (computer science)](https://en.wikipedia.org/wiki/Macro_(computer_science)) (Wikipedia)
- [M4 (computer language)](https://en.wikipedia.org/wiki/M4_(computer_language)) (Wikipedia)
- [Hygienic macro](https://en.wikipedia.org/wiki/Hygienic_macro) (Wikipedia)
