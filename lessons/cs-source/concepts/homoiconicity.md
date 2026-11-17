---
title: "Homoiconicity: code as data"
chapter: 6
order: 50
---
A language is *homoiconic* when its programs are written in its own data structures. In Lisp, code is a list, so a macro is just a program that builds a list. Tcl goes a different way, with "everything is a string", and APL treats a function as a character matrix. In Forth the program is a stream of words that the interpreter can read. The idea exists because it makes metaprogramming simple: if code is data, you can inspect it, build it and change it with the tools you already have. [[entry:apl-weird]] reads its own source with `⎕CR`, rewrites it and defines the copy with `⎕FX`.

- **Use it when:** you write macros, code transformers or small languages.
- **Avoid it when:** tools must understand your code without running it. Static analyzers and refactoring tools find it hard to follow code that builds code.

**Read more:**

- [Homoiconicity](https://en.wikipedia.org/wiki/Homoiconicity) (Wikipedia)
- [Lisp (programming language)](https://en.wikipedia.org/wiki/Lisp_(programming_language)) (Wikipedia)
- [Metaprogramming](https://en.wikipedia.org/wiki/Metaprogramming) (Wikipedia)
