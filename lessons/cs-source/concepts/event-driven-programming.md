---
title: "Event-driven programming"
chapter: 10
order: 10
---
In **event-driven programming** the program does not decide when its code runs. Something else produces *events*, and the program registers *callbacks* that run when one arrives. The flow of control is inverted: you do not call the framework, it calls you. Graphical interfaces, servers and timers work this way.

[[entry:javascript-events]] is the plainest case in this repo: its ten listeners are the whole program, and each one emits the event that the next one waits for. [[entry:tar-gnu-weird]] is the other plain case. tar writes an archive, and every 512 bytes it calls a command. The command has no loop and no idea how many times it will be called. It moves a state machine one step. Change the archive's layout, and the same program gets a different number of events. [[entry:javascript]] and [[entry:javascript-weird]] show a small, real one: after all the cards are saved, a `setInterval` timer calls a function every 600 milliseconds to pulse the DEMO ONLY line. The calls only happen after the synchronous code has finished, because JavaScript runs on one thread and its **event loop** runs a callback only when nothing else is running. A redirected run starts no timer, so Node has no event to wait for and exits at once.

A window is not enough to make a program event-driven. The WPF, Tk, GLib and Swing entries start a UI loop, but their cards come from a `for` statement, a pipeline or a parser, so they are counterexamples.

- **Use it when:** the work is a reaction to things that arrive: clicks, requests, ticks, files.
- **Avoid it when:** the order matters and the callbacks hide it. A chain of callbacks is hard to read and harder to test.

**Read more:**

- [Event-driven programming](https://en.wikipedia.org/wiki/Event-driven_programming) (Wikipedia)
- [The event loop](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Event_loop) (MDN)
- [Events: EventEmitter](https://nodejs.org/api/events.html) (Node.js documentation)
