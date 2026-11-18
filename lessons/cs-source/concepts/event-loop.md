---
title: "The event loop and scheduling turns"
chapter: 10
order: 40
---
An **event loop** is a loop that waits for something to happen and then runs the code registered for it, one piece at a time. It exists so that one thread can do many things without blocking: while one piece waits for a file or a timer, another can run. Each pass of the loop runs a callback to its end. That is a **turn**. The next turn starts only when the call stack is empty.

This is why `setImmediate()` is useful in [[entry:javascript-events]]. It does not call the function. It puts the function on the loop's queue, and Node runs it on a later turn, after the stack has unwound and after anything else that was waiting. Compare an `emit()`, which is a call on the *current* stack. The difference is what keeps a million cards from becoming a million nested calls. In [[entry:javascript]] and [[entry:javascript-weird]], the loop is the reason a pulse timer runs *after* the synchronous work is done, and the reason a redirected run exits at once: with no timer registered, the loop has nothing to wait for.

User-interface toolkits run the same kind of loop. The WPF dispatcher (`Application.Run` in [[entry:ModernChallenge1]] and [[entry:LinqChallenge1]]), Tk's `mainloop` in [[entry:PythonChallenge1]] and GLib's `MainLoop` in [[entry:RustChallenge1]] each wait for events and call handlers. In those entries the loop only displays the window. The cards were made before it started.

- **Use it when:** many slow, independent things must share a thread.
- **Avoid it when:** a callback runs for a long time. Nothing else runs on that thread while it does, so one slow turn stalls every other.

**Read more:**

- [Event loop](https://en.wikipedia.org/wiki/Event_loop) (Wikipedia)
- [The event loop](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Event_loop) (MDN)
