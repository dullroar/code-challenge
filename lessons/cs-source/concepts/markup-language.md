---
title: "Markup languages"
chapter: 5
order: 80
---
A markup language is text with annotations that describe its structure: HTML, XML, Markdown, XAML. It exists so that people and tools can share one document, and so that content stays separate from presentation. XAML describes a tree of user-interface objects, and a loader creates the objects. The danger is a format that can name *types* and *methods*. Then loading a file means running code chosen by the file's author. That is the idea behind many deserialization attacks, and it is exactly what [[entry:xaml]] does on purpose: all the behavior of that program lives in one markup file and runs while the file is parsed.

- **Use it when:** you describe documents or data that both humans and tools must read.
- **Avoid:** letting a document choose arbitrary types or call arbitrary methods. Use an allowlist.

**Read more:**

- [Markup language](https://en.wikipedia.org/wiki/Markup_language) (Wikipedia)
- [XAML](https://en.wikipedia.org/wiki/XAML) (Wikipedia)
- [XML external entity attack](https://en.wikipedia.org/wiki/XML_external_entity_attack) (Wikipedia)
- [Deserialization cheat sheet](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html) (OWASP), on loading data safely
