---
title: "What counts as a machine?"
---
Before you can say that a regex engine, a build tool or a markup file "computes", you need to say what a machine is. The answer is smaller than you might think. A machine has a **state**, a set of allowed **steps**, a way to **represent** its values, and some facts that stay true while it runs (**invariants**). If you can say what those four are, you have named the machine.

The first goal of this book is exactly that habit: *name the machine hiding inside the language*. A stack machine, a register machine and a rewriting system can all compute the same things, but they keep their memory in different places. The concepts here are the vocabulary for that: transition systems, Turing machines, Markov algorithms and Turing completeness. The chapter "State beyond variables" then returns to the question that matters most for this repository: where does the state live?
