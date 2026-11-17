---
title: "Scope and binding"
chapter: 6
order: 40
---
*Scope* is the part of a program where a name can be seen. *Binding* is the link between a name and a value. Most languages use *lexical* scope: a name means what it means where it is written. Some use *dynamic* scope: a name means whatever the most recent caller set. Dynamic scope can be useful, and it can be dangerous. In [[entry:apl-weird]] dynamic scope would let a rewritten function overwrite its parent's variables, so each generated header re-declares its locals. In Tcl, `uplevel` runs code in the scope of another stack frame. [[entry:tcl-weird]] uses `uplevel #0`, which means the global scope. In m4 and Make, every name is global.

- **Use it when:** lexical scope, almost always. It lets you read a function without knowing its callers.
- **Avoid:** dynamic and global scope, except for deliberate, documented settings.

**Read more:**

- [Scope (computer programming)](https://en.wikipedia.org/wiki/Scope_(computer_programming)) (Wikipedia)
- [Name binding](https://en.wikipedia.org/wiki/Name_binding) (Wikipedia)
- [Closure (computer programming)](https://en.wikipedia.org/wiki/Closure_(computer_programming)) (Wikipedia)
- [Scope](https://developer.mozilla.org/en-US/docs/Glossary/Scope) (MDN glossary)
