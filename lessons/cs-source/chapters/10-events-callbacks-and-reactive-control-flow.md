---
title: "Events, callbacks and reactive control flow"
---
Every entry in this book answers one question: **who chooses what runs next?** In a `for` loop, the loop chooses. In a lazy pipeline, whoever asks for the next value chooses. In this chapter, something else chooses: an *event*. A program registers small functions, and something else calls them when something happens. The program does not say when.

That sounds like a window with buttons, but it is a general way to build control flow, and this book has it in small, honest forms. [[entry:javascript-events]] is built from nothing else: ten listeners on one emitter, and no loop statement. The other chapters show how code is chosen by a counter, a demand or a rewrite. This one shows what changes when a *notification* does the choosing.

## Who chooses what runs next?

Three answers appear in the entries for the same job (draw cards until the total passes 40):

- **The program chooses** (a loop). `while (total <= 40) { ... }`. The program asks itself the question before every card. [[entry:javascript]] and [[entry:cobol]] work this way.
- **The consumer chooses** (a pull). Nothing happens until someone asks for the next value. [[entry:javascript-weird]] and [[entry:haskell]] work this way. The asking is the loop.
- **The producer chooses** (a push). Something announces "this happened", and every function that registered for it runs. [[entry:javascript-events]] works this way, and so does [[entry:tar-gnu-weird]]: tar announces "one more record written", and a state machine takes one step.

The two ways to know that something happened are **polling** and **notification**. Polling is a loop that asks "is it there yet?" again and again. Notification is a registration: "call me when it is there". Polling costs time while nothing happens. Notification costs *structure*: the order of the program is now spread over the places where things are registered and announced.

## Three ways to run the same cards

| | A loop | A synchronous emitter | Scheduled events |
|---|---|---|---|
| Example | [[entry:javascript]] | The same listeners, with `emit('generate')` in place of `later('generate')` | [[entry:javascript-events]] |
| Who starts the next card | The `for` statement | The last listener, by calling `emit` | The last listener, by asking the event loop |
| The call stack between two cards | Empty | **Grows** by a few frames for every card | Empty |
| A run of a million cards | Fine | `RangeError: Maximum call stack size exceeded` | Fine |
| A listener that throws | Not applicable | The exception goes to the caller of `emit`, up through every card before it | The exception goes to the scheduled callback, so each listener catches its own |
| Who else can run between two cards | Nobody | Nobody | Anything on the event loop: timers, I/O, other listeners |

The middle column is the trap. It *looks* like events, and it behaves like a recursion. In Node, `EventEmitter.emit()` calls every listener of the event, in the order they were registered, **before it returns**. A listener that emits again makes the stack deeper. The event loop is not involved at all. Only a call to something like `setImmediate()` hands the next step to the event loop, and then the stack unwinds first.

## A trace you can read

One run of [[entry:javascript-events]] with three cards of 19 hours, with `>name` where an `emit` starts and `<name` where it returns:

```text
>start <start                              <- turn 1: asks for the first card, returns
>generate >card-created >card-saved >total-updated
<total-updated <card-saved <card-created <generate     <- turn 2: card 1, then the stack is empty
>generate >card-created >card-saved >total-updated
<total-updated <card-saved <card-created <generate     <- turn 3: card 2
>generate >card-created >card-saved >total-updated >finished >done
<done <finished <total-updated <card-saved <card-created <generate   <- turn 4: card 3 (57 hours)
```

The nesting is the call stack. Inside one turn the events are *calls*: `card-created` runs inside `generate`, and `generate` cannot return until it has. Between turns the stack is empty, and the event loop is back in charge. The picture:

```mermaid
sequenceDiagram
    accTitle: One turn of scheduled events: emit nests, the event loop separates turns
    accDescr: A sequence diagram. The event loop starts a turn by calling the generate listener. That listener emits card-created, so the emitter calls the card-created listener inside it. That listener emits card-saved, so the emitter calls the card-saved listener inside it. Each listener then returns, in the reverse order, so the stack unwinds. The last listener has asked the event loop for the next turn with setImmediate. The event loop starts the next turn only after the stack is empty.
    participant L as Event loop
    participant G as generate listener
    participant C as card-created listener
    participant S as card-saved listener
    L->>G: a turn begins
    G->>C: emit card-created: the call is nested
    C->>S: emit card-saved: nested again
    S-->>L: setImmediate asks for the next turn
    S-->>C: returns
    C-->>G: returns
    G-->>L: returns: the stack is empty
    Note over L: the next turn begins only now
```

## Node's rules that matter here

