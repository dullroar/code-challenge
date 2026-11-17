---
title: "Hyrum's law"
chapter: 8
order: 50
---
Hyrum's law says: with enough users of an interface, *every* observable behavior of it will be depended on by somebody, whatever the documentation promises. Hyrum Wright, a software engineer at Google, put the observation into words. It explains the third tag in this book, **accidentally exploited**. GNU Make documents that it restarts after it remakes an included makefile, but it never promised that you could use that as a loop. CMake's `MATCHES` clears every `CMAKE_MATCH` variable after a failed match, and that is observed behavior, not a promise. The entries lean on both. Maintainers know the law too. Go, for example, randomizes the order of map iteration on purpose, so that nobody can rely on it.

- **Use it when:** you change a library (someone depends on the old behavior), and you decide whether to rely on an undocumented one (write it down, and add a test).
- **Avoid:** building on behavior that nobody promised, in code that others must live with.

**Read more:**

- [Hyrum's law](https://en.wikipedia.org/wiki/Hyrum%27s_law) (Wikipedia)
- [Backward compatibility](https://en.wikipedia.org/wiki/Backward_compatibility) (Wikipedia)
