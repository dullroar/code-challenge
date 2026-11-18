---
title: "Control flow and continuations"
---
"What runs next?" is one of the two basic questions about any program. (The other is "what does it remember?", in the chapter "State beyond variables".) Most languages answer it with a program counter and a call stack, and most programmers never think about it again. The entries in this book keep control somewhere else, so you can see it clearly.

In COBOL it is the target of a `GO TO` that `ALTER` can change. In Forth it is the parse position `>in`, which the program can move backward. In GNU Make it is the set of files that exist, and the build restarts when a makefile is remade. In XAML it is the order of the elements in the document. Each of these is a *continuation* in disguise: the rest of the computation, stored as something other than a stack frame. This chapter gives you the vocabulary: structured programming, recursion, fixed points, coroutines, continuations and self-modifying code. It ends with two ideas about *when* code runs: event-driven programming, where something else calls your code, and logical clocks, where time is a count of events. The tar entries use both.
