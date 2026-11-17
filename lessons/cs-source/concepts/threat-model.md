---
title: "Threat model"
chapter: 1
order: 10
---
A threat model answers four plain questions. What are we protecting? Who might attack it? How could they do it? What will we do about that? It exists because nobody can defend against "everything". You defend against a list, and the list is the threat model. Teams use it to decide where to spend review time and which protections to add. This repository turns the usual question around. The code is the thing we do *not* trust (a pull request from a stranger), and the thing we protect is the reviewer's machine. That is why [`CONTRIBUTING.md`](../../CONTRIBUTING.md) asks for a check script that runs on a throwaway system with no network.

- **Use it when:** you are about to run, install or review code you did not write, or when you design anything that accepts input.
- **Avoid it when:** you treat it as a document you write once. A threat model that nobody updates describes a system that no longer exists.

**Two examples from this repo, where the threat model had to change:**

- **"It's just markup."** The XAML entry ([[entry:xaml]]) directly inspired a second project, [xaml-write-and-run](https://github.com/dullroar/xaml-write-and-run). That project builds the shape of a command-and-control channel from nothing but `.xaml` files: one file writes the next file to disk, a later object in the same document loads and runs it, and the chain extends itself. A variant fetches its next instructions from the web. It rests on a well-known attack path (the classic `ObjectDataProvider` deserialization gadget), one that defenders already know and guard against. That is the lesson. Even on a well-guarded path, "it is only markup" is a false comfort: a trusted parser that reads attacker-influenced markup is running a program, so your threat model must treat markup as code.
- **"It's just a regex."** The Perl entry ([[entry:regex-perl]]) is a single pattern match. Inside that match, Perl code blocks seed the data, write to a database and print, and then the match returns false on purpose. If your threat model only worries about a regex running slowly (see [[redos]]), update it. A regex can also run code, and a pattern deserves the same care as any other program you accept.

**Read more:**

- [Threat model](https://en.wikipedia.org/wiki/Threat_model) (Wikipedia)
- [RFC 3552, section 3: the Internet threat model](https://www.rfc-editor.org/rfc/rfc3552), a short, practical example from the IETF
- [Threat modeling](https://owasp.org/www-community/Threat_Modeling) (OWASP), a step-by-step guide
