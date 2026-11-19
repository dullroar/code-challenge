---
title: "Backtracking"
chapter: 7
order: 60
---
Backtracking is a systematic search. Try a choice, go on, and if you get stuck, undo the choice and try the next one. It exists for problems with many possible answers and some rules to prune them: puzzles, parsing and pattern matching. Perl, PCRE2 and .NET regex engines work this way. The entries in this repository turn it around: *do the work in side effects, then fail on purpose.* The match returns false only after every row has been written. What survives the failure is the whole lesson. Perl's `local` variables are restored, but its `INSERT` and `print` calls cannot be undone. [[entry:regex-dotnet]] cannot play this game at all, because a failed .NET match throws its captures away.

```mermaid
flowchart TB
    accTitle: Backtracking searches by trying one path and retreating to the last open choice when the path fails
    accDescr: A small search tree. From the start there are two choices, A and B. Step 1, the search tries A and goes to A1. Step 2, A1 is a dead end. Step 3, the search backtracks to the start, the last choice with an alternative left, shown as a dotted arrow. Step 4, it tries B and goes to B1. Step 5, B1 succeeds.
    S(["Start: two choices"]) -->|"1. try A"| A["A"]
    A --> A1["2. A1: dead end"]
    A1 -.->|"3. backtrack to the last open choice"| S
    S -->|"4. try B"| B["B"]
    B --> B1(["5. B1: success"])
```

The search remembers the choices that still have untried alternatives. When a path fails, it goes back to the most recent one. Here that is the start, where `B` is still open. Undoing a choice undoes the search's own state, not the outside world. As the paragraph above says, a row written along a failed path stays written.

- **Use it when:** the search space is small, or you can prune it early.
- **Avoid it when:** effects cannot be undone, or when the input comes from an attacker (see [[redos]]).

**Read more:**

- [Backtracking](https://en.wikipedia.org/wiki/Backtracking) (Wikipedia)
- [Regular expression](https://en.wikipedia.org/wiki/Regular_expression) (Wikipedia)
