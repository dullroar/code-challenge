---
title: "Principle of least privilege"
chapter: 1
order: 40
---
The principle of least privilege says that every part of a system should get only the permissions it needs, and no more. It exists because every program has bugs. When a bug is exploited, the damage is limited to what that part was allowed to do. In this repository the runtime containers run as the unprivileged user `nobody`, with no network and a read-only file system. If an entry misbehaves, it has almost nothing to misbehave *with*.

- **Use it when:** always. It is the default for accounts, services, containers, API tokens and file permissions.
- **Avoid its failure mode:** if a task fails for lack of permission, grant exactly that permission. Do not "fix" it by running as root.

**Read more:**

- [Principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege) (Wikipedia)
- [RFC 4949: Internet Security Glossary](https://www.rfc-editor.org/rfc/rfc4949), which defines the term (search the page for "least privilege")
