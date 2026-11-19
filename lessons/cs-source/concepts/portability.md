---
title: "Portability"
chapter: 8
order: 30
---
Software is portable if it runs correctly in more than one environment: another operating system, another implementation of the same language, another version. It exists as a goal because your users do not all have your machine. The usual tools are a written standard, a thin layer over the differences and tests on more than one platform. The entries here have honest examples. The POSIX AWK subset runs everywhere, but a regular expression as the record separator is a gawk extension. On mawk, [[entry:awk-weird]] reads forever. `close()` returns different values in different awks. The `pcre2grep` in Ubuntu is built without callout scripts.

- **Use it when:** you write for users you do not control. Pick a standard and test on at least two implementations.
- **Avoid it as dogma:** when a stunt needs one implementation, name it, pin its version and say so in the README.

**Read more:**

- [Software portability](https://en.wikipedia.org/wiki/Software_portability) (Wikipedia)
- [POSIX](https://en.wikipedia.org/wiki/POSIX) (Wikipedia)
