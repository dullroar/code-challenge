---
title: "Backpressure"
chapter: 10
order: 50
---
**Backpressure** is how a slow consumer tells a fast producer to wait. An event source announces things at its own speed. If the consumer cannot keep up, either a queue grows without a limit until memory runs out, or events are dropped. Backpressure turns that into a conversation: a bounded buffer, a stream that pauses its source or a *pull*, where the consumer asks for one value when it is ready.

A pull is the simplest backpressure, and [[entry:javascript-weird]] is one: it cannot be flooded, because nothing is drawn until something asks. [[entry:javascript-events]] has no backpressure and does not need it: each card waits for the previous card, so producer and consumer are one program. [[entry:tar-gnu-weird]] shows the missing half. tar keeps writing records, and so keeps calling the clock, after the machine is done. Those ticks only count as idle, because there is no way to ask tar to stop.

- **Use it when:** the producer's speed is not under your control.
- **Avoid it when:** the producer and consumer are one sequential program. A plain loop is enough.

**Read more:**

- [Back pressure](https://en.wikipedia.org/wiki/Back_pressure) (Wikipedia)
