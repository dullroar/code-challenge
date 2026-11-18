---
title: "Capability and authority"
chapter: 1
order: 80
---
Who can do what is a question about **authority**, not only about data. A file that cannot do anything on its own gains power when something with authority agrees to act on it. The old rule of **capability security** is that you should hold only the authority you need, and that authority should come from what you were handed, not from what you can name.

[[entry:tar-gnu]] shows it in one line. An archive cannot register a hook for itself. `tar -xf` writes files and runs nothing, and `tar --to-command=...` starts a program for each member. The authority to run something is in the command that the *operator* typed, so the trust boundary is that command. [[entry:ed-weird]] and [[entry:ex-weird]] make a similar choice about the editors. GNU ed allows a shell escape (`!`) inside a global command list, and Ex has `!` and file commands too. Both programs avoid them, and their check scripts enforce that. The reason is not that the commands are bad. A program that can run a shell can do anything, and one that cannot is much easier to reason about. See also [[sandbox]] and [[least-privilege]].

- **Use it when:** you design an interface that runs something on someone's behalf. Ask what authority each caller carries, and give the callee no more.
- **Avoid it when:** you treat "it is only data" as a reason to stop thinking. Data is inert only until a consumer with authority acts on it.

**Read more:**

- [Capability-based security](https://en.wikipedia.org/wiki/Capability-based_security) (Wikipedia)
- [Principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege) (Wikipedia)
- [Confused deputy problem](https://en.wikipedia.org/wiki/Confused_deputy_problem) (Wikipedia)
