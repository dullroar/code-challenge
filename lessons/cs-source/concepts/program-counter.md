---
title: "The program counter"
chapter: 3
order: 30
---
The program counter is a register that holds the address of the next instruction. After each step it moves forward by one, unless a jump sets it somewhere else. It exists because a machine needs to know "where am I?". Every interpreter has one, even if it has a different name. In [[entry:forth-weird]] the role is played by `>in`, the position of the text interpreter in the current line. The program *moves `>in` backward* to repeat itself. In [[entry:cobol-weird]] it is the destination of one `GO TO`.

- **Use this idea when:** you debug, or write an interpreter, a debugger or a virtual machine. These are the cases where reaching for the "where am I" value is legitimate.
- **Avoid:** letting ordinary application code touch it.

**Read more:**

- [Program counter](https://en.wikipedia.org/wiki/Program_counter) (Wikipedia)
- [Interpreter (computing)](https://en.wikipedia.org/wiki/Interpreter_(computing)) (Wikipedia)
