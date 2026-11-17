---
title: "Sandbox"
chapter: 1
order: 30
---
A sandbox is a restricted place where untrusted code can run without being trusted. The code gets a small, fenced area: little memory, no network, no access to your files. It exists because "read every line first" does not scale, and because a clever program can hide what it does. Every entry here runs in one. The Linux sandbox has no network, a read-only system and an unprivileged user. Windows entries use Windows Sandbox. See [`SANDBOX-SETUP.md`](../../SANDBOX-SETUP.md).

- **Use it when:** you run code you did not write, or code that handles input you did not write.
- **Avoid trusting it blindly:** sandboxes have escape bugs, and they cannot protect the data you hand in or take out. Use one layer among several (*defense in depth*), and still read the code.

**Read more:**

- [Sandbox (computer security)](https://en.wikipedia.org/wiki/Sandbox_(computer_security)) (Wikipedia)
- [Operating-system-level virtualization](https://en.wikipedia.org/wiki/Operating-system-level_virtualization), the idea behind containers (Wikipedia)
