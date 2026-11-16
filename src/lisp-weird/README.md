# Common Lisp, weirder

**Teaches you:** that CLOS method combination is a control-flow construct: a class hierarchy is a loop, and `or` is a stop rule.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

Below the line marked `RUN TIME` in [`timecards.lisp`](timecards.lisp) there is **no loop, no `if`, `when`, `cond` or `case`, no `mapcar`, and no recursion**. Each card is a *method*. The cards are chained through a class hierarchy, and the generic function that calls them uses the built-in `or` method combination, which runs methods one after another and **stops at the first one that returns true**. Each method deals a card and answers "is the total over 40 yet?". The class precedence list is the loop counter, and `or`'s short-circuit is the stop rule.

The straight version is [`lisp`](../lisp/README.md).

## Run it

[SBCL](https://www.sbcl.org/) (tested with 2.2.9) and `sqlite3`. Nothing else: no libraries, no ASDF.

```bash
cd src/lisp-weird
sbcl --script timecards.lisp
./check.sh                  # set SBCL=/path/to/sbcl if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/LispWeird/demo-timecards.db` (default `~/.local/share/LispWeird/`). A run looks like this:

```text
# DEMO ONLY run 1794860078-QM6YV6
Meetings	18	18	2026-W47	DEMO ONLY
Coding	18	36	2026-W47	DEMO ONLY
Debugging	15	51	2026-W47	DEMO ONLY
# committed total=51 entries=3 DEMO ONLY
# PUNCH had 5 OR methods and 3 ran: the class precedence list is the loop, and OR is the stop rule
```

The last line is introspection: it asks the **metaobject protocol** (`sb-mop:compute-applicable-methods`) which methods apply to the ledger, and counts how many of the five actually ran.

## How the stunt works

### 1. Method combination: what happens when more than one method applies

When you call a generic function, CLOS finds every method whose specializers match, sorts them most-specific-first, and then **combines** them. The default combination calls the most specific method, and that method may call `call-next-method` to reach the next. But the standard also provides built-in combinations (`and`, `or`, `progn`, `append`, `list`, `max`, `min`, `+`, `nconc`) which call *all* the applicable methods for you and combine the results. With `or`:

```lisp
(defgeneric punch (ledger)
  (:method-combination or))
(defmethod punch or ((ledger card-3)) ...)    ; "or" here is the method qualifier
```

`punch` becomes `(or (method-1 ledger) (method-2 ledger) ...)`, in specificity order. Same short-circuit as the ordinary `or` special operator: the first true result ends it and **later methods never run**.

### 2. The class hierarchy as a counter

```text
card-1 -> card-2 -> card-3 -> card-4 -> card-5 -> ledger
```

`(defcard 3 card-4)` expands into `(defclass card-3 (card-4) ())` and a `punch or` method specialized on `card-3`. An instance of `card-1` therefore has class precedence list `(card-1 card-2 card-3 card-4 card-5 ledger ...)`, so `punch` runs card 1's method, then card 2's, and so on. The classes have no slots of their own; the class itself is the whole message "this is card number N". The `ledger` at the end of the chain holds the state (running total, entry count, random state, run id).

Why five? Cards are at least 10 hours, so four cards total at least 40, and 40 is not *over* 40 (that is the all-10s case); a fifth card always pushes past it. Five is the most this challenge can ever need.

### 3. The stop rule is `or`

`deal` ends with `(> (total ledger) 40)`. When it is true the chain stops. After three or four cards the remaining methods are simply never called. The program contains no statement that says "stop".

### 4. `:around`, `prog1`, and dynamic binding

An `:around` method on `ledger` wraps the whole chain. It binds the special variable `*sql*` to a fresh string stream (dynamic binding: every `format *sql*` deeper in the call stack, in `deal`, writes into it, with no stream passed down), calls `call-next-method` (which is the `or` chain), then appends `COMMIT` and pipes the script into `sqlite3`.

### 5. A circular list from the reader

```lisp
(defparameter *week* '#1=("Meetings" "Coding" "Debugging" "Learning" . #1#))
```

`#1=` labels the list and `#1#` points back at it, so the reader builds a ring. `(nth 4 *week*)` is `"Meetings"` again: the categories repeat with no `mod`. (Never print it with `*print-circle*` off.)

### 6. Generalized places

`(incf (total ledger) hours)`: `total` is a slot accessor, and every accessor is a `setf`-able **place**, so `incf` works on it exactly as on a variable.

### 7. Macros at compile time

`defcard` is a macro, so its expansion is five `defclass` and five `defmethod` forms written for us at compile time. The code that builds the names (`intern`, `format`) runs while compiling, inside `eval-when`, so none of it is a loop over cards at run time.

## Why this is weird

A Lisp programmer reads `or` as a *form*. Here it appears as a *qualifier on a method*, and the thing being or-ed is a chain of classes. Control flow is made out of the object system: dispatch is the iteration, specificity order is the sequence, and the return value is the "break". Nothing is doing the work in a thin wrapper: delete `:method-combination or` and the program no longer stops (see the proof below).

You should not do this in production because the control flow is invisible: nothing near `punch` says "this loops". A maintainer would have to know that `defclass` ordering decides execution order, and splicing a class into the chain would change behaviour without touching any method.

## What you can learn

- Method combination, qualifiers (`or`, `:around`) and how `defgeneric ... (:method-combination ...)` selects it. `define-method-combination` lets you write your own.
- Class precedence lists, and that they are *computed* (`sb-mop:compute-class-precedence-list`) and can be inspected.
- The metaobject protocol: `sb-mop:compute-applicable-methods` and `method-qualifiers`.
- Reader labels `#n=` / `#n#` for circular and shared structure.
- Dynamic binding (`defvar` + `let`) as an implicit parameter.
- Why `(eval-when (:compile-toplevel ...))` matters: a function used by a macro must exist at compile time.

## Proof that `or` is the stop rule

`check.sh` rewrites the file, replacing `or` with `progn` (the combination that runs *every* method) and runs it five times: every run deals **all five** cards, the total ending anywhere up to 95. The unmodified file stops after three or four cards. Nothing else changes between the two files, so the combination is what stops it.

## Gotchas and limitations

- **SBCL only.** `sb-mop`, `sb-ext:run-program`, `sb-ext:posix-getenv` are SBCL's. The CLOS parts (`or` combination, `:around`, `defcard`) are standard Common Lisp.
- **Order of definitions.** Superclasses must exist before subclasses, so `defcard` goes tail first (`card-5`, then `card-4`, ...). A forward reference would work in some implementations and warn in others.
- **The limit is baked into the chain.** Five classes handle "10 to 19 hours, stop over 40". Different rules need a longer or shorter chain: a design limit the straight version does not have.
- **`sql-quote` does not escape.** Every value is a number or one of four fixed words; do not use it with anything else.
- **Formatting.** No formatter exists for Common Lisp; the layout follows Emacs `lisp-mode` indentation by hand.

## What `check.sh` enforces

With comments removed, below the `RUN TIME` marker: none of `loop do dolist dotimes mapc mapcar mapcan map maphash reduce if when unless cond case tagbody go block return catch throw handler-case`; `(:method-combination or)` is present; there are exactly five `defcard` forms; the over-40 test appears once. Then the `progn` experiment above, then 25 runs each checked for sane records (hours 10-19, categories in order, correct running totals, stopping when the total passes 40) with SQLite agreeing with the output.

## Run it in a container

Prerequisite: Docker, set up once as described in [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md#docker). The `cc-rt-sbcl` base image comes from `sandbox/container/build-bases.sh`.

```bash
sandbox/container/run-image.sh src/lisp-weird
```

In the image: SBCL and sqlite3 on a minimal Ubuntu.