The sources are the Node.js [`events` documentation](https://nodejs.org/api/events.html) and its guide to the [event loop, timers and `process.nextTick()`](https://nodejs.org/en/learn/asynchronous-work/event-loop-timers-and-nexttick).

- **`emit()` is synchronous.** Listeners run in registration order, before `emit` returns. This is documented, so it is a promise and not an accident.
- **The name `error` is special.** `emit('error', e)` with no listener *throws* `e`. Every other name with no listener does nothing.
- **A copy of the listener list is made for each `emit`.** A listener that removes listeners (or adds some) changes the *next* emit, not the one in flight.
- **Timers, immediates and microtasks have an order**, and it is not the order you might guess. After the current code finishes, Node runs `process.nextTick` callbacks, then promise callbacks (microtasks), and then goes round the event loop: expired timers, then I/O callbacks, then `setImmediate` callbacks, and so on. When `setTimeout(fn, 0)` and `setImmediate(fn)` are called from the main module, which runs first is *not promised*: it depends on how fast the process started. Inside an I/O callback, `setImmediate` always runs first. This is implementation-dependent behavior of the kind that [[hyrums-law]] describes, so [[entry:javascript-events]] uses `setImmediate` alone and never depends on the order between two of them.
- **An `async` listener's failure is not caught by a `try` around `emit`.** The listener returns a promise, and `emit` has already returned. The option `captureRejections` turns such a rejection into an `error` event.
- **Listeners need an owner.** A listener that nobody removes can keep a whole object alive. Node warns when one event has more than ten listeners, because that is usually a leak. A timer or an immediate left behind can keep the process from ending. [[entry:javascript-events]] ends by removing every listener, and its lab checks that no timer or immediate is left.

## State machines, re-entrancy and ending

A program of listeners is a [[transition-system]]: a state, and moves that events trigger. [[entry:javascript-events]] keeps its state in one object that only listeners touch, and each listener is one transition. Two questions decide whether such a program is sound.

**Can a listener be called again while it is still running?** That is *re-entrancy*. A synchronous `emit` allows it: a listener emits an event whose listener emits the first event again. The synchronous column above is exactly that, and its price is the stack. The scheduled version cannot be re-entered, because the next card is a new turn.

**Does it end?** A chain of events that never stops is a loop that nobody can see. The program must have one listener that does *not* announce the next step, and it must tidy up: roll back what was not committed, close the database, remove the listeners and stop the timers. In [[entry:javascript-events]] that is `finished` (or `failed`), and then `done` removes everything.

A listener cannot pause in the middle and be resumed, so a chain of listeners is not a [[coroutine]]. Each listener runs to its end and returns, and the next one starts fresh. State has to live outside them. The same is true for a [[closure]] used as a callback: it keeps variables, but not a *place* to resume.

## Backpressure, and when events are the wrong tool

An event source announces things at its own speed. Events have no way to say "slower". If the producer is faster than the consumer, the queue grows without a limit, or events are dropped. **Backpressure** is the way a consumer pushes back. A pull is the simplest form of it, because the consumer asks for one value when it is ready: [[entry:javascript-weird]] cannot be flooded, since nothing is drawn until `next()` is called. [[entry:tar-gnu-weird]] shows the opposite. tar keeps writing records and calling the clock after the machine is done, and those ticks only count as idle.

[[entry:javascript-events]] is safe from the flood for a plain reason: each card waits for the one before it, so the producer and the consumer are the same program. A real event source, such as a network socket, needs a bounded queue or a stream.

Events are also the wrong tool when:

- there is exactly one listener, and it is always the same one. A function call says the same thing, is shorter, and a debugger can step through it;
- the order must be obvious. With events it is in the names and in the order of registration;
- you need a result back. An event announces, and it does not answer.

## Events in this repository, and what is only a look-alike

Not every callback is an event, and not every window is event-driven. The table says what each entry really has.

| Entry | What it has | Is the program event-driven? |
|---|---|---|
| [[entry:javascript-events]] | Ten listeners on one emitter; `setImmediate` between cards; a pulse timer | **Yes.** The listeners are the program |
| [[entry:javascript]] | A `for` statement, then a `setInterval` callback for the pulse | Only the pulse. The cards are a loop |
| [[entry:javascript-weird]] | A pull pipeline, then the same timer | Only the pulse. The cards are pulled |
| [[entry:tar-gnu-weird]] | tar runs a command at every checkpoint | **Yes.** A callback from outside moves a state machine one step. There is no loop in the program |
| [[entry:regex-pcre2]] | The engine calls a function at every callout | A **callback**, but a synchronous one: it is a call from the engine, not a queued event |
| [[entry:tcl-weird]] | A trigger calls an SQL function, which calls Tcl | A **callback chain** on one call stack. The database dispatches, and nothing waits in a queue |
| [[entry:ModernChallenge1]], [[entry:LinqChallenge1]], [[entry:xaml]] | A WPF window with its message loop (`Application.Run`) and an animation that is started by a `Loaded` trigger | **No.** The UI framework has an event loop, and an animation is declared, not subscribed to. The cards come from a `for` statement, a LINQ pipeline and a parser |
| [[entry:PythonChallenge1]], [[entry:RustChallenge1]] | A Tk `mainloop` and a GLib `MainLoop`, with a timer that moves a color | **No.** The same: a window runs its own loop, and the cards are made before it opens |
| [[entry:JavaChallenge1]], [[entry:KotlinChallenge1]], [[entry:GoChallenge1]] | A modal Swing dialog with a timer that fades the colors (Java, Kotlin), and a page served to the browser (Go) | **No.** The window opens at the end, and the cards come from a `for` statement or a sequence |

An animation framework, data binding and a window's own loop are *mechanisms* that use events. They do not make the program that starts them event-driven. The test is simple: **does the card logic run because an event arrived?** If the answer is "no, a loop or a pipeline runs it, and then it opens a window", the entry is a loop with a window.

## Predict, then run

[Exercise B22](../exercises.md#b22-javascript-event-driven-predict-the-trace-then-remove-the-boundary-verified) asks you to write the trace of a run *before* you see it, to predict what `emit` and `setImmediate` print, and to remove the scheduling boundary and watch a million cards run out of stack. Do the prediction on paper first. The surprise is the point.
