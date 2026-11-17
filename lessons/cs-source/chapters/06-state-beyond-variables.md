---
title: "State beyond variables"
---
If a language has no variables, or if you may not use them, where can a program keep what it remembers? This chapter collects the answers. A stack of marks. A line of text that substitutions rewrite. Which files exist on disk. The captures that a regex leaves behind. The source text of functions. A temporary table of procedures. The depth of a trigger's recursion. A pile of `x` characters.

None of these looks like "state" in the way that a variable does, and every one of them is. The concepts below are the places where it can hide: the call stack, the stack as a data structure, scope and binding, code as data, reflection, dependency graphs and database triggers. The first concept is state itself, and the lesson is a habit: for every program, ask *where does it live?* You will find a table of the entries' answers in [By overall goals](../goals.md).
