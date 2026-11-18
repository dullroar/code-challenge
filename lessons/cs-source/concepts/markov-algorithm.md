---
title: "Markov algorithms"
chapter: 2
order: 90
---
A Markov algorithm is a list of find-and-replace rules, in order. Look for the first rule whose pattern appears in the text, replace it, and start again from the top. Stop when no rule applies (or when a rule says "stop"). The Russian mathematician Andrey Markov Jr. described it in the 1950s, and it can compute anything a Turing machine can. It exists to show that *rewriting text is computing*. [[entry:regex-sed]] is exactly this: one line of text, and a script of substitutions that rewrite it until nothing matches. The line is the whole memory.

```mermaid
flowchart TB
    accTitle: A Markov algorithm applies the first rule that matches, again and again, until a terminal rule or no match
    accDescr: An ordered rule list is shown above a trace. Rule 1 turns AA into A. Rule 2 turns BA into AB. Rule 3 turns B into B and stops. The text BAA matches both rule 1 and rule 2, but rule 1 comes first, so it wins and the text becomes BA. Now only rule 2 matches, and the text becomes AB. Rules 1 and 2 no longer match, rule 3 matches and is terminal, so the algorithm halts with AB.
    subgraph RULES["Rules, always tried from the top"]
        direction TB
        R1["1: AA becomes A"] ~~~ R2["2: BA becomes AB"] ~~~ R3["3: B becomes B, then stop"]
    end
    S0["Text: BAA (rules 1 and 2 both match)"] -->|"rule 1 comes first"| S1["Text: BA"]
    S1 -->|"rule 2"| S2["Text: AB"]
    S2 -->|"rule 3: terminal"| H(["Halt with AB"])
    RULES ~~~ S0
```

The order of the rules decides, not the place in the text. `BAA` matches rules 1 and 2, and rule 1 wins because it is first. After each rewrite the search for a rule starts again at rule 1. The run ends when a terminal rule applies (rule 3 here) or when no rule matches. Other rewriting systems, such as those in [[term-rewriting]], do not all pick rules this way.

- **Use it when:** you transform or normalize text, or when you want to teach that a program can be "just rules".
- **Avoid it for large programs:** rule order *is* the control flow, which is hard to reason about, and speed is hard to predict.

**Read more:**

- [Markov algorithm](https://en.wikipedia.org/wiki/Markov_algorithm) (Wikipedia)
- [[term-rewriting]] in "Formal languages as computational substrates"
