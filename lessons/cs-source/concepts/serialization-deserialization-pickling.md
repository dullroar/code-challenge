---
title: "Serialization, deserialization and object pickling"
chapter: 6
order: 90
---
**Serialization** turns something abstract into bytes that you can store or send: an object, a state, a list of instructions. **Deserialization** reads the bytes back. These are two separate acts, and a third act hides behind them: **interpretation**, which gives the decoded data an effect. You can parse a file and do nothing with it. You can also parse a file and run it. Most of the danger in this topic lives in the gap between the two.

**Object pickling** is serialization of an object graph. Python's `pickle` writes the *recipe* to rebuild an object: which class, which arguments, which attributes. Reading a pickle can call any function the recipe names, so unpickling bytes you do not trust runs the sender's code. The Python documentation says so in a warning box. A serialized **program** is the same idea one level up: source text, a syntax tree, bytecode, or a small instruction stream stored as records. [[entry:tar-gnu]] stores a program as the members of a tar archive: each member name is an instruction, each member body is its operand. [[entry:tcl-weird]] stores Tcl source in SQLite rows and runs it on demand. [[entry:apl-weird]] reads a function's source, rewrites it, and defines the copy. [[entry:xaml]] stores an object graph as markup that a parser turns into live objects.

What does a round trip keep? Be exact, because "the same" has four different meanings:

- **Byte identity.** `encode(decode(bytes))` gives the same bytes. [[entry:tar-gnu]] builds a byte-identical archive from the same seed, because it fixes the order, the times and the owners.
- **Structural equality.** The decoded structure has the same fields and values. The inspector in [[entry:tar-gnu]] and the database rows agree on every card.
- **Behavioral equivalence.** Running the decoded program gives the same results. Two runs of one archive, in two fresh databases, give the same cards.
- **Continuation or live-state preservation.** A paused process, with its stack, its open files and its position, resumes where it stopped. This is a much stronger promise. Almost no format makes it, and the tar entries do not claim it.

`decode(encode(x))` may keep some of these and lose others. A JSON round trip keeps the structure and loses the object's identity, its methods and its undefined values. State what you promise before you promise it.

**Security.** Bytes are inert until a consumer gives them meaning. A tar archive cannot register a hook for itself: `tar -xf` only writes files, and it is the operator's `--to-command` option that makes tar start a program for each member. JSON is not "safe by nature" either. It is only data, until a consumer passes a field to `eval`, a shell or a SQL string. Unsafe deserialization attacks chain the *reconstruction callbacks* that a format allows (constructors, `__reduce__`, `readObject`) into code that does something the author did not plan. The defenses are old and boring. Do not deserialize untrusted bytes into live objects. Check every record against a strict grammar. Refuse what you do not know. Run the consumer with the least privilege it needs.

**Category theory.** An encoder and a decoder are functions that should compose to something with a stated law: `decode ∘ encode = id` on the values you care about. That is true for some types and some formats, false for others (a format may map two values to one string). Do not call a codec an isomorphism unless you can prove the law in both directions; [[category-theory]] says what the word asks of you.

| | What the bytes hold | What the consumer rebuilds | Can code run while reading? | Where the trust boundary is |
| --- | --- | --- | --- | --- |
| Python `pickle` | A recipe: classes, arguments, state | Live Python objects | Yes, by design | Around the bytes: never read pickles you did not write |
| JSON | Numbers, strings, lists, maps | Plain data | No, unless your code interprets a field | Inside your code that uses the fields |
| tar | Files: names, bytes, sizes, times, modes | Files on disk, or a stream of members | No, unless the operator passes `--to-command` or `--checkpoint-action` | In the command line the operator wrote |

- **Use it when:** you must store a state, send a value, or ship a program, and you can state which kind of "same" you need back.
- **Avoid it when:** the bytes come from someone you do not trust and the format can rebuild arbitrary objects. Use a data-only format and a strict parser.

**Read more:**

- [Serialization](https://en.wikipedia.org/wiki/Serialization) (Wikipedia)
- [Pickle (Python)](https://en.wikipedia.org/wiki/Pickle_(Python)) (Wikipedia)
- [Tar (computing)](https://en.wikipedia.org/wiki/Tar_(computing)) (Wikipedia)
- [Deserialization of untrusted data](https://owasp.org/www-community/vulnerabilities/Deserialization_of_untrusted_data) (OWASP)
- [Deserialization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html) (OWASP)
- [`JSON`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON) (MDN)
