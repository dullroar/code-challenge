---
title: "Arbitrary code execution"
chapter: 1
order: 20
---
Arbitrary code execution means that an attacker makes a program run instructions its author never intended. It is usually an accident: a buffer overflow, an injected string, a file format that is more powerful than anyone noticed. It matters here because many entries in this repository do the same thing *on purpose, in a safe place*. XAML's `ObjectDataProvider` calls methods while the file is parsed. Perl's `(?{ ... })` runs code in the middle of a match. Tcl's `unknown` hook runs code that is stored in a database row. The mechanism is always the same: **data is read as code**.

- **Use this idea when:** you review any feature that "evaluates" something: `eval`, templates, deserializers, macro expanders, plugin loaders.
- **Avoid the technique when:** the input comes from someone you do not trust. If you need extension points, offer a small, declared interface (a plugin API, or a tiny expression language) instead of a general `eval`.

**Read more:**

- [Arbitrary code execution](https://en.wikipedia.org/wiki/Arbitrary_code_execution) (Wikipedia)
- [Code injection](https://en.wikipedia.org/wiki/Code_injection) (Wikipedia)
- [Code injection](https://owasp.org/www-community/attacks/Code_Injection) (OWASP), with examples and defenses
- [`eval()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/eval) (MDN), whose page opens its warning with "Never use direct eval()!"
