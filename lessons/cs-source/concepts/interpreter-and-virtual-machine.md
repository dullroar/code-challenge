---
title: "Interpreters and virtual machines"
chapter: 5
order: 130
---
An **interpreter** reads a program as data and does what it says, step by step. A **virtual machine** is an interpreter for a small, fixed instruction set. Both are the same trick: a *representation* (text, records, bytes) plus a *program that gives it behavior*. Take the interpreter away and the representation is only data.

Several entries are interpreters in small. In [[entry:tar-gnu]] the program is the members of a tar archive, and a dispatcher of about 80 lines gives four record types their meaning. It checks every record against a strict grammar and refuses an unknown one. In [[entry:tcl-weird]] Tcl source is stored in SQLite rows, and an overridden `unknown` command fetches and runs it. In [[entry:xaml]] the parser that loads a document is the interpreter that runs it. In [[entry:regex-pcre2]] callout strings are opcodes, and a bodiless C function is the dispatcher. In [[entry:ex-weird]] Ex is the interpreter and a register of text is the program, which the program rewrites and runs again. The question to ask of each is the same: what is the representation, what is the interpreter and who chose to run the one with the other?

- **Use it when:** a program is easier to change as data than as code, or you want a small, safe language for others to write in.
- **Avoid it when:** the data comes from someone you do not trust and the interpreter is general. A strict grammar and a fixed set of instructions are what keep a data format from becoming a way in.

**Read more:**

- [Interpreter (computing)](https://en.wikipedia.org/wiki/Interpreter_(computing)) (Wikipedia)
- [Virtual machine](https://en.wikipedia.org/wiki/Virtual_machine) (Wikipedia)
