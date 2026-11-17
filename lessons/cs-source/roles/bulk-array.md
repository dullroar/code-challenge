---
title: "Whole-array operations instead of steps"
order: 30
---
Do it to all of them at once, then cut. [[entry:apl]] draws five random values (a bound that can never be too small), takes a running sum, and keeps the prefix whose total does not pass 40, plus the card that does. There is no loop and no counter. The cost is that the program computes more than it needs, and the reader needs to think in arrays.
