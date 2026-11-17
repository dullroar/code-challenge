---
title: "Dispatch and triggers: the rule fires the next step"
order: 70
---
The rule fires the next step. In [[entry:lisp-weird]] a class hierarchy is the loop: each method calls the next one up the class precedence list, and the `or` method combination stops at the first true value. In [[entry:tcl-weird]] a SQLite trigger inserts the next card, which fires the trigger again, and the loop ends when a `WHERE` clause finds nothing to insert. In both, the repeat is invisible in the code that starts it.
