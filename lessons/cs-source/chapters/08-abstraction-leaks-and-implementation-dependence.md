---
title: "Abstraction leaks and implementation dependence"
---
Every abstraction hides something, and sooner or later the hidden thing shows. This chapter is about those moments. A language standard promises some things, allows others and ignores the rest. An optimizer may skip code that the language says nobody can see. A regex that is fast on every test can take a year on one bad input. A feature that nobody promised can still be the one that everybody uses.

These ideas explain the three tags used in every lesson. **Guaranteed** means the specification promises it. **Implementation-permitted** means one implementation allows it. **Accidentally exploited** means it works, and nobody promised it. The concepts below give you the vocabulary for each: leaky abstractions, undefined and unspecified behavior, portability, optimizers, Hyrum's law, time complexity, ReDoS, and reproducibility (writing down every input so that the same sources give the same result).
