---
title: "Threat model"
chapter: 1
order: 10
---
A threat model answers four plain questions. What are we protecting? Who might attack it? How could they do it? What will we do about that? It exists because nobody can defend against "everything". You defend against a list, and the list is the threat model. Teams use it to decide where to spend review time and which protections to add. This repository turns the usual question around. The code is the thing we do *not* trust (a pull request from a stranger), and the thing we protect is the reviewer's machine. That is why [`CONTRIBUTING.md`](../../CONTRIBUTING.md) asks for a check script that runs on a throwaway system with no network.

- **Use it when:** you are about to run, install or review code you did not write, or when you design anything that accepts input.
- **Avoid it when:** you treat it as a document you write once. A threat model that nobody updates describes a system that no longer exists.

**Read more:**

- [Threat model](https://en.wikipedia.org/wiki/Threat_model) (Wikipedia)
- [RFC 3552, section 3: the Internet threat model](https://www.rfc-editor.org/rfc/rfc3552), a short, practical example from the IETF
- [Threat modeling](https://owasp.org/www-community/Threat_Modeling) (OWASP), a step-by-step guide
