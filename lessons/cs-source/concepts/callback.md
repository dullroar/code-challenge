---
title: "Callbacks"
chapter: 10
order: 20
---
A **callback** is code that you give to someone else, to be called later. The caller decides when, and you decide what. It exists because a library or an engine often knows *when* something happens (a record was written, a match reached a point, a timer expired) and cannot know *what* you want to do about it. Callbacks are how a tool lets you in.

A callback can be called at once, before the function you handed it to returns (a *synchronous* callback), or later, from the event loop (an *asynchronous* one). The first is just a call with an indirection, and it runs on the same call stack. The second needs a queue. [[entry:regex-pcre2]] has the first kind: at every callout, the matching engine calls a C function, waits for its answer (`0` to go on, `1` to fail this branch) and then decides. [[entry:tar-gnu-weird]] hands tar a command to run at every checkpoint. [[entry:tcl-weird]] registers a Tcl command as an SQL function, so a database trigger can call back into the interpreter. In [[entry:javascript]] and [[entry:javascript-weird]] the pulse is a timer callback, and in [[entry:javascript-events]] the listeners are callbacks that call each other through an emitter.

- **Use it when:** a tool knows when and you know what.
- **Avoid it when:** the callbacks nest deeply ("callback hell"), or errors must travel back to the caller. A throw inside a callback goes to whoever *called* it, which may be code that is not waiting.

**Read more:**

- [Callback (computer programming)](https://en.wikipedia.org/wiki/Callback_(computer_programming)) (Wikipedia)
