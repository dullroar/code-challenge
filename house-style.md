# House style

Use this guide for entry READMEs, *Learn Programming the Weird Way!* and its study guides.

## Voice

- Address the reader as "you". Use "we" for the maintainers when it matters who did the work.
- Prefer active verbs, direct sentences and concrete examples. Define terms and acronyms at first use. Use one term for each concept.
- Keep the book's playful lesson headings and its occasional jokes. Use full forms such as "cannot" in body prose. Fixed humor headings and direct quotations can keep their contractions.
- Use "repo" or "repository" in the book. Use "repository" in the study guides.

## Spelling and punctuation

- Use American spelling. Write "forever", "rerun", "reread", "reentrancy" and "redeclare".
- Write "built-in" and "read-only" as adjectives. Use "side effect" as a noun and "side-effecting" as an adjective. Use "non-zero", "callback", "backtracking" and the noun "lookup".
- Use sentence case in headings. "Program Flow" is the fixed name of the entry README section. Leave hand numbering out of lesson and goal headings. Exercise IDs such as B13 stay because readers and the answer key refer to them.
- Omit the serial comma in a simple list. Use it when it makes the grouping clearer. Use bullets or a table when the items are long.
- Put a period or comma outside a quoted fragment unless the punctuation belongs to the quotation. A full quoted sentence takes its own punctuation.
- Type straight quotation marks and apostrophes in Markdown. Use a new sentence to break up prose where a dash would go. Keep punctuation in proper names and literal examples.
- Write prose ranges with "to", as in "10 to 19". Spell out units in prose, as in "40 hours" and "8-hour day". Format literal notation and output as code. In arithmetic prose use × for multiplication.
- Use backticks for literal identifiers and entry IDs. In a chapter's opening entry list use repository paths such as `src/forth`. Use AWK, Make and Ex for the languages and lower-case executable names such as `awk`, `gawk`, `find`, `tar`, `ed`, `sed` and `busybox`.

## Challenge wording and evidence

- Keep the first card that takes the total over 40. The loop stops when the total passes 40. A total of exactly 40 continues. Say when a specific entry differs from that rule.
- Use three bold labels in prose. **guaranteed** refers to a named specification or documented API. **implementation-permitted** depends on a particular implementation, platform or version. **accidentally exploited** relies on unpromised behavior. Give the evidence and its scope in plain text. Use `accidentally-exploited` as the frontmatter value.
- Start entry `teaches:` text with a lowercase "that" clause. If the README has a **Teaches you:** line, match the frontmatter exactly.
- In a concept source, start the practical guidance with **Use it when:** and **Avoid it when:**. Use a more specific label if it adds information.

## Study guides

- Use Simplified Technical English for advanced readers. Prefer literal verbs, one idea per sentence and at most 25 words in a descriptive sentence. Use a list or table for a long series.
- Follow the [guide template](lessons/study-guides/README.md#how-every-guide-works). Start "The shared challenge" with the standard specification paragraph. Put entry-specific details and exceptions in the next paragraph.
- Start an Evidence question with a named speaker and a concrete claim. Use this pattern: A reviewer says, "The total stays at 40." Design a test that could fail.
- Keep build commands and contributor notes in [the build guide](lessons/book/README.md#building-the-study-guides).

## Source and publication

Edit entry README prose and metadata under `src/`, concept sources under `lessons/cs-source/` and the hand-written lesson or guide Markdown. Regenerate `lessons/cs/` and the marked generated blocks. The [build guide](lessons/book/README.md) has the commands for checking and rebuilding both volumes from those sources.
