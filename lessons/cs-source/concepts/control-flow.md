---
title: "Control flow"
chapter: 3
order: 10
---
Control flow is the order in which a program's steps run: one after another, a choice between branches, a repetition, a call and a return, or a jump. It exists as a separate idea because "what happens next?" is a different question from "what is the data?". Most languages weld control flow to two things: the *program counter* and the *call stack*. The entries in this repository pull it loose and keep it somewhere else. In COBOL it lives in the target of a `GO TO`. In Forth it lives in the text interpreter's parse position. In Make it lives in which files exist. Seeing it move is the best way to understand that it is a thing you can name.

- **Use it when:** you ask, about any program, "where does 'what runs next' live?"
- **Avoid it when:** the mechanism hides control flow from debugging tools. A debugger shows the call stack. It does not show a rewritten line of text.

**Read more:**

- [Control flow](https://en.wikipedia.org/wiki/Control_flow) (Wikipedia)
- [Control-flow graph](https://en.wikipedia.org/wiki/Control-flow_graph) (Wikipedia)
