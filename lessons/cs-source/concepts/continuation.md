---
title: "Continuations"
chapter: 3
order: 70
---
A continuation is "the rest of the computation" from some point, treated as a value. If you could pause a program and ask "what will you do next?", the answer is the continuation. In *continuation-passing style* every function takes an extra argument, a function that says what to do with the result. It exists because early exit, exceptions, generators, backtracking and `async`/`await` can all be written as ordinary function calls once "what next?" is a value. The entries here choose "what next?" on purpose. COBOL's `ALTER` rewrites it. Forth's `>in` rewinds it. Make's restart is "the rest of the build, again".

- **Use it when:** you write a compiler, an async library or a web framework with callbacks.
- **Avoid it when:** you write by hand in a language without tail calls. The code becomes callbacks inside callbacks, and the stack grows.

**Read more:**

- [Continuation](https://en.wikipedia.org/wiki/Continuation) (Wikipedia)
- [Continuation-passing style](https://en.wikipedia.org/wiki/Continuation-passing_style) (Wikipedia)
- [Call-with-current-continuation](https://en.wikipedia.org/wiki/Call-with-current-continuation) (Wikipedia)
