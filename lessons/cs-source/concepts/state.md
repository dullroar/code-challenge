---
title: "State"
chapter: 6
order: 10
---
State is whatever a program remembers between steps. Without it, nothing could be computed. The interesting question is *where it lives*: in variables, on a stack, on the heap, in a file, in a database, in an environment variable, over the network. This book's first goal is to ask that question about every program. The answers here are surprising. State lives in the target of a `GO TO`, in one line of text, in which files exist on disk, in the captures of a regex, in the text of functions, in the input stream and in the depth of trigger recursion. See the table in [By goal](../goals.md).

- **Use it when:** make state explicit, small and close to where it is used.
- **Avoid hidden and global state.** It is hard to test, hard to share and hard to reason about.

**Read more:**

- [State (computer science)](https://en.wikipedia.org/wiki/State_(computer_science)) (Wikipedia)
- [File system](https://en.wikipedia.org/wiki/File_system) (Wikipedia), where the Make entry keeps its state
- [Global variable](https://en.wikipedia.org/wiki/Global_variable) (Wikipedia)
