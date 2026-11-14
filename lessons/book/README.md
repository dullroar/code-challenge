# Building the book

The whole of *Learn Programming the Weird Way!* builds into **one** document with [pandoc](https://pandoc.org):

```bash
python lessons/book/build.py            # writes learn-programming-the-weird-way.pdf and .epub in the repo root, and lessons/book/out/weird-way.html
python lessons/book/build.py --check    # builds the HTML and verifies every internal link resolves
```

- `chapters.txt` is the reading order. Add a chapter by adding its path there.
- `metadata.yaml` holds the title, author and table-of-contents settings.
- `build.py` concatenates the chapters and rewrites links first: a link to another chapter becomes an in-book anchor, a link to the web index becomes plain text, and a link to anything else in the repo (source files, `src/*/README.md`, `CHALLENGE.md`) becomes its GitHub URL. The chapters themselves stay ordinary GitHub-friendly Markdown.
- **PDF** is written to the repo root as `learn-programming-the-weird-way.pdf` and needs [WeasyPrint](https://weasyprint.org) (`uv tool install weasyprint` or `pipx install weasyprint`; it also needs the Pango library, which most Linux desktops and WSL images already have). Without it the script skips the PDF with a note; the EPUB and HTML are complete either way. The layout is `book.css`; fonts are DejaVu, whose mono face has the APL glyphs (`⍴ ⍳ ⎕`; see [Seeing the glyphs](../../src/apl/README.md#seeing-the-glyphs)).
- **Title and copyright pages** are in [`front-matter.md`](../front-matter.md) (plain HTML, inserted before the table of contents). Edit authors and the copyright line there.
- **Long code lines** (regexes, XAML, CMake) are hard-wrapped in the PDF by `wrap-code.lua` so nothing runs off the page. A line that continues ends in `↩` and the next line starts with `↪`. The Markdown source is untouched; HTML and EPUB reflow on their own.
- The PDF and EPUB in the repo root are committed; the HTML (and the intermediate `book.md`) go to `lessons/book/out/`, which is git-ignored.

To keep the book building: give every chapter exactly one `# ` title, link between chapters with relative `.md` links, and put exercises' answers in [`answers-key.md`](../answers-key.md).
