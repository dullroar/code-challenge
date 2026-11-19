---
title: "Goto and structured programming"
chapter: 3
order: 20
---
`GOTO` jumps to any other place in the program. In 1966 Böhm and Jacopini proved that you never *need* it: sequence, choice and loops are enough for any computation. In 1968 Edsger Dijkstra wrote the famous letter "Go To Statement Considered Harmful". Structured programming won because you can reason about a block with one way in and one way out. COBOL's `ALTER` goes the opposite way: it changes where a `GO TO` points *while the program runs*. [[entry:cobol-weird]] uses it as its loop. The statement was later removed from the COBOL standard. GnuCOBOL still runs it.

- **Use `goto` when:** in a few honest cases, such as one clean exit for error handling in C, or in generated code and state machines.
- **Avoid it when:** a target computed or changed at run time would make the code hard to read.

**Read more:**

- [Goto](https://en.wikipedia.org/wiki/Goto) (Wikipedia)
- [Structured program theorem](https://en.wikipedia.org/wiki/Structured_program_theorem) (Wikipedia)
- [Considered harmful](https://en.wikipedia.org/wiki/Considered_harmful) (Wikipedia)
