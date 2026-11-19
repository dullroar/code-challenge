---
title: "Comparative case studies"
---
For an advanced reading path with traces and experiments, see the [comparative machine design study guide](../study-guides/concepts/comparative-machine-design.md).

The [shared challenge](../intro.md#what-the-challenge-does) asks for fictional cards up to and including the first card that takes the total over 40, a local record of those cards and a result the reader can see. Some entries print to a terminal, others open a window. See [where entries differ](../intro.md#where-entries-differ) for fixed LINQ data, the four-pass XAML ceiling and persistence variations. Each section asks what plays a particular **role**, starting with what repeats.

The tables are generated from the metadata at the top of each entry’s README. The README and executable source are where you can check the classification. Evaluation describes what drives the main computation. In the C# `for`, for example, an embedded deferred LINQ projection is consumed immediately by `Sum()` on each test of the loop condition. The final table lists every entry with its kind, evaluation strategy and weakest required assurance.

{{table:roles}}

## Where does the program live, and what makes the next step run?

Ask these two questions of any entry, and the strange ones stop looking alike. The first says where the program and its state are kept. The second says what causes the next step to execute.

| Entry | Where the program and its state live | What advances it |
| --- | --- | --- |
| [[entry:xaml]] | A declarative document, built into objects | The parser: objects are made in document order |
| [[entry:tar-gnu]] | Serialized archive members, plus a contract (`tarprog/1`) that tar knows nothing about | Tar's walk over the members, and the operator's `--to-command` |
| [[entry:tar-gnu-weird]] | The archive's layout, and one row of registers in SQLite | GNU tar's checkpoint events: one tick per record written |
| [[entry:ed-weird]] | The editor buffer: lines, and rows of marks | Addressed editing: one global command, and substitutions that apply only when they match |
| [[entry:ex-weird]] | The buffer, the editor's marks and registers, and a tape of numbered lines | Ex itself: a register that runs itself, steered by a line of data |
| [[entry:make-gnu]] | Targets, dependencies and restart state | Resolving the build graph, and restarting |
| [[entry:find-posix]] and [[entry:find-gnu]] | The directory tree, its depth and the names | The tree walk |
| [[entry:haskell-weird]] | Lazy values with effects in them | Demand: whatever is forced runs |
| [[entry:tcl-weird]] | SQL rows that hold stored source | The interpreter's lookup of an unknown command, and triggers |
| [[entry:javascript]] | Properties of one object literal, in a bodiless `for` | The `for` statement: initializer, condition, iterator |
| [[entry:javascript-weird]] | Variables captured by closures | A consumer's demand on an iterator: each `next()` runs one step |
| [[entry:javascript-events]] | One object that only the listeners of an `EventEmitter` touch | An event, then the scheduler: each listener emits the next event, and `setImmediate` gives the event loop a turn between cards |

## Writing a program down, reading it back, running it

Four different acts hide behind the words "the program is data". **Serialization** writes something down as bytes. **Deserialization** reads the bytes back into pieces. **Interpretation** gives the pieces a meaning. **Execution** gives that meaning an effect. A format can stop after any of them, and a consumer can combine them. What matters for safety is *which consumer you gave which authority to*. See [[serialization-deserialization-pickling]].

| Entry | Serialization | Deserialization | Interpretation and execution | The round-trip promise it makes |
| --- | --- | --- | --- | --- |
| [[entry:tar-gnu]] | A builder writes the members of an archive, in a fixed order, from a seed | Tar parses the members. A passive inspector does the same without running anything | A dispatcher gives four record types a meaning, and runs them only when the operator passes `--to-command` | Same seed, same bytes (checked with `cmp`). The inspector and the database agree on every card. One archive in two fresh databases gives the same cards. It does **not** promise to resume a stopped run |
| [[entry:xaml]] | A `.xaml` file is an object graph written as markup | `XamlReader.Load` parses it | The same call runs it: methods are called as objects are made | None. Parsing *is* running, and the entry never writes the document back |
| [[entry:tcl-weird]] | Tcl source is stored as rows in SQLite | An overridden `unknown` command fetches a row | The fetched text is defined and evaluated as Tcl | The source comes back as the text that was stored. It does not keep any object identity |
| [[entry:apl-weird]] | `⎕CR` writes a function out as a matrix of characters | `⎕FX` defines a function from such a matrix | Each function rewrites its source, defines the copy, and calls it | The matrix is what `⎕FX` accepts back: a property of GNU APL that the entry uses |
| [[entry:regex-sed]] and [[entry:m4]] | None apart from the text itself: the state *is* text | None: there is nothing to read back | The rules rewrite the text until none applies | The text is its own representation, so a round trip is the identity. This is an analogy, and not serialization in the object-graph sense |

Read down the last column. Only one of the five makes a promise about *behavior* after a round trip, and it names what it does not promise. That is the honest shape of the topic: "I can write it down and read it back" is a weaker claim than "it will do the same thing", and both are weaker than "I can pause it and carry on".


## Every entry at a glance

{{table:glance}}
