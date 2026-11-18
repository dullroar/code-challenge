# JavaScript

Entry: [`src/javascript`](../../src/javascript/README.md) (the original's bodiless `for`, in Node.js). JavaScript is the language of the browser, and with Node.js it is also a general-purpose scripting language on the server. Its `for` statement is the C `for`: three clauses and a body. Here the body is empty and the three clauses are the whole program.

## What makes JavaScript special

| Feature | What it teaches |
| --- | --- |
| `for (init; test; update) body` | A loop is three expressions and a statement. The order is fixed: init once, then test, body, update, test, body, update, until the test is false. |
| The comma operator `(a, b)` | Evaluate both, give the second. It lets one expression do several things in order, which is how the iterator clause adds a card *and* saves it. |
| Truthiness and `&&`, `?:` | A test can be any value, and `a ? b : c` is an expression, not a statement. So the stop rule can be a value, and a side effect can sit in the false branch. |
| `let` in a `for` header | The loop variable is copied for each iteration. A closure made in the body sees its own copy. A copy of an *object reference* is a reference to the same object, so the state is shared. |
| Arrow functions and closures | A function carries the variables around it. The seeded random generator is a closure over one number. |
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

## Computer science behind this page

<!-- BEGIN GENERATED concepts:languages/javascript.md -->
The computer-science ideas behind this page: [Control flow](../cs/03-control-flow-and-continuations.md#control-flow), [Eager evaluation](../cs/04-evaluation-and-demand.md#eager-evaluation), [Short-circuit evaluation](../cs/04-evaluation-and-demand.md#short-circuit-evaluation), [State](../cs/06-state-beyond-variables.md#state), [Scope and binding](../cs/06-state-beyond-variables.md#scope-and-binding), [Side effects](../cs/07-effects-errors-and-commitment.md#side-effects), [Integrity constraints](../cs/07-effects-errors-and-commitment.md#integrity-constraints).
<!-- END GENERATED concepts:languages/javascript.md -->
