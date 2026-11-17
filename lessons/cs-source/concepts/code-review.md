---
title: "Code review"
chapter: 1
order: 50
---
Code review means that another person reads your code before it is accepted. It exists because tests only check what you thought to test, while a reader may notice what you did not think of. Here the review has a specific shape: the README must contain a plain-English **How the stunt works** section, and reviewers (people and AI helpers) are asked to translate the code into plain words and list everything it can touch. If the reviewer cannot follow the entry, it is not merged, however clever it is.

- **Use it when:** for every change, and most of all for unusual code.
- **Avoid relying on it alone:** tired people miss things, and invisible characters hide from eyes. Combine review with automatic checks such as `sandbox/scope-check.sh`.

**Read more:**

- [Code review](https://en.wikipedia.org/wiki/Code_review) (Wikipedia)
