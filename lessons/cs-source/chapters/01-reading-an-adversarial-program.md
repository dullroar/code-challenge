---
title: "How to read an adversarial program"
---
For an advanced reading path with traces and experiments, see the [reading adversarial programs study guide](../study-guides/concepts/reading-adversarial-programs.md).

The programs in this book are *adversarial* on purpose. They do things that code should not do: run code inside a regex match, call methods while parsing a markup file, rewrite their own jump targets. They are safe to study because of how this repository handles them. Every entry writes fictional **DEMO ONLY** data, runs in a [sandbox](../../SANDBOX-SETUP.md), and is reviewed as untrusted code until someone has read and understood it.

This chapter is the reader's safety model. It has two habits. First, **read the weird program next to its ordinary sibling**: [`cobol`](../../src/cobol/README.md) beside [`cobol-weird`](../../src/cobol-weird/README.md), [`haskell`](../../src/haskell/README.md) beside [`haskell-weird`](../../src/haskell-weird/README.md). The difference shows you exactly what the stunt costs. Second, **ask what kind of promise stands behind each trick**: guaranteed, implementation-permitted or accidentally exploited (see the [intro](../intro.md#three-kinds-of-knowledge)). The topics below are the security and review ideas that make those habits work. They include one that the tar entries bring out: authority comes from the command that runs a program, not from the data it reads ([[capability-security]]).
