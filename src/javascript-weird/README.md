---
name: "JavaScript"
teaches: "that a closure is a state machine: a function plus the variables it was made next to, pulled one step at a time by an iterator, with reduce as the one fold that cannot stop."
kind: weird
languages: [javascript, sqlite]
lesson: "languages/javascript.md#closures-all-the-way-down"
loop-by: lazy-demand
evaluation: lazy
assurance: guaranteed
pairs-with: javascript
machine: "A closure-backed state machine, pulled by a lazy iterator"
state: "Variables captured by closures: the generator's number, and the machine's card count, total and stop flag"
tags: [closure, computation-versus-orchestration, dataflow-programming, deferred-execution, eager-evaluation, event-driven-programming, first-class-and-higher-order-functions, functor, generators, invariant, lazy-evaluation, monoid-and-fold, referential-transparency, reproducibility, scope-and-binding, short-circuit-evaluation, side-effect, state]
analogies: [category-theory, coroutine]
counterexamples: [continuation]
---
# JavaScript, weirder: closures all the way down

**Teaches you:** that a closure is a state machine: a function plus the variables it was made next to, pulled one step at a time by an iterator, with reduce as the one fold that cannot stop.

> **DEMO ONLY.** Fictional time cards, written to a scratch SQLite file under `$XDG_DATA_HOME/JavaScriptWeird/`.
> Nothing here touches real time reporting.

The [conventional entry](../javascript/README.md) is a `for` statement with an empty body. This one has **no loop statement at all**, and no `this`. The algorithm is three small closures in [`core.mjs`](core.mjs), and the program in [`timecards.mjs`](timecards.mjs) is one expression that pulls cards through them:

```js
const records = Iterator.from(cards(machine(hoursFrom(seed))))   // three closures, nested
  .map(stamp(user, week))                                          // a closure that makes a card into a record
  .map(save)                                                       // a closure that saves it
  .toArray();                                                      // the demand: pull cards until there are none
```

```text
$ node timecards.mjs
# DEMO ONLY run 1
Meetings	12	12	2026-W47	DEMO ONLY
Coding	17	29	2026-W47	DEMO ONLY
Debugging	17	46	2026-W47	DEMO ONLY
# committed total=46 entries=3 DEMO ONLY

Total simulated hours: 46.0
Saved locally for the modernization exercise.
```

This is the **weird** entry of a pair. Read the pair as three steps: the [C# original](../ModernChallenge1/README.md), the [bodiless `for` in Node](../javascript/README.md), and this.

## Run it

You need **Node.js 24 or newer**: it has `node:sqlite` and the *iterator helpers* (`Iterator.from`, `map`, `some`, `take`, `toArray`), both built in. There is no `npm install`.

```bash
cd src/javascript-weird
node timecards.mjs                       # run the demo (SEED=42 replays one exact run)
node --expose-gc --test check.mjs        # the closure lab: 12 tests that prove what this page says
./check.sh                               # everything below (needs sqlite3 and GNU date, and `script` for the terminal tests)
```

Records go to `$XDG_DATA_HOME/JavaScriptWeird/demo-timecards.db` (default `~/.local/share/JavaScriptWeird/`).

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker).

```bash
sandbox/container/run-image.sh src/javascript-weird          # the plain, CI-style output
sandbox/container/run-image.sh --tty src/javascript-weird    # with a terminal: watch the DEMO ONLY line pulse
```

It builds this folder's [`Dockerfile`](Dockerfile) and runs the result with no network, a read-only file system and user `nobody`.

## How the stunt works

### Three closures

A **closure** is a function together with the variables it was made next to. [`core.mjs`](core.mjs) has three, each made by another function:

```text
 hoursFrom(42)                  machine(hoursFrom(42))                cards(machine(...))
 +----------------+             +-------------------------+           +-------------------------+
 | state = 42     |<--calls-----| nextHours  (the left box)|<--calls--| next                    |
 | () => 10+...   |             | n = 0   total = 0       |           | [Symbol.iterator]()     |
 +----------------+             | over = false            |           |   -> { next() }         |
                                | () => card | undefined  |           +-------------------------+
                                +-------------------------+
 Nobody can read state, n, total or over. The only way to move them is to call the function.
```

| Closure | Captured variables | One call does |
|---|---|---|
| `hoursFrom(seed)` | `state` | Moves `state` (Park-Miller) and answers 10 to 19 |
| `machine(nextHours)` | `n`, `total`, `over` | Asks for hours, adds them to `total`, sets `over = total > 40`, and answers the card. After the card that took the total over 40, it answers `undefined` for ever |
| `cards(next)` | none of its own: it holds `next` | Wraps the machine in the **iteration protocol**: `next()` answers `{ value: card, done: false }`, or `{ done: true }` when the machine has no card |

