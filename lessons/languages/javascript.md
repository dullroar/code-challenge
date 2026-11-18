# JavaScript

Entries: [`src/javascript`](../../src/javascript/README.md) (the original's bodiless `for`, in Node.js) and [`src/javascript-weird`](../../src/javascript-weird/README.md) (closures and a lazy iterator, with no loop statement). JavaScript is the language of the browser, and with Node.js it is also a general-purpose scripting language on the server. Its `for` statement is the C `for`: three clauses and a body. Here the body is empty and the three clauses are the whole program.

## What makes JavaScript special

| Feature | What it teaches |
| --- | --- |
| `for (init; test; update) body` | A loop is three expressions and a statement. The order is fixed: init once, then test, body, update, test, body, update, until the test is false. |
| The comma operator `(a, b)` | Evaluate both, give the second. It lets one expression do several things in order, which is how the iterator clause adds a card *and* saves it. |
| Truthiness and `&&`, `?:` | A test can be any value, and `a ? b : c` is an expression, not a statement. So the stop rule can be a value, and a side effect can sit in the false branch. |
| `let` in a `for` header | The loop variable is copied for each iteration. A closure made in the body sees its own copy. A copy of an *object reference* is a reference to the same object, so the state is shared. |
| Arrow functions and closures | A function carries the variables around it. The seeded random generator is a closure over one number. |
| Iterators and the iteration protocol | An object with `[Symbol.iterator]()` and a `next()` method can be consumed by `for...of`, by spread, by `Iterator.from(...).map(...)`. The *consumer* decides how many values to ask for. |
| Node.js: the event loop | JavaScript runs on one thread. Timers fire only when the current code is done. The pulse works because the loop is finished first. |

## The bodiless for in Node

### 1. Behold the monstrosity

```bash
sandbox/container/run-image.sh src/javascript
```

One statement, about 80 lines long. The body is empty. No function is declared in the file.

### 2. How the hell does that work?

- **The initializer builds the state.** One `let i = ...` holds a list of hours, the database, the clock and a seeded random generator. A `for` allows one declaration, so the state is one object.
- **The condition is the stop rule, and the report.** `total <= 40 ? true : (print, false)`. While it says `true` the loop goes on. When it says `false` it has already printed the result.
- **The iterator is the work.** It draws the hours and saves the card. It runs *before* each test, so the card that crosses 40 is saved before the test sees it. That is why the crossing card is included.
- **A timer is the animation.** On a terminal, `setInterval` pulses the DEMO ONLY line. It starts only after the loop, so it cannot slow the cards down.

The [README](../../src/javascript/README.md#how-the-stunt-works) has the table of what the C# did and what this does, and a measured comparison with the original.

### 3. What did we just learn?

- **Evaluation order is the program.** Init, test, body, update: the order is the control flow, and you can put side effects in any clause.
- **A conditional is a value.** `?:` and `&&` choose between expressions, so they can choose between *effects*.
- **State has to live somewhere that survives an iteration.** A `let` number would be copied. An object is shared.
- **The event loop is a second loop.** The `for` runs to the end first. The timer runs after. They do not interleave.
- **The comma has two meanings.** In a declaration it separates declarators. In an expression it is an operator. C# lets you mix the two in an initializer. JavaScript does not.

Tags: the `for` semantics, `?:`, `&&`, the comma operator and closures are **guaranteed** by the ECMAScript specification. `node:sqlite` is a Node.js API, outside the language standard (**implementation-permitted**).

### 4. Do this in production and you're fired

- **A `for` with an empty body hides the program in its header.** Nobody can find the loop body, because there is none.
- **Side effects in a condition are a bug waiting.** If the test runs twice, the result prints twice.
- **The state object is a global in disguise.** Anything can reach into it.

Legitimate uses: `for (;;)` with a `break`, and a comma in an update clause for two counters.

### 5. Now break it yourself

See [exercise B20](../exercises.md#b20-javascript-read-the-clauses-move-the-limit-and-fail-the-structure-check-verified).

## Closures all the way down

### 1. Behold the monstrosity

```bash
sandbox/container/run-image.sh src/javascript-weird
```

No `for`, no `while`, no `this`. The algorithm is three closures of one line each. The program is one pipeline: `Iterator.from(...).map(...).map(...).toArray()`.

### 2. How the hell does that work?

- **A closure is a state machine.** `machine(nextHours)` returns a function. It remembers a count, a total and a stop flag in variables that only it can reach. Each call makes the next card.
- **The iteration protocol is the loop.** An object with a `next()` method that says `{ done: true }` when it is finished. `toArray()` keeps asking until it hears that.
- **The stop rule is a variable.** `over = total > 40`, set in the same call that makes the crossing card. After that the machine answers `undefined`, and the stream ends.
- **Demand decides.** Nothing is drawn until something asks. `take(1)` draws one card. `toArray()` draws all of them.
- **`reduce` is the fold that cannot stop.** It runs for every element. So it adds up the finished list, and the stop is done somewhere else.

The [README](../../src/javascript-weird/README.md#how-the-stunt-works) has the closure diagram, a table of five ways to stop, and a comparison of the C# original, the bodiless `for` and this one.

### 3. What did we just learn?

- **A closure is a function plus its environment.** Lambda syntax alone is not a closure that matters. A function that changes a variable that lives past the call is.
- **Closures capture variables, not values.** Two closures over one variable share it. Every call to a factory makes new variables.
- **`this` is not a captured variable.** Detach a method and it loses its `this`. A closure keeps what it captured.
- **A closure is not a continuation.** It can be called again. It cannot resume in the middle of something, or go back.
- **Lazy and eager give different orders of effects.** `Iterator.from(xs).map(a).map(b)` runs `a1 b1 a2 b2`. `xs.map(a).map(b)` runs `a1 a2 b1 b2`. For pure functions nobody can tell. With effects you can, and that is why the "map preserves composition" law needs pure functions.
- **Only some operations can stop early.** `some`, `find`, `take` and a source that says `done` can. `reduce` cannot. A `throw` can, and it is the wrong tool.

Tags: closures, arrow functions and the iteration protocol are in the ECMAScript specification, and so are the iterator helpers since ECMAScript 2025 (**guaranteed**). `node:sqlite`, `WeakRef`'s timing and `--expose-gc` are engine and Node details, used only in the check.

### 4. Do this in production and you're fired

- **Effects inside `map` surprise people.** A reader expects `map` to be pure. This one saves rows.
- **Hidden state is hard to inspect.** A debugger shows captured variables, and `console.log` of the function does not.
- **An iterator that is spent is a trap.** A second pass over it gives nothing, with no error.

Legitimate uses: closures for private state, factories for configured functions, lazy pipelines for streams that are too big to hold, and `some`/`find` for "stop at the first".

### 5. Now break it yourself

See [exercise B21](../exercises.md#b21-javascript-weirder-move-the-stop-rule-in-a-closure-and-watch-the-demand-verified).

## Computer science behind this page

<!-- BEGIN GENERATED concepts:languages/javascript.md -->
The computer-science ideas behind this page: [Control flow](../cs/03-control-flow-and-continuations.md#control-flow), [Eager evaluation](../cs/04-evaluation-and-demand.md#eager-evaluation), [Lazy evaluation](../cs/04-evaluation-and-demand.md#lazy-evaluation), [Short-circuit evaluation](../cs/04-evaluation-and-demand.md#short-circuit-evaluation), [Deferred execution](../cs/04-evaluation-and-demand.md#deferred-execution), [Iterators and generators](../cs/04-evaluation-and-demand.md#iterators-and-generators), [Referential transparency](../cs/04-evaluation-and-demand.md#referential-transparency), [State](../cs/06-state-beyond-variables.md#state), [Scope and binding](../cs/06-state-beyond-variables.md#scope-and-binding), [Side effects](../cs/07-effects-errors-and-commitment.md#side-effects), [Integrity constraints](../cs/07-effects-errors-and-commitment.md#integrity-constraints).
<!-- END GENERATED concepts:languages/javascript.md -->
