---
title: "Reflection and metaprogramming"
chapter: 6
order: 60
---
*Reflection* means a program inspects or changes its own structure while it runs: it finds a type by name, lists methods, calls one. *Metaprogramming* means a program writes or transforms programs. They exist because frameworks need them: serializers, test runners, dependency injection and plugin systems all find code they have never seen. XAML works by reflection: a type name in the markup becomes an object. Common Lisp's metaobject protocol lets [[entry:lisp-weird]] ask which methods apply to a call. The cost is that tools and optimizers cannot see through it, and a name that comes from data can become an attack.

- **Use it when:** at the boundaries of a framework, where code must be found by name.
- **Avoid it in business logic.** If names come from outside, accept only an explicit list.

**Read more:**

- [Reflective programming](https://en.wikipedia.org/wiki/Reflective_programming) (Wikipedia)
- [Metaprogramming](https://en.wikipedia.org/wiki/Metaprogramming) (Wikipedia)
- [Metaobject](https://en.wikipedia.org/wiki/Metaobject) (Wikipedia)
