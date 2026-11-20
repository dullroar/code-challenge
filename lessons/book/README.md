# Building the book

The whole of *Learn Programming the Weird Way!* builds into **one** document with [pandoc](https://pandoc.org):

```bash
python lessons/book/build.py            # writes learn-programming-the-weird-way.pdf and .epub in the repo root, and lessons/book/out/weird-way.html
python lessons/book/build.py --check    # builds the HTML and verifies every internal link resolves
python lessons/book/build.py --check-diagrams   # the full render gate for the Program Flow diagrams (see Diagrams below)
```

- `chapters.txt` is the reading order. Add a chapter by adding its path there.
- `metadata.yaml` holds the title, the edition number (`book-version`), author and table-of-contents settings. The book is numbered from v3 on: bump `book-version`, the title, the title page in `front-matter.md` and add a section to [`VERSIONS.md`](VERSIONS.md) (what that edition added). `build.py` fails if they disagree.
- `build.py` assembles the chapters and rewrites links after Pandoc parses the Markdown. Code samples stay literal. A link to another chapter becomes an in-book anchor, a link to the web index becomes plain text, and a link to anything else in the repo (source files, `src/*/README.md`, `CHALLENGE.md`) becomes its GitHub URL. The chapters themselves stay ordinary GitHub-friendly Markdown.

- **Why the sources use relative links and the PDF and EPUB use absolute ones.** On GitHub and in a clone a relative link always works, and it keeps working when the repository is renamed or forked. A PDF or EPUB has no repository around it, so its links to source files must be full URLs. [`repo_links.py`](repo_links.py) is the only place that knows the repository's address: a fixed canonical default (`https://github.com/dullroar/learn-programming-the-weird-way`, branch `master`), so the same sources give the same bytes on any machine. The build never reads `git remote`. A fork can set `REPOSITORY_WEB_BASE` (and `REPOSITORY_BRANCH`) to publish its own links. The title and copyright pages use the placeholders `{{REPOSITORY_WEB_URL}}` and `{{REPOSITORY_WEB_LABEL}}`, which the build fills in. If the repository is renamed again, change `DEFAULT_WEB_BASE` there, rebuild the publications and commit them. [`test_repo_links.py`](test_repo_links.py) tests the mapping, and [`test_repo_identity.py`](test_repo_identity.py) fails if the old repository name returns anywhere except a short, reviewed list (the internal sandbox image tag `code-challenge-sandbox:local` and a per-user Rust build cache directory), including in the published PDFs and EPUBs.
- **PDF** is written to the repo root as `learn-programming-the-weird-way.pdf` and needs [WeasyPrint](https://weasyprint.org) (`uv tool install weasyprint` or `pipx install weasyprint`; it also needs the Pango library, which most Linux desktops and WSL images already have). Without it the script skips the PDF with a note; the EPUB and HTML are complete either way. The layout is `book.css`; fonts are DejaVu, whose mono face has the APL glyphs (`⍴ ⍳ ⎕`; see [Seeing the glyphs](../../src/apl/README.md#seeing-the-glyphs)).
- **Title and copyright pages** are in [`front-matter.md`](../front-matter.md) (plain HTML, inserted before the table of contents). EPUB puts this material on its opening page. Edit authors and the copyright line in the source.
- **Long code lines** (regexes, XAML, CMake) are hard-wrapped in the PDF by `wrap-code.lua` so nothing runs off the page. A line that continues ends in `↩` and the next line starts with `↪`. The Markdown source is untouched; HTML and EPUB reflow on their own.
- The PDF and EPUB in the repo root are committed. The HTML and assembled Markdown go to `lessons/book/out/`, which is git-ignored.
- **The study guides are a separate document set.** [`lessons/study-guides/`](../study-guides/README.md) holds hand-written guides that build with `python lessons/study-guides/build.py` into `learn-programming-the-weird-way-study-guides.pdf` and `.epub` beside the book's. That script imports this one (`build_documents`), so the link rewriting, diagram rendering, Pandoc call, stylesheet and reproducibility rule are shared and not copied. The guides are not in `chapters.txt`, and the book only links to them. [`study_guides.py`](study_guides.py) checks them and [`test_study_guides.py`](test_study_guides.py) tests those checks.

## PDF release gate

Every full build lints the PDF it just wrote. Both the book and the study guides use the same hook, including with `--artifacts-dir`. Run the build with `--release` to require WeasyPrint, a complete lint scan and zero errors. Without `--release`, the post-build lint reports diagnostics and the build continues. The HTML-only `--check` routes need no PDF lint dependencies.

```bash
# From the repository root, in the Python environment used for the builds.
python -m pip install -r lessons/book/requirements-pdf-lint.txt

# Check finished PDFs without invoking Pandoc, Mermaid or WeasyPrint.
python lessons/book/lint_pdf.py --release \
  --json lessons/book/out/pdf-lint/both.json \
  --annotate-dir lessons/book/out/pdf-lint/pages \
  learn-programming-the-weird-way.pdf \
  learn-programming-the-weird-way-study-guides.pdf

# Run the same ordered gates as CI, with the build and diagram tools installed.
python lessons/book/build.py --check
python lessons/study-guides/build.py --check
python lessons/book/build.py --check-diagrams
python lessons/book/test_pdf_lint.py
python lessons/book/build.py --release
python lessons/study-guides/build.py --release
```

The standalone CLI uses the publication filenames to select the book and study-guide sentinels. Use `--profile book` or `--profile study-guides` for a renamed copy, or `--profile letter` for geometry on a fixture. Its exit codes are **0** for a complete scan with zero errors, **1** for a completed scan with errors and **2** for an incomplete scan or invocation failure. Warnings are advisory in every mode. `--release` also rasterizes every page at low resolution and fails on a rasterizer exception or an entirely white render with substantial detected content. The [PDF release workflow](../../.github/workflows/pdf-release-gate.yml) builds both documents from source and uploads the lint diagnostics on failure.

The linter derives Letter size and its content rectangle from `book.css`. It checks the MediaBox and CropBox within 0.1 pt, the page edge within 1 pt, and the content margin within 1.5 pt. The placement tolerances allow small variations in glyph metrics. The initial scan also exposed a table and two highlighted listings with measurable intrusions well above these tolerances. Title, copyright, TOC and index content use the regular margins. The footer exemption requires the physical page number, the expected font and size, and a centered position in the footer.

| Rules | Evidence |
| --- | --- |
| PDF-001 through PDF-005 | Scan completion, page geometry, glyph and displayed raster placement bounds. |
| PDF-006 | Advisory vector overrun, using path bounds and enclosing clip bounds. |
| PDF-007 | Empty publication page when no body or drawing objects are detected. Ambiguous cases and generic Letter fixtures are advisory. |
| PDF-008 and PDF-009 | Advisory overlap by relative box area, a sparse page, caption with no nearby figure evidence, or matching table grids with an open edge across a page break. |
| PDF-010 | Named selectable-text sentinels for Mermaid comparisons and Forth labels, APL glyphs, regex/sed literals and selected Forth and Make wraps. The fixture renders literal comparisons and Mermaid's `#gt;` through the pinned SVG route. Its wrap comparison removes only adjacent paired arrows from a deliberately mid-token break, where no source space was lost. |
| PDF-011 | Release rasterization and diagnostic preview failures. |

Path bounds approximate visible ink. Clip boxes approximate clipping, and content discarded before PDF serialization may be undetectable. Raster measurements describe placement even when masking affects the visible pixels. The selectable-text checks cover the named strings in [the sentinel list](pdf_sentinels.py). Outlined glyphs and semantic row boundaries require visual inspection or evidence from the source. Figure scale remains the responsibility of `--check-diagrams`. A separate `qpdf` structural check is optional and outside this gate.

Keep diagnostics under the ignored `lessons/book/out/`. The build hook stores a report per document in `out/pdf-lint/<stem>/report.json` and writes affected pages to its `pages/` subdirectory. A preview shows the allowed content region in teal, marks measured boxes, and lists the rule and displacement in a side legend. The default cap is 20 console findings and 12 preview pages per PDF, with up to 12 marked items per PNG. `--verbose` prints every finding and produces a preview for every affected page. JSON always includes all findings.

JSON schema version 1 has top-level `documents`, `diagnostics`, `errors`, `warnings` and `exit_status` fields. Each document records its basename, profile, `page_count`, `pages_scanned`, `complete`, `page_failures`, `content_checks` and `findings`. Each finding records the rule, severity, message, one-based physical page (or null), excerpt, `box`, `allowed_box`, `overflow_pt` and a preview filename when available. Boxes are normally unrotated, crop-relative points in `[left, top, right, bottom]` order. Page-geometry findings display the measured and expected page boxes. For an overlap, `allowed_box` is the other object's measured box. A document-level check can have null geometry. Documents sort by basename and findings by page, severity, rule and geometry. Reports contain no timestamps or absolute input paths.

For an intentional exception, specify the profile, rule and observable object signature, record why the position is expected, and test both it and a nearby genuine failure. The development dependency file pins PyMuPDF and Pillow. This repository uses the AGPL distribution of PyMuPDF as an installed local and CI tool, and ships the WeasyPrint publications and lint source without the PyMuPDF package. PyMuPDF remains available under AGPL or Artifex's commercial terms. [PyMuPDF licensing](https://pymupdf.io/licensing)

## Diagrams

Every entry's README has a `## Program Flow` section with one Mermaid diagram (the contract is in [`CONTRIBUTING.md`](../../CONTRIBUTING.md#program-flow-a-picture-of-the-machine)). The diagram is text in Git, and the build turns it into a figure. The shared "what the challenge does" picture is a fenced `mermaid` block in [`intro.md`](../intro.md), and the chapter on events has one too. **Any** `mermaid` fence in a chapter is rendered.

**How it flows.** `src/<entry>/README.md` (the source of truth) is read by [`diagrams.py`](diagrams.py) with a fence-aware Markdown scanner, not a regex. The `## Program Flow` section is copied by `build.py --generate` into the generated block `How each program runs` of the lesson page named by the entry's `lesson:` key (the page keeps the Mermaid fence, so GitHub draws it too). At book-build time every `mermaid` fence is rendered once to SVG and once to PNG by Mermaid CLI and replaced by an HTML `<figure>` with a caption (`accTitle`) and alt text (`accDescr`) before pandoc runs. The PDF and HTML use the SVG (vector, scaled to fit one page); the EPUB uses the PNG (every reader draws it). There is one renderer and no second mechanism.

**Setup (once, no root needed).** You need Node and a Chromium. Mermaid CLI is pinned in [`diagrams/package.json`](diagrams/package.json) and [`package-lock.json`](diagrams/package-lock.json) (`@mermaid-js/mermaid-cli` 12.2.0; tested with Node 24 and Chrome for Testing 147):

```bash
cd lessons/book/diagrams
PUPPETEER_SKIP_DOWNLOAD=1 npm ci          # installs Mermaid CLI into diagrams/node_modules (git-ignored)
# a Chromium: any of these is found automatically, or set MERMAID_CHROME=/path/to/chrome
npx playwright install chromium-headless-shell    # -> ~/.cache/ms-playwright   (or: apt install chromium)
```

After that the build works offline. If Chromium's sandbox does not work in your container, set `MERMAID_NO_SANDBOX=1`; the diagrams are text from this repository, rendered with Mermaid's `securityLevel: strict`.

**What is checked, and when.**

| Command | Needs the renderer? | What it checks |
| --- | --- | --- |
| `build.py --check` | No (it says so if it was missing) | Every entry has exactly one `## Program Flow` heading, spelled exactly so, with one `mermaid` block, `accTitle` and `accDescr`, no HTML tags, no sub-headings, and the two bold lead-ins. Generated lesson pages are up to date. If the renderer is present it also renders and checks every diagram. **Without the renderer this is a syntax-and-structure check only, and the build says so** |
| `build.py --check-diagrams` | Yes | **The full render gate.** Renders every diagram, prints its family, natural size, the scale that fits it to a Letter page and the printed size of its labels, and fails on a render error (with the entry, the heading and Mermaid's message), on a diagram that would print under 70% scale (labels under 8.4 pt), or on a second pass that is not entirely served from the cache |
| `build.py` | Yes | Renders (or reuses) the figures, deletes cached files that no diagram uses, builds the PDF, EPUB and HTML. It never writes a blank figure or an unrendered code block: any failure stops it |

**Cache.** Figures live in `lessons/book/out/diagrams/<key>.svg` and `.png` (`out/` is git-ignored). The key is a hash of the diagram text, the Mermaid CLI version, the Chrome version, the PNG scale and [`diagrams/mermaid-config.json`](diagrams/mermaid-config.json). Edit one diagram and only its figure is drawn again. Change the renderer, the browser or the style and all of them are. A clean checkout renders everything once (about 15 seconds). The committed PDF and EPUB contain the figures.

**Page fit.** `diagrams.py` computes each figure's printed size (`FIT_W`, `FIT_H` in CSS pixels, 1 px = 1/96 inch) from the page geometry in `book.css`, so a figure always fits one page with its heading and caption, and never splits. If a diagram is so large that scaling would shrink its labels below the minimum, the build fails and tells you which README to fix. The fixes are in the contribution rules: fewer nodes, shorter labels, hexagons for decisions.

**Style.** [`diagrams/mermaid-config.json`](diagrams/mermaid-config.json): the `neutral` theme, DejaVu Sans (the book's font), dark lines on white, SVG text labels (`htmlLabels: false`, because WeasyPrint does not draw HTML inside SVG), no color that carries meaning.

**A light PDF.** Two things keep the figures cheap for PDF viewers, and an early v4 PDF had neither. Mermaid's default `neo` look gives every node a gradient border and a blurred shadow, so the config says `"look": "classic"` (flat and vector, still crisp). And Mermaid centers every label and draws label backgrounds half transparent, which WeasyPrint writes as a PDF *transparency group* each. Edge and Chrome (PDFium) draw every group into an off-screen bitmap, and a book with thousands of them showed white pages for a long time, even on pages without a figure, because all pages shared one resource list naming every group. [`diagrams/flatten-text.mjs`](diagrams/flatten-text.mjs) runs on each SVG after Mermaid: the same Chrome measures each label, the script moves it to the equivalent left-anchored position and turns single-shape `opacity` into `fill-opacity`, and it fails the figure if any label moved by more than half a pixel. The PNG for the EPUB is untouched. The result: the PDF went from about 7,500 objects and 4.3 MB to about 400 objects and 2.1 MB, with no transparency groups. `test_diagrams.py` checks that no centered text is left, and (when WeasyPrint is installed) that a figure turns into a PDF without groups. If you see `a label moved by`, the figure uses a text feature the script does not handle yet; the message names the file.

**Failure modes.** `cannot render ... Mermaid CLI is not installed`: run the setup above. `no Chromium found`: set `MERMAID_CHROME`. A Mermaid parse error is printed with the README path and the line Mermaid complains about (a `;` inside a sequence-diagram message is a common cause). PDF viewers differ: we checked the PDF with MuPDF; Ghostscript at some resolutions drops parts of a WeasyPrint SVG, which is a Ghostscript problem.

**Pseudocode.** There is no pseudocode section on purpose. No standard defines one that fits imperative, lazy, rewriting, self-modifying and event-driven programs without erasing the difference. Pseudocode may appear in an entry's prose when it helps, labeled as such, and it never replaces the diagram.

**Adding or changing a diagram.** Edit the `## Program Flow` section of the entry's README, run `python lessons/book/build.py --generate` (it refreshes the lesson page copy), then `--check-diagrams`. Look at the figure. There is nothing else to edit by hand. `python lessons/book/test_diagrams.py` tests the extractor, the cache keys and the contract.

## Metadata-driven chapters

Part of the book is **generated** from metadata and author-written Markdown. The freshness check verifies agreement with those inputs. Review the labels against the implementation and its tests before changing the metadata.

| Source (hand-written) | What it becomes |
| --- | --- |
| The YAML frontmatter at the top of every `src/*/README.md` (see [`CONTRIBUTING.md`](../../CONTRIBUTING.md#how-your-entry-plugs-into-the-book)) | The "In this repo" table under each concept, the comparative chapter, and the tables between `<!-- BEGIN GENERATED ... -->` markers in `goals.md`, `patterns.md` and the language pages |
| [`cs-source/concepts/<id>.md`](../cs-source/concepts/): one file per computer-science concept (`title`, `chapter`, `order`, then the prose) | A section in a chapter of `lessons/cs/`. The file name is the **tag** that entries use |
| [`cs-source/roles/<id>.md`](../cs-source/roles/): one file per "what plays the loop" role | A section of the comparative chapter (chapter 9) |
| [`cs-source/chapters/NN-name.md`](../cs-source/chapters/) and [`cs-source/index.md`](../cs-source/index.md) | The chapter introductions and the opener of the "By computer science concept" part |
| [`link-hosts.txt`](link-hosts.txt) | The only external hosts the prose may link to |

**How a concept is grounded.** Every concept page needs something real behind it, and the build fails if it has nothing. An entry can relate to a concept in three ways, set in its frontmatter: `tags` (it **demonstrates** the idea), `analogies` (it resembles the idea) or `counterexamples` (it shows what the idea is not). The concept's "In this repo" table has a column that says which. Some facts are true of *every* entry, and a maintainer states them once in the concept's own frontmatter instead of tagging every entry: `applies-to: all` (or `has:machine`, for the entries that name their machine) with a required `applies-because:` sentence. A concept that no entry demonstrates at all can instead point at a focused exercise with `exercise: exercises.md#anchor`. The prose "no entry uses this yet" is rejected: the generator now says what is behind each concept. `python lessons/book/build.py --orphans` prints the grounding of every concept and fails if one has none. `python lessons/book/test_cs.py` tests the rules.

Run `python lessons/book/build.py --generate` to refresh the generated Markdown (the files in `lessons/cs/` and the marked blocks) without running pandoc. The generated files are **committed**, so GitHub readers see the full chapters, and `--check` fails if they are out of date or if any metadata is invalid (an unknown tag, a missing key, a link to a host that is not on the list).

In prose you can write `[[concept-id]]` to link to a concept, `[[entry:folder-name]]` to link to an entry, and `{{table:glance}}`, `{{table:evaluation}}` or `{{table:roles}}` for a generated table. A concept file's body should hold: one paragraph (why it exists, why it is used), a **Use it when** line, an **Avoid it when** line, and a **Read more** list. The generator adds the "In this repo" table itself.

### Links

External links must follow the policy in [`link-hosts.txt`](link-hosts.txt): Wikipedia first, then only sources that are long-lived and openly licensed or freely readable (IETF RFCs, OWASP, MDN). `build.py --check` enforces the host list offline. `build.py --check-links` fetches every external link in the prose and reports any that no longer load. It needs the network, so it is deliberately **not** part of `--check`; run it now and then, and before a release.

### Reproducible builds

The same sources give the same bytes. Every list is sorted, nothing reads the clock, and `SOURCE_DATE_EPOCH` is set from the `date:` line in [`metadata.yaml`](metadata.yaml), which also holds a fixed EPUB identifier. Bump `date:` when you publish new books. The check is simple: build twice with `--artifacts-dir` pointing at two empty folders and compare the files with `sha256sum`. They match for the same pandoc and WeasyPrint versions (tested with pandoc 3.1.3 and WeasyPrint on Ubuntu 24.04). That includes a build from an empty diagram cache (`lessons/book/out/diagrams/`): the cache only saves time, and the committed PDFs and EPUBs do not depend on it.

That last point took a fix. Mermaid draws some node shapes, above all the stadium `A(["..."])`, with rough.js, which jitters each outline with random numbers. Unseeded, every fresh draw of such a diagram differed from the last. Many concept pages use stadiums, so a clean checkout rebuilt different bytes, and the committed files could be reproduced only from the exact cache that had built them. [`diagrams/mermaid-config.json`](diagrams/mermaid-config.json) now sets `handDrawnSeed`, which makes the jitter the same on every draw. Keep it. `test_diagrams.py` draws every node shape twice from an empty cache and fails if the SVG or PNG changes. If you change the seed, the Mermaid CLI or Chrome version, or the config, every diagram is drawn again and the PDFs and EPUBs change: rebuild all six and commit them together.

### When an entry is added (for maintainers)

After merging a new entry: add its row to the root `README.md` table, add any new tag, role or language to `lessons/cs-source/`, run `python lessons/book/build.py` (it regenerates the chapters, the index and the PDF and EPUB), and update the bold **"N challenges in M languages"** line at the top of the root `README.md`. The build prints the right numbers and warns when that line is stale. It is the one count that is kept by hand.

To keep the book building: give every chapter exactly one `# ` title, link between chapters with relative `.md` links, and put exercises' answers in [`answers-key.md`](../answers-key.md).

### Guide impact review

Compare a proposed revision with its base before building both volumes. The report uses entry and concept IDs, source links and the indirect dependencies in [`guide-dependencies.json`](guide-dependencies.json). It is a reading list for the reviewer. Add missing dependencies when a guide teaches a mechanism without naming the edited source. If a changed file has no affected guides, record an empty list for that path in the dependency file after review.

```bash
python lessons/book/guide_impact.py master                    # compare master with HEAD
python lessons/book/guide_impact.py master --worktree         # include uncommitted edits
python lessons/book/guide_impact.py master --check-review review.json
```

Once you've checked a guide's traces, exercises, boundaries and source citations, record its printed token in a JSON object keyed by guide path, such as `languages/apl.md`. The check rejects missing tokens and tokens made stale by an edit to the guide or the relevant sources. Record the supporting run or source evidence in the review. Rebuild the book and the separate study guides together.

## Building the study guides

The guides build as their own HTML, PDF and EPUB set, separate from the book. The book's PDF and EPUB do not contain them.

```bash
python lessons/study-guides/build.py --check   # lint the guides, build the HTML, verify every internal link
python lessons/study-guides/build.py           # write the PDF and EPUB next to the book's, in the repository root
python lessons/book/test_study_guides.py       # the tests: template, diagrams, links, index
```

The outputs are `learn-programming-the-weird-way-study-guides.pdf` and `.epub`. The reading order is [`chapters.txt`](../study-guides/chapters.txt). The build reuses the book's own pipeline ([`lessons/book/build.py`](build.py)) for link rewriting, diagrams, Pandoc and reproducibility. [`lessons/book/study_guides.py`](study_guides.py) checks each guide for the template, for placeholder text, for diagrams that match their source, and for links.

The [PDF release gate](README.md#pdf-release-gate) checks the guide PDF after each full build. Pass `--release` to make the PDF and its lint scan required.

**Diagrams.** A Program Flow diagram in a guide is copied verbatim from `src/<entry>/README.md` and marked with `<!-- diagram-source: src/<entry>/README.md#program-flow -->`. The build fails if a copy has drifted. A new diagram is allowed only when it shows a relationship no source diagram shows (cross-language state placement, a lazy-demand trace, a transaction boundary or an authority boundary), and is marked `<!-- diagram-new: kind - why -->`.

**External links.** A guide may link only to the hosts in [`lessons/book/link-hosts.txt`](link-hosts.txt). Wikipedia comes first. The GNU Project manuals (`www.gnu.org/software/`) were added for the guides, because a claim about an implementation needs its manual.

## Building the curriculum

The curriculum is one hand-written file, [`docs/curriculum.md`](../../docs/curriculum.md): a 16-week course plan that points at the book chapters, the study guides and the exercises without changing them. It builds as its own HTML, PDF and EPUB, separate from the book and the study guides.

```bash
python lessons/curriculum/build.py --check   # lint the curriculum, build the HTML, verify every internal link
python lessons/curriculum/build.py           # write curriculum.pdf and curriculum.epub in the repository root
python lessons/book/test_curriculum.py       # the tests: plan, diagram, links, house style, page limit
```

[`lessons/curriculum/build.py`](../curriculum/build.py) imports this build's `build_documents`, as the study-guide build does, so the link rewriting, Mermaid rendering, Pandoc call, stylesheet, reproducibility rule and PDF lint are shared. Its own checks cover weeks 1 to 16 once each, the one diagram with `accTitle` and `accDescr`, links and hosts, house style (25 words at most in a prose sentence, no contractions, no dashes) and a limit of 10 PDF pages. The title page and metadata are in [`lessons/curriculum/`](../curriculum/). When the book's edition changes, `companion-to` in `metadata.yaml` must change too, after someone reviews the curriculum.
