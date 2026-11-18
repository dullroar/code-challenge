---
title: "Dispatch and triggers: the rule fires the next step"
order: 70
---
The rule fires the next step. In [[entry:lisp-weird]] a class hierarchy is the loop: each method calls the next one up the class precedence list, and the `or` method combination stops at the first true value. In [[entry:tcl-weird]] a SQLite trigger inserts the next card, which fires the trigger again, and the loop ends when a `WHERE` clause finds nothing to insert. In both, the repeat is invisible in the code that starts it. [[entry:tar-gnu-weird]] gets its callbacks from GNU tar: every record that tar writes runs one transition of a small state machine, so the archive's layout sets the pace. [[entry:javascript-events]] is the plainest case: ten listeners on one `EventEmitter` are the whole program, and each one emits the event that the next one waits for. The next card is asked for through `setImmediate`, so every card is a new turn of the event loop and the call stack never grows.
