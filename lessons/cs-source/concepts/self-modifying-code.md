---
title: "Self-modifying code"
chapter: 3
order: 80
---
Self-modifying code changes its own instructions while it runs. Early computers did it to save scarce memory. Today the idea lives on in just-in-time compilers, in program loaders and in malware that hides itself. In this repository it is a way to move control flow into the program text. [[entry:apl-weird]] reads a function's source with `⎕CR`, rewrites it and defines the new version with `⎕FX`. [[entry:cobol-weird]] changes a `GO TO` with `ALTER`. [[entry:tcl-weird]] keeps procedure source in a database table and defines it on demand.

- **Use it when:** you generate code at a clear boundary: write text, compile it, run it. That is what JIT compilers and code generators do.
- **Avoid it in hand-written programs.** Debuggers, caches and security tools (some systems forbid memory that is both writable and executable) all assume that code does not change.

**Read more:**

- [Self-modifying code](https://en.wikipedia.org/wiki/Self-modifying_code) (Wikipedia)
- [Just-in-time compilation](https://en.wikipedia.org/wiki/Just-in-time_compilation) (Wikipedia)
