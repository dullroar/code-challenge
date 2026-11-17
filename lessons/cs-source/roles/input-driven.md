---
title: "The input is the loop"
order: 80
---
The input is the loop. AWK reads one record at a time and runs every pattern-action rule on it, so the program does not contain a loop at all. [[entry:awk]] uses the loop in the usual way. [[entry:awk-weird]] sets a regular expression as the record separator, so a stream of random bytes becomes dice, and a single pattern (`t > 40 { exit }`) is the stop rule.
