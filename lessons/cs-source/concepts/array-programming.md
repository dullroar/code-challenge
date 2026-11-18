---
title: "Array programming"
chapter: 4
order: 80
---
Array programming applies an operation to a whole array at once. Scalars stretch to match, and explicit loops mostly disappear. Kenneth Iverson invented APL for this in the 1960s, and the idea lives on in J, K, R, MATLAB and NumPy. It exists because it makes the code short and because hardware can do many elements at the same time (SIMD, GPUs). [[entry:apl]] shows the style: five random draws, a running sum `+\` and a take-while replace the loop. You describe the full answer, then trim it.

```mermaid
flowchart TB
    accTitle: Array programming describes bulk transformations on whole vectors, often replacing explicit control flow
    accDescr: A pipeline of whole arrays with no loop. The hours array is 19, 16, 19, 11. A running sum gives the totals 19, 35, 54, 65. Comparing every total with 40 gives the flags 1, 1, 0, 0. Summing the flags gives 2, and adding 1 gives 3 cards to keep. Taking 3 items from the hours gives 19, 16, 19.
    H["hours: 19 16 19 11"] -->|"running sum"| T["totals: 19 35 54 65"]
    T -->|"compare every total with 40"| F["at most 40: 1 1 0 0"]
    F -->|"sum the flags, add 1"| N["cards to keep: 3"]
    N -->|"take 3 from hours"| K["kept: 19 16 19"]
```

Read the picture from top to bottom. Each step is one operation on a whole array, and no step is a loop. The comparison gives a flag for every total at once. The number of flags that are 1, plus one, is the number of cards to keep, because the card that crosses 40 is kept too. [[entry:apl]] works this way. The numbers here are only an example, and the idea does not depend on APL's symbols.

- **Use it when:** you work with numbers, tables and signals.
- **Avoid it when:** the algorithm is inherently one step after another, or the intermediate arrays are too big for memory. Also remember that a dense notation is hard for a team that does not read it.

**Read more:**

- [Array programming](https://en.wikipedia.org/wiki/Array_programming) (Wikipedia)
- [APL (programming language)](https://en.wikipedia.org/wiki/APL_(programming_language)) (Wikipedia)
- [Kenneth E. Iverson](https://en.wikipedia.org/wiki/Kenneth_E._Iverson) (Wikipedia)
- [Single instruction, multiple data](https://en.wikipedia.org/wiki/Single_instruction,_multiple_data) (Wikipedia)