**The stop rule is `over = total > 40`.** It is a variable inside a closure, set in the same call that makes the crossing card. So the crossing card is the last one, and it is included.

### Demand is the loop

Nothing is drawn until something asks. [`timecards.mjs`](timecards.mjs) builds a pipeline of lazy steps (`Iterator.from`, then two `map`s) and ends it with `.toArray()`, which asks for every value until the iterator says `done`. Each ask pulls **one** card all the way through: drawn, stamped, saved. Then the next ask starts. Replace `toArray()` with `take(1).toArray()` and exactly one card is drawn. `check.mjs` counts the draws to prove it.

| Job | Done by |
|---|---|
| Loop | The consumer's demand: `toArray()` calls `next()` until `done` |
| Random hours | `hoursFrom`: a closure over one number |
| Running total, category order, stop rule | `machine`: a closure over `n`, `total`, `over` |
| Turning a card into a record | `.map(stamp(user, week))`: a closure over the user and the week |
| Saving | `.map(save)`: a closure over the prepared statement. It saves and returns the record, so it can sit in a pipeline |
| The final sum | `reduce`, over the finished list |
| Output | `console.log`, and a `setInterval` pulse on a terminal |

### What `map` and `reduce` do here, exactly

- **`map` (twice)** derives records from cards, and then saves each one. It runs *lazily*: the helpers on an iterator do one value at a time, so a card is stamped and saved before the next card exists.
- **`reduce`** adds up the hours of the *finished* list. It is not used to stop. `reduce` cannot stop: it walks every element (`check.mjs` counts the calls). That is why it comes after `toArray()`.
- **No `flatMap`.** There is nothing for it to expand. We did not add one to have one.

### Five ways to stop (each one tested)

| Way | Stops early? | What `check.mjs` shows | Used here? |
|---|---|---|---|
| `reduce` with a "done" flag | **No.** The callback runs for every element | Five elements, five calls, though the answer was settled after three | Only after the list is complete |
| A bound drawn up front (`Array.from({ length: 5 }, machine)`) | By guessing | Five slots asked for, two of them empty. The program would draw more than it uses | No |
| `some` / `find` on the iterator | **Yes.** They ask only while the answer is "no" | Three draws for three cards | No (the machine already ends the stream) |
| The source says `done` (a custom iterable) | **Yes**, and the consumer need not know | The machine answers `undefined` after the crossing card; it never asks for more hours | **Yes** |
| `throw` from the callback | Yes, and it is the wrong tool | `reduce` ends, with an exception that something must catch. Control flow by error | No |

### Where does the program live, and what makes the next step run?

| | C# original | JavaScript, bodiless `for` | JavaScript, closures |
|---|---|---|---|
| Where the program lives | In the three clauses of a `for` | In the three clauses of a `for` | In three closures and one expression |
| Where the state lives | Fields of an anonymous object | Properties of an object literal | **Captured variables**, which nothing else can reach |
| What makes the next step run | The `for` statement: test, body, iterator | The `for` statement | **The consumer's demand**: `next()` |
| What stops it | A condition that is false | A condition that is false | A closure that says `done` |
| When a card is made | When the iterator clause runs | When the iterator clause runs | When something asks for it |
| Can you run it again? | Run the program again | Run the program again | A new machine replays it; the old one is spent |

The **lazy-versus-eager** question has the same shape as in two other entries. In [`LinqChallenge1`](../LinqChallenge1/README.md) a query is a *description* that runs when something enumerates it, and enumerating it twice runs it twice. In [`haskell`](../haskell/README.md) a list is made on demand, and an infinite list is fine because only a prefix is forced. Here the iterator is closer to Haskell's list and unlike LINQ's query in one way: **it is spent**. The machine is a closure with a position, so a second pass finds it already over. To start again you make a new machine from the same seed.

### Closures, lambdas, `this` and continuations

- **A closure is not the same as lambda syntax.** An arrow function that uses no outside variable (`x => x + 1`) is not an interesting closure. `() => (total += hours)` is: it changes a variable that lives past the call.
- **A closure captures variables, not values.** That is also true for a C# lambda. If two closures capture the same `let`, they share it. A new call to a factory (`machine(...)`) makes new variables, so two machines never share state (`check.mjs` interleaves two).
- **`this` is not a captured variable.** A method that uses `this.n` loses its `n` the moment you pull it off its object (`check.mjs` shows the `TypeError`). A closure keeps its variable.
- **A closure is not a continuation.** You can call it again, and it does the next step. You cannot hand it a place to *resume in the middle* of something, and you cannot go back. A generator function, or an explicit continuation, is a different tool.
- **The environment lives as long as the function can be reached.** A function nobody refers to is collected, and its variables go with it. `check.mjs` proves both halves with a `WeakRef` and a forced garbage collection (`node --expose-gc`).

