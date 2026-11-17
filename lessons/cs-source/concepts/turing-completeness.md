---
title: "Turing completeness"
chapter: 2
order: 100
---
A system is Turing complete if it can simulate any Turing machine (given unlimited memory). In plain words: it can compute whatever a general-purpose computer can. People enjoy finding this property in surprising places: Make, sed, m4, spreadsheets, even slide software. That is the spirit of this repository. But the property has a price. If a notation is Turing complete, you cannot decide in general what its programs will do (Rice's theorem). That is why security people prefer inputs that are *not* powerful. See [[langsec]]. The web community calls this the *rule of least power*: choose the least powerful language that solves the problem.

- **Use it when:** you want to know the ceiling of a notation, or explain why a "configuration language" can run forever.
- **Avoid it as praise:** "it is Turing complete" is a warning label as often as a compliment.

**Read more:**

- [Turing completeness](https://en.wikipedia.org/wiki/Turing_completeness) (Wikipedia)
- [Rice's theorem](https://en.wikipedia.org/wiki/Rice%27s_theorem) (Wikipedia)
- [Rule of least power](https://en.wikipedia.org/wiki/Rule_of_least_power) (Wikipedia)
