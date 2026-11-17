---
title: "Evaluation and demand"
---
Is a value computed when you write it, when you first need it, or each time you ask? That is the question of **evaluation strategy**, and the same-looking code answers it differently in different languages.

Haskell is lazy: one `span` over an infinite list is the stop rule, because only the needed part is ever computed. LINQ is deferred: a pipeline does nothing until someone enumerates it. APL is eager and works on whole arrays at once, so it draws more numbers than it needs and trims the result. When effects are involved, the choice stops being a detail. If a lazy list performs input and output, then *reading the list* is what does the work. This chapter explains the vocabulary, and the table at the end shows every entry's strategy in one place.

{{table:evaluation}}
