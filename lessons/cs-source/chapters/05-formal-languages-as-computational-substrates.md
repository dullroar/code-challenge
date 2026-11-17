---
title: "Formal languages as computational substrates"
---
A formal language is a notation with strict rules that a machine can process. The recurring surprise of this repository is that a notation built for *one* job turns out to be a computer. Regular expressions were made to match text, and Perl, PCRE2 and .NET engines turn them into search machines, a stack and a counter. `sed` is a rewriting system. Make and CMake were made to order builds, and they became a restarting loop and a register machine. XAML was made to describe a user interface, and its parser runs methods.

This chapter gives you the theory underneath: the Chomsky hierarchy (how much machine does a notation need?), parsing, rewriting, macros and declarative languages. It ends with two security ideas that explain why this matters outside the book. If an input language is more powerful than its authors realized, then reading the input is the same as running a program. See [language-theoretic security](#language-theoretic-security) and [weird machines](#weird-machines).