### Effects stay at the leaves

`core.mjs` imports nothing, and has no `console`, no clock, no timer and no `process`. It is pure in the sense that matters: given the same hours it always makes the same cards, and `check-static.mjs` checks that it has no I/O, no clock and no timer. `timecards.mjs` holds the impure parts: the seed, the date, the database, the screen and the pulse. Each one is a small closure. The pulse starts after everything is saved, only on a terminal, and is the only thing that keeps the event loop alive: with redirected output there is no timer and Node exits at once.

## What `check.sh` enforces

- **The constraint is real.** `check-static.mjs` scans both files with comments and strings blanked out. There is no `for`, `while` or `do`, no `forEach` (a loop in disguise), no `eval`, no `Function`, no `this`, and no network, process or vm module. `core.mjs` uses no `process`, `console`, `Date`, `Math`, `crypto`, timer or `import`. `Symbol.iterator`, `Iterator.from`, `map`, `reduce` and `toArray` really are used. Eight mutants (a `while`, a `for`, `eval`, `console` and the clock in the pure core, `this`, `forEach`, `node:child_process`) are rejected.
- **The closure lab (`check.mjs`).** Twelve tests: captured state persists and is private, two machines do not share state, a seed replays and a machine cannot be rewound, the crossing card is kept and exactly 40 goes on, nothing is drawn until something asks, lazy `map` interleaves the stages while an array `map` does not, `reduce` runs for every element, `some` stops, a `throw` stops a `reduce`, an iteration cannot be repeated (a new machine can), closure lifetime under a forced garbage collection, closure versus `this`, and closure versus continuation.
- **The rules of the challenge.** 25 random runs: categories in order, hours 10 to 19, correct running totals, a stop right after the first total over 40, `DEMO ONLY` everywhere, nothing on stderr, no escape codes in redirected output. In SQLite: only demo rows, the current user, and every `running_total` equal to the sum of the hours so far.
- **Seeds.** `SEED=42` twice gives the same cards. Twelve seeds match a separate model of the generator in awk, and a seed whose first four cards make exactly 40 must get a fifth.
- **The ISO week** agrees with GNU `date` on ten dates, and **the pulse** behaves on a pseudo-terminal, with `NO_COLOR`, with `TERM=dumb`, and when redirected.
- **Errors and the schema.** An unwritable data folder ends with a non-zero status. SQLite refuses a non-demo row or run, 9 hours and a fifth category.

## Gotchas worth knowing

- **Iterator helpers need Node 22 or newer.** They are part of ECMAScript 2025, so the language **guarantees** them, and the closures. `node:sqlite` is a Node API, not part of the language. We tested Node 24.15 and 24.22.
- **`map` with effects is a trick, and a deliberate one.** A pure `map` does not care in what order it runs. This one saves a record in each call, so the lazy order (card 1 is saved before card 2 is drawn) is the program. With an array, `cards.map(stamp).map(save)` would draw all the cards first and save them afterwards: same rows, different order of effects, and no way to stop at 40 without a separate step. The check shows the difference.
- **The first `done` is final.** `{ done: true }` from `next()` ends the iteration, and the helpers never call `next()` again. The machine is also safe if someone does: it answers `undefined` and asks for no more hours.
- **`WeakRef` is only a hint, and the GC test is the one fragile test.** An engine may keep an object as long as it likes. The test forces a collection with `--expose-gc` and retries a few times. It passed 25 of 25 runs on Node 24.15. Treat a failure there as the GC test, not as a bug in the program.
- **The generator is not a generator.** `cards` is a hand-written iterable: an object with a `[Symbol.iterator]` method and a `next` method. A `function*` would be shorter, but it has a program counter inside it, and it would hide the closure. Both are in the book: this one shows the protocol.
- **An iterator is not replayable.** `[...it]` twice gives the cards and then nothing, as in the check. That is the opposite of an array and of a LINQ query.
- **`this` is gone on purpose.** It was in the conventional entry, only so that `clearInterval(this)` could stop the timer. Here a closure over `id` does that.
- **The pulse timer is the one callback with state of its own.** Its `frame` and `id` are captured by the timer callback and nothing else, which is exactly the point of this entry.

---

See the [root README](../../README.md#the-results-so-far) for how this compares to the other entries, and [`CHALLENGE.md`](../../CHALLENGE.md) if you want to write your own.
