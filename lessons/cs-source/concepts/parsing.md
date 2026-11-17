---
title: "Parsing"
chapter: 5
order: 30
---
Parsing turns text into structure, following a grammar. It exists because programs and data arrive as flat text, and the computer needs a tree. There are hand-written *recursive descent* parsers and generated ones. Every XML, JSON or programming-language tool has one. JSON is a good example of a format whose grammar is written down exactly (RFC 8259). Parsing is also where input becomes dangerous, because it is the first code that touches untrusted data. Two entries show a parser that does more than read. [[entry:forth-weird]]'s text interpreter parses a word and runs it at once, so the program can move its own parse position. [[entry:xaml]]'s parser builds objects *and calls methods* while it reads the file.

- **Use it when:** you accept any structured input. Use a real parser and a real grammar.
- **Avoid:** ad hoc parsing with `split` and regular expressions for nested formats, and parsers that also act on what they read.

**Read more:**

- [Parsing](https://en.wikipedia.org/wiki/Parsing) (Wikipedia)
- [Recursive descent parser](https://en.wikipedia.org/wiki/Recursive_descent_parser) (Wikipedia)
- [RFC 8259: the JSON format](https://www.rfc-editor.org/rfc/rfc8259), a small, precise grammar
