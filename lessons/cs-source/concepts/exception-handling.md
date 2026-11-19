---
title: "Exception handling"
chapter: 7
order: 30
---
Exception handling is a language feature for errors: raise a signal, unwind the stack and let a handler deal with it. It exists to keep the normal path of the code free of error checks. COBOL has an older, simpler form. `ON SIZE ERROR` runs when an arithmetic result does not fit the field, and the field stays unchanged. In [[entry:cobol-weird]] that overflow *is* the stop rule: a two-digit counter overflows on purpose, and the error branch ends the loop. Errors as control flow work, but they hide the real design from the next reader.

```mermaid
sequenceDiagram
    accTitle: Exceptions alter control flow by unwinding outward until a handler accepts them
    accDescr: A sequence diagram of three nested calls. The function main, which has a try and catch, calls process, and process calls save. Save throws an exception. The exception does not return to process in the normal way. It passes through process, which has no handler, so the rest of process is skipped. It reaches main, where the catch block handles it. After the handler, normal flow continues in main. The normal return statements of save and process never run.
    participant M as main: try and catch
    participant P as process
    participant S as save
    M->>P: call
    P->>S: call
    Note over S: throws an exception
    S--xP: unwinds, no normal return
    Note over P: no handler, the rest is skipped
    P--xM: unwinds, no normal return
    Note over M: catch block runs
    Note over M: normal flow resumes after the try
```

The normal `return` of `save` and `process` never runs. The exception passes outward through each call until a `catch` accepts it, and then normal flow resumes after the `try` in `main`. If nothing catches it, it leaves the program. Unwinding only moves control. It does not undo what the skipped code already did: a row that `save` wrote stays written, unless a transaction rolls it back (see [[transaction]]).

- **Use it when:** something truly unexpected happens, and the caller can recover or must be told.
- **Avoid it when:** the "error" is a normal, frequent outcome (such as "end of input"), or when you catch everything and move on in silence.

**Read more:**

- [Exception handling](https://en.wikipedia.org/wiki/Exception_handling) (Wikipedia)
- [Fail-fast system](https://en.wikipedia.org/wiki/Fail-fast_system) (Wikipedia)
