# Building the book

The whole of *Learn Programming the Weird Way!* builds into **one** document with [pandoc](https://pandoc.org):

```bash
python lessons/book/build.py            # writes lessons/book/out/weird-way.html and .epub (and .pdf if a PDF engine exists)
python lessons/book/build.py --check    # builds the HTML and verifies every internal link resolves
```

- `chapters.txt` is the reading order. Add a chapter by adding its path there.
- `metadata.yaml` holds the title, author and table-of-contents settings.
- `build.py` concatenates the chapters and rewrites links first: a link to another chapter becomes an in-book anchor, a link to the web index becomes plain text, and a link to anything else in the repo (source files, `src/*/README.md`, `CHALLENGE.md`) becomes its GitHub URL. The chapters themselves stay ordinary GitHub-friendly Markdown.
- **PDF** needs a PDF engine that pandoc can find (`xelatex`, `lualatex`, `typst`, `weasyprint`, `wkhtmltopdf`). Without one the script skips the PDF with a note; the EPUB and HTML are complete either way. APL glyphs (`⍴ ⍳ ⎕`) need a font that has them (see [Seeing the glyphs](../../src/apl/README.md#seeing-the-glyphs)).
- Output goes to `lessons/book/out/`, which is git-ignored.

To keep the book building: give every chapter exactly one `# ` title, link between chapters with relative `.md` links, and put exercises' answers in [`answers-key.md`](../answers-key.md).
