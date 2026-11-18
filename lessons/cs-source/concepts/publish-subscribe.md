---
title: "Publish and subscribe"
chapter: 10
order: 30
---
In **publish and subscribe**, a *producer* announces that something happened, and any number of *consumers* that registered an interest are called. The producer does not know who they are, and the consumers do not know who produced the event. That is the whole point: the two sides can change independently. Message queues, browser events, and Node's `EventEmitter` all follow this shape.

The idea has two halves that are easy to confuse. *Who is called* is decided by registration (the table of listeners). *When they are called* is decided by the mechanism: an `EventEmitter` calls them at once and in order, and a message broker may deliver them later and somewhere else. [[entry:javascript-events]] uses an emitter in the plainest way, with one listener per event, and its README says honestly that with exactly one listener the indirection buys nothing. A SQLite trigger in [[entry:tcl-weird]] is a subscription to "a row was inserted". The checkpoint action in [[entry:tar-gnu-weird]] is a subscription with one subscriber.

- **Use it when:** more than one party may care, or the sender must not know who.
- **Avoid it when:** there is one receiver. A function call is shorter, and a debugger can step through it.

**Read more:**

- [Publish-subscribe pattern](https://en.wikipedia.org/wiki/Publish%E2%80%93subscribe_pattern) (Wikipedia)
- [Events: EventEmitter](https://nodejs.org/api/events.html) (Node.js documentation)
