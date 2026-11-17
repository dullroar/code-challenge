---
title: "Weird machines"
chapter: 5
order: 110
---
"Weird machine" is a term from security research. A program has the machine its authors meant, and it also has *another* machine, made of the same parts, that an attacker can drive with crafted input. In return-oriented programming, for example, an attacker chains small pieces of existing code into a new program. The term exists to explain why "it was only supposed to parse a file" is not a safety argument. Every entry in this repository is a weird machine made on purpose, in a safe place: a regex engine that counts, a parser that loops, a build tool that restarts. Each one asks the lesson's question in reverse: *what can input make this program do?*

- **Use it when:** you review an attack surface, and when you want to understand how a "harmless" feature computes.
- **Avoid building them in production.** If you must, describe the machine in the README, as the entries here do.

**Read more:**

- [Weird machine](https://en.wikipedia.org/wiki/Weird_machine) (Wikipedia)
- [Return-oriented programming](https://en.wikipedia.org/wiki/Return-oriented_programming) (Wikipedia)
- [[langsec]]
