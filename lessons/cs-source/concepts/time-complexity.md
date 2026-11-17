---
title: "Performance cliffs and time complexity"
chapter: 8
order: 60
---
Time complexity describes how running time grows with the size of the input: linear (n), quadratic (n²), exponential (2ⁿ). It exists because small tests hide big problems. A function that takes a millisecond for ten items may take a year for sixty. In this repository the cliff is used on purpose. [[entry:regex-sed]] has a catastrophic-backtracking regex, tuned to take about 50 milliseconds per frame, as a *clock*. That is a nice trick in a demo, and a fine example of why you cannot use speed as a timer in real software: another machine, another version, another answer.

- **Use it when:** before you ship code that handles large or hostile input, ask what the worst case is.
- **Avoid:** using performance as a clock, or as a promise.

**Read more:**

- [Time complexity](https://en.wikipedia.org/wiki/Time_complexity) (Wikipedia)
- [Big O notation](https://en.wikipedia.org/wiki/Big_O_notation) (Wikipedia)
- [Computational complexity theory](https://en.wikipedia.org/wiki/Computational_complexity_theory) (Wikipedia)
