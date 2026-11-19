---
title: "Effects, errors and commitment"
---
For an advanced reading path with traces and experiments, see the [effects, errors and commitment study guide](../study-guides/concepts/effects-errors-and-commitment.md).

A program that does nothing outside itself is a very expensive heater. Useful programs change the world: they write files, print and insert rows. This chapter is about the three questions that follow. When does an effect happen (**side effects**)? What happens when something goes wrong (**errors**)? And at what point is a change final (**commitment**)?

The entries here play with all three. A regex engine runs the whole demo and then *fails on purpose*, so what survives the failure becomes the lesson. A constraint violation, an arithmetic overflow or a program's exit code *is* the stop rule. A database transaction commits only when the work is complete. The concepts below give each of these a name and a reason: side effects, effect systems, exceptions, exit status, constraints, backtracking, the cut, transactions, idempotence and thread safety.
