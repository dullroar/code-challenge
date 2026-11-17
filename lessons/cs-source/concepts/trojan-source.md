---
title: "Trojan Source: characters you cannot see"
chapter: 1
order: 60
---
Trojan Source is an attack on the human reviewer. Unicode includes characters that you cannot see: zero-width spaces, and "bidirectional" controls that change the visual order of text. Code can *look* harmless to a person and *mean* something else to the compiler. Researchers at Cambridge described the attack in 2021 (CVE-2021-42574). This repository defends against it in a simple way: `sandbox/scope-check.sh` rejects hidden and direction-changing characters in a pull request. Visible Unicode is fine. APL needs `⍴` and `⍳`.

- **Use the defense when:** you accept code from other people. Scan for invisible characters automatically.
- **Avoid over-correcting:** do not ban all non-ASCII text. Ban the characters that have no visible shape.

**Read more:**

- [Trojan Source](https://en.wikipedia.org/wiki/Trojan_Source) (Wikipedia)
- [Bidirectional text](https://en.wikipedia.org/wiki/Bidirectional_text) (Wikipedia)
- [RFC 3629: UTF-8](https://www.rfc-editor.org/rfc/rfc3629), the encoding that carries all of this text
