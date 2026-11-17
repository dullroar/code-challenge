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

## Metadata-driven chapters

Part of the book is **generated** from data, so it can never disagree with the code:

| Source (hand-written) | What it becomes |
| --- | --- |
| The YAML frontmatter at the top of every `src/*/README.md` (see [`CONTRIBUTING.md`](../../CONTRIBUTING.md#how-your-entry-plugs-into-the-book)) | The "In this repo" table under each concept, the comparative chapter, and the tables between `<!-- BEGIN GENERATED ... -->` markers in `goals.md`, `patterns.md` and the language pages |
| [`cs-source/concepts/<id>.md`](../cs-source/concepts/): one file per computer-science concept (`title`, `chapter`, `order`, then the prose) | A section in a chapter of `lessons/cs/`. The file name is the **tag** that entries use |
| [`cs-source/roles/<id>.md`](../cs-source/roles/): one file per "what plays the loop" role | A section of the comparative chapter (chapter 9) |
| [`cs-source/chapters/NN-name.md`](../cs-source/chapters/) and [`cs-source/index.md`](../cs-source/index.md) | The chapter introductions and the opener of the "By computer science concept" part |
| [`link-hosts.txt`](link-hosts.txt) | The only external hosts the prose may link to |

Run `python lessons/book/build.py --generate` to refresh the generated Markdown (the files in `lessons/cs/` and the marked blocks) without running pandoc. The generated files are **committed**, so GitHub readers see the full chapters, and `--check` fails if they are out of date or if any metadata is invalid (an unknown tag, a missing key, a link to a host that is not on the list).

In prose you can write `[[concept-id]]` to link to a concept, `[[entry:folder-name]]` to link to an entry, and `{{table:glance}}`, `{{table:evaluation}}` or `{{table:roles}}` for a generated table. A concept file's body should hold: one paragraph (why it exists, why it is used), a **Use it when** line, an **Avoid it when** line, and a **Read more** list. The generator adds the "In this repo" table itself.

### Links

External links must follow the policy in [`link-hosts.txt`](link-hosts.txt): Wikipedia first, then only sources that are long-lived and openly licensed or freely readable (IETF RFCs, OWASP, MDN). `build.py --check` enforces the host list offline. `build.py --check-links` fetches every external link in the prose and reports any that no longer load. It needs the network, so it is deliberately **not** part of `--check`; run it now and then, and before a release.

### Reproducible builds

The same sources give the same bytes. Every list is sorted, nothing reads the clock, and `SOURCE_DATE_EPOCH` is set from the `date:` line in [`metadata.yaml`](metadata.yaml), which also holds a fixed EPUB identifier. Bump `date:` when you publish new books. The check is simple: build twice with `--artifacts-dir` pointing at two empty folders and compare the files with `sha256sum`. They match for the same pandoc and WeasyPrint versions (tested with pandoc 3.1.3 and WeasyPrint on Ubuntu 24.04).

To keep the book building: give every chapter exactly one `# ` title, link between chapters with relative `.md` links, and put exercises' answers in [`answers-key.md`](../answers-key.md).
