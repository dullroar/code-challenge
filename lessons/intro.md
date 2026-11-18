# Intro: why these lessons exist

You already know how to write a loop, query a database and call a function. You have read the tutorials. This is what comes after them.

The [code challenge](../README.md) asks one question in many accents: *how far can a language's own machinery be pushed before it starts acting like a general-purpose program?* Every entry builds the same small demo (fictional time cards of 10-19 hours, added until the total passes 40, saved to a local **DEMO ONLY** SQLite file) under an absurd constraint: one statement, no loop, no `IF`, nothing but a regex, nothing but a markup file.

The stunts are the door. These lessons are what is behind it.

## The teaching philosophy

> Teach the language by deliberately misusing it, then explain why the misuse works.

Most tutorials teach the idioms first: here is the right way to iterate, to hold state, to handle errors. These lessons start where the tutorials stop:

*You know the right way. Now find out what the language actually lets you do. Then ask why, although it is perfectly legal, it might be a terrible idea.*

The aim is to take your understanding up a level in two directions at once:

- **In a specific language.** You will learn what `ALTER`, `unsafeInterleaveIO`, `>in`, `include`, `CMAKE_MATCH_1` and `⎕FX`, `RT`, `unknown`, rescanning, method combination and a `find` that digs its own tree really do, which means you will learn how COBOL, Haskell, Forth, Make, CMake, APL, Common Lisp, m4, Tcl, AWK and find really work.
- **As concepts.** Control flow, state, evaluation order and side effects turn out to be separable things that different languages bolt together differently. Once you have seen control flow stored in a `GO TO`'s target, a parse position, a restarting build tool and a regex capture, you stop thinking of "the loop" as a given.

## The shape of every lesson

Each strange example is taught in the same five steps, whatever the language.

| Step | What happens |
| --- | --- |
| 1. **Behold the monstrosity** | The working program, and the command to run it ([in a container](exercises.md#running-things-safely)). Try to understand it *before* reading on. |
| 2. **How the hell does that work?** | The real semantics: what the compiler, interpreter, runtime or operating system actually does. The mechanism, not just the trick. |
| 3. **What did we just learn?** | The generalizable idea. Make is a dependency engine that can restart itself. COBOL's `ALTER` means a jump target is mutable state. LINQ is an execution pipeline, not just a query language. |
| 4. **Do this in production and you're fired** | The concrete failure modes: debugging, optimizers, concurrency, portability, security, testing, maintenance. Plus the honest cases where the technique is legitimate. |
| 5. **Now break it yourself** | An experiment that only works if you understood step 2. Predict, change, run, compare. See [exercises](exercises.md). |

Without step 5 this would be a museum of curiosities. The exercise is what turns curiosity into understanding.

## Three kinds of knowledge

Experienced programmers sometimes confuse "I've done this for twenty years" with "the language guarantees this." Every lesson tags what it leans on:

| Tag | Meaning | Example |
| --- | --- | --- |
| **Guaranteed** | The specification or documented semantics promise it. | `span` on a lazy list reads only as far as it must. |
| **Implementation-permitted** | Works because of a particular compiler, runtime, platform or version. | GnuCOBOL still runs `ALTER`. `pcre2grep` callout scripts need a special build. |
| **Accidentally exploited** | Works today, but nobody promised it. | Make restarting itself because a makefile it can remake was "remade". |

## The recurring question

Every lesson ends by asking:

> Under what circumstances would this terrible idea become a reasonable engineering decision?

Sometimes the answer is "never, given the alternatives." Sometimes it is "when you are writing a compiler, debugger, interpreter or test framework." Occasionally it is "when you are running a mainframe in 1978." A language feature is neither good nor bad in isolation: its value depends on the problem, the environment and the consequences. `ALTER` horrifies modern programmers, and it also served real purposes under real constraints. That does not mean we should revive it. It means we should understand why it worked, what it cost, and what changed.

## Weird next to boring

Pair each weird program with the small, idiomatic version of the same behavior (the repo has several: [`cobol`](../src/cobol/README.md) beside [`cobol-weird`](../src/cobol-weird/README.md), [`haskell`](../src/haskell/README.md) beside [`haskell-weird`](../src/haskell-weird/README.md), [`lisp`](../src/lisp/README.md) beside [`lisp-weird`](../src/lisp-weird/README.md), and so on). The point is not that the idiomatic one is morally superior. It is to see what got easier, what got harder, and what surprising capability the weird version revealed.

## Three ways in

- **By computer science concept**, if you want the theory first: [cs/](cs/README.md). Each idea gets a short explanation of why it exists, why people use it, when it fits and when it does not, with links to Wikipedia and other long-lived, freely reusable sources.
- **By language**, if you want to deepen the one you use: [languages/](languages/README.md).
- **By mechanism**, if you want to explore an unfamiliar way of computing: [patterns](patterns.md). A reader who arrives for C# may meet Haskell's laziness and realize both raise the same question: *when does the computation actually run?* One who arrives for COBOL's `ALTER` meets Make's restart machinery and CMake's regex registers, which are other ways of keeping control state outside ordinary variables. That cross-pollination is the point.

Then see [goals](goals.md), what was [overcome](problems-overcome.md), what is still [blocked](blocking-problems.md), and the [exercises](exercises.md).

## A word of caution

This is not a production style guide. Do not try any of it at work, and do not tell the boss. Every program here writes **DEMO ONLY** data to a local throwaway file; run them in the [container or sandbox](exercises.md#running-things-safely) rather than trusting them.
