#!/usr/bin/env python3
"""Build "Learn Programming the Weird Way!" as one book (EPUB, HTML and, if an engine exists, PDF).

    python lessons/book/build.py            # writes lessons/book/out/
    python lessons/book/build.py --release  # build and require PDF layout/content checks
    python lessons/book/build.py --check    # build HTML and verify every internal link resolves
    python lessons/book/build.py --check-links   # (network) verify every external link in the computer-science prose loads
    python lessons/book/build.py --check-diagrams  # FULL RENDER GATE: render every diagram, check each fits a printed page legibly, list orphans
    python lessons/book/build.py --orphans       # how every concept is grounded (entries, analogies, cross-cutting, exercise); fails on none

Needs pandoc (https://pandoc.org) and, for the diagrams, the pinned Mermaid CLI (`npm ci` in lessons/book/diagrams; see README.md here).
PDF additionally needs WeasyPrint (`uv tool install weasyprint`
or `pipx install weasyprint`). Without it, use the EPUB or HTML.

The chapters are ordinary Markdown files that link to each other and to the repo with relative
links, which is what you want on GitHub and is wrong in a single document. This script reads the
chapters in chapters.txt order and rewrites relative links in Pandoc's parsed document:
  * to another chapter           -> an in-book anchor (#heading-id)
  * to lessons/README.md         -> plain text (the web index is not part of the book)
  * to anything else in the repo -> its GitHub URL (repo_links.py holds the repository's address; the sources never do)

Parts of the book are generated from metadata (see cs.py): the entries' YAML frontmatter and the
files under lessons/cs-source/ become the "By computer science concept" chapters in lessons/cs/ and
the tables between `<!-- BEGIN GENERATED ... -->` markers. `build.py` regenerates them; `--check`
fails if the committed copies are stale or the metadata is invalid.

The build is deterministic: sorted inputs, no clock. SOURCE_DATE_EPOCH is taken from `date:` in
metadata.yaml, so the same sources give the same EPUB and PDF bytes (given the same pandoc and
WeasyPrint versions).

The title page and copyright page live in lessons/front-matter.md (plain HTML, inserted before the
table of contents). The PDF and EPUB are written to the repo root as learn-programming-the-weird-way.*.
"""
import calendar, json, os, re, shutil, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cs, diagrams, repo_links
from pathlib import PurePosixPath

HERE = os.path.dirname(os.path.abspath(__file__))
LESSONS = os.path.dirname(HERE)
REPO = os.path.dirname(LESSONS)
OUT = os.path.join(HERE, "out")
GITHUB = repo_links.blob_base()     # prefix of a published link to a file; the one canonical address lives in repo_links.py

def slug(heading):
    h = re.sub(r"`", "", heading.strip().lower())
    h = re.sub(r"[^\w\- ]", "", h)
    return h.replace(" ", "-")

def chapters():
    with open(os.path.join(HERE, "chapters.txt"), encoding="utf-8") as f:
        return [l.strip() for l in f if l.strip() and not l.startswith("#")]

def read(rel):
    with open(os.path.join(LESSONS, rel), encoding="utf-8") as f:
        return f.read().replace("\r\n", "\n")

def h1(text):
    for line in text.splitlines():
        if line.startswith("# "):
            return line[2:]
    raise SystemExit("chapter has no H1")

def normalize(chapter, target):
    """Repo-root-relative path (posix) of a relative link target, or None if outside the repo."""
    base = PurePosixPath("lessons") / PurePosixPath(chapter).parent
    parts = []
    for p in (base / target).parts:
        if p == "..":
            if not parts:
                return None
            parts.pop()
        elif p != ".":
            parts.append(p)
    return "/".join(parts)

def headings(text):
    """Heading texts of a Markdown file, in order, skipping fenced code."""
    return (item[2] for item in diagrams.scan(text) if item[0] == "heading")

def id_maps(texts):
    """Different chapters repeat heading titles ("Run it", "Gotchas worth knowing", "What did we just learn?").
    GitHub numbers repeats inside one file (x, x-1, x-2); pandoc numbers them across the whole book. A link
    written for the first must land on the second's chapter, so map  chapter -> {id in that file: id in the book}.
    Both sides follow the same rule: the first heading keeps its slug, later ones get -1, -2, ... in order."""
    in_book, maps = {}, {}
    for chapter, text in texts.items():
        in_file, m = {}, {}
        for h in headings(text):
            base = slug(h)
            n = in_file.get(base, 0); in_file[base] = n + 1
            k = in_book.get(base, 0); in_book[base] = k + 1
            m[base if n == 0 else f"{base}-{n}"] = base if k == 0 else f"{base}-{k}"
        maps[chapter] = m
    return maps

def link_target(target, chapter, ids, maps):
    """Resolve a parsed link. Return None to keep just its label."""
    def book_id(ch, frag):
        return maps[ch].get(frag, frag)    # an unknown fragment is left alone; --check reports it
    if not target or re.match(r"[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("/"):
        return target
    if target.startswith("#"):
        return "#" + book_id(chapter, target[1:])
    path, _, frag = target.partition("#")
    full = normalize(chapter, path.replace("%20", " "))
    if full is None:
        return target
    if full == "lessons/README.md":
        return None
    rel = full.removeprefix("lessons/") if full.startswith("lessons/") else None
    if rel in ids:
        return "#" + (book_id(rel, frag) if frag else ids[rel])
    if full.endswith("/") or os.path.isdir(os.path.join(REPO, full)):
        return repo_links.folder_url(full)
    return repo_links.file_url(full, frag)

def rewrite_links(nodes, chapter, ids, maps):
    """Walk Pandoc's nested inlines and blocks. Code nodes hold plain strings."""
    rewritten = []
    for node in nodes:
        if isinstance(node, list):
            node = rewrite_links(node, chapter, ids, maps)
        elif isinstance(node, dict) and isinstance(node.get("c"), list):
            node["c"] = rewrite_links(node["c"], chapter, ids, maps)
            if node["t"] == "Link":
                _, label, destination = node["c"]
                destination[0] = link_target(destination[0], chapter, ids, maps)
                if destination[0] is None:
                    rewritten.extend(label)
                    continue
        rewritten.append(node)
    return rewritten

def chapter_texts():
    return {c: read(c) for c in chapters()}

def where_of(chapter, text, first_line):
    """Where a diagram came from, for error messages: the README for a copied Program Flow section, else the chapter and line."""
    heading = None
    for it in diagrams.scan(text):
        if it[0] == "heading" and it[3] < first_line:
            heading = it[2]
    m = re.match(r"Program flow of `([^`]+)`", heading or "")
    if m:
        return f"src/{m.group(1)}/README.md, section '## {diagrams.SECTION}' (copied into lessons/{chapter})"
    return f"lessons/{chapter}:{first_line}" + (f" (under '{heading}')" if heading else "")

def collect_diagrams(texts):
    """Every distinct Mermaid source in the book's chapters -> where it came from."""
    wanted = {}
    for c, text in texts.items():
        for first, _, src in diagrams.mermaid_blocks(text):
            wanted.setdefault(src, where_of(c, text, first))
    return wanted

def render_figures(texts, required, prune_cache=True):
    """Render the book's diagrams (cached). Returns {source: Figure}, or None when there is no renderer and none is required.
    Never returns a partial result: any diagram that fails to render or cannot print legibly stops the build.
    `prune_cache=False` keeps cached figures that this document set does not use (the study guides share the cache with the book)."""
    wanted = collect_diagrams(texts)
    if not wanted:
        return {}
    renderer, why = diagrams.find_renderer()
    if renderer is None:
        if required:
            raise SystemExit(f"cannot render the {len(wanted)} diagram(s): {why}")
        print(f"NOTE    {len(wanted)} diagram(s) were NOT rendered ({why}). Their Mermaid syntax was not checked; "
              "run with the renderer installed for the full render gate (--check-diagrams).")
        return None
    figs, errors = diagrams.render_all(renderer, wanted)
    bad = errors + [f"{f.where}: the diagram prints at {f.points:.1f} pt after fitting one page ({f.scale:.0%} of its size; the minimum is "
                    f"{diagrams.MIN_SCALE:.0%}). Make it smaller or lay it out differently (LR instead of TD, fewer nodes, shorter labels)."
                    for f in figs.values() if hasattr(f, "scale") and f.scale < diagrams.MIN_SCALE]
    if bad:
        print("\n".join("DIAGRAM " + b for b in bad))
        raise SystemExit(f"{len(bad)} diagram problem(s)")
    hits = sum(1 for f in figs.values() if f.hit)
    print(f"diagrams: {len(figs)} rendered with {renderer.describe()} ({hits} from cache, {len(figs) - hits} drawn now)")
    gone = diagrams.prune(figs) if prune_cache else []
    if gone:
        print(f"diagrams: removed {len(gone)} stale cached file(s)")
    return figs

MARKDOWN_READER = "gfm+gfm_auto_identifiers+yaml_metadata_block"
CHAPTER_BOUNDARY = "<!-- publication chapter boundary -->"

def prepare_document(texts, figs, fmt, name, front=None):
    """Write the assembled Markdown and the parsed, link-resolved document for Pandoc's writers."""
    global ID_MAPS
    ID_MAPS = id_maps(texts)
    ids = {c: next(iter(ID_MAPS[c].values())) for c in texts}     # a chapter's id is its first heading's, the H1
    counter = [1]
    parts = [diagrams.embed(t, figs, fmt, counter) if figs else t for t in texts.values()]
    os.makedirs(OUT, exist_ok=True)
    stem = os.path.join(OUT, name)
    with open(stem + ".md", "w", encoding="utf-8", newline="\n") as f:
        f.write("\n\n".join(parts))

    # Parse as one document so Pandoc assigns repeated heading IDs globally.
    # Remove the boundary comments after using them to find each link's source chapter.
    source = "\n\n".join(f"{CHAPTER_BOUNDARY}\n\n{part}" for part in parts)
    parsed = subprocess.run(["pandoc", "-f", MARKDOWN_READER, "-t", "json"],
                            input=source, encoding="utf-8", stdout=subprocess.PIPE, check=True)
    document = json.loads(parsed.stdout)
    chapter_names = iter(texts)
    chapter = None
    blocks = []
    for block in document["blocks"]:
        if block["t"] == "RawBlock" and block["c"][1].strip() == CHAPTER_BOUNDARY:
            chapter = next(chapter_names, None)
            if chapter is None:
                raise SystemExit("unexpected publication chapter boundary")
        elif chapter is not None:
            blocks.extend(rewrite_links([block], chapter, ids, ID_MAPS))
        else:
            raise SystemExit("document content appeared before the first publication chapter boundary")
    if (missing := next(chapter_names, None)) is not None:
        raise SystemExit(f"missing publication chapter boundary for {missing}")
    if front is not None:
        # EPUB applies the include-before-body template to every chapter. A
        # leading raw block instead gives the front matter its own opening page.
        with open(front, encoding="utf-8") as f:
            blocks.insert(0, {"t": "RawBlock", "c": ["html", f.read()]})
    document["blocks"] = blocks
    return json.dumps(document, ensure_ascii=False)

ID_MAPS = {}

BOOK = "learn-programming-the-weird-way"
ARTIFACTS = REPO   # --artifacts-dir DIR writes the PDF and EPUB there instead (used to test reproducibility)
PDF_NAME = BOOK + ".pdf"
FRONT = os.path.join(LESSONS, "front-matter.md")
CSS = os.path.join(HERE, "book.css")

def artifacts_dir():
    if "--artifacts-dir" in sys.argv:
        d = os.path.abspath(sys.argv[sys.argv.index("--artifacts-dir") + 1])
        os.makedirs(d, exist_ok=True)
        return d
    return ARTIFACTS

def pdf_engine():
    # The title/copyright pages and the layout are HTML + CSS, so the PDF needs an HTML-to-PDF engine
    # (LaTeX engines would drop the front matter).
    for e in ("weasyprint",):
        if shutil.which(e):
            return e

def source_date_epoch(metadata=None):
    """Midnight UTC of `date:` in metadata.yaml (or the given metadata file); the only 'now' the build ever sees."""
    with open(metadata or os.path.join(HERE, "metadata.yaml"), encoding="utf-8") as f:
        m = re.search(r"^date:\s*(\d{4}-\d\d-\d\d)\s*$", f.read(), re.M)
    if not m:
        raise SystemExit("metadata.yaml needs a `date: YYYY-MM-DD` line (it fixes the build timestamp)")
    return str(calendar.timegm(time.strptime(m.group(1), "%Y-%m-%d")))

def counts(model):
    """Print the two numbers the root README shows near the top, and warn (never fail) if it is stale."""
    n = len(model.entries)
    langs = len({l for e in model.entries.values() for l in e["languages"]})
    print(f"counts for the root README: {n} challenges in {langs} languages")
    with open(os.path.join(REPO, "README.md"), encoding="utf-8") as f:
        m = re.search(r"\*\*(\d+) challenges in (\d+) languages\*\*", f.read())
    if not m or (int(m.group(1)), int(m.group(2))) != (n, langs):
        print(f"NOTE    the root README says {m.group(0) if m else 'nothing'}; update it to **{n} challenges in {langs} languages**")

def check_version():
    """The edition number must agree in metadata.yaml, on the title and copyright pages, and in VERSIONS.md."""
    with open(os.path.join(HERE, "metadata.yaml"), encoding="utf-8") as f:
        meta = f.read()
    v = re.search(r"^book-version:\s*(\d+)\s*$", meta, re.M)
    t = re.search(r'^title:\s*"(.+)"\s*$', meta, re.M)
    if not v or not t:
        raise SystemExit("metadata.yaml needs `book-version: N` and a quoted `title:` line")
    full = f"Learn Programming the Weird Way! v{v.group(1)}"
    problems = []
    if t.group(1) != full:
        problems.append(f"metadata.yaml: title is {t.group(1)!r}, expected {full!r} to match book-version")
    with open(FRONT, encoding="utf-8") as f:
        front = f.read()
    if f'<span class="book-version">v{v.group(1)}</span>' not in front or f"<p>{full}</p>" not in front:
        problems.append(f"front-matter.md: the title page and the copyright page must both say {full!r}")
    versions = os.path.join(HERE, "VERSIONS.md")
    if not os.path.isfile(versions) or not re.search(rf"^## v{v.group(1)}\b", open(versions, encoding="utf-8").read(), re.M):
        problems.append(f"lessons/book/VERSIONS.md needs a '## v{v.group(1)}' section saying what this edition added")
    if problems:
        print("\n".join("PROBLEM " + p for p in problems))
        raise SystemExit("the book version is inconsistent")
    print(f"book edition: {full}")

def generate(check):
    """Validate the metadata and refresh (or, with --check, verify) the generated files."""
    model = cs.Model()
    files = cs.generate_all(model)
    if model.problems:
        print("\n".join("PROBLEM " + p for p in model.problems))
        raise SystemExit(f"{len(model.problems)} metadata problem(s)")
    check_version()
    counts(model)
    if check:
        bad = cs.drift(files)
        if bad:
            print("\n".join("STALE   " + b for b in bad))
            raise SystemExit("generated files are out of date: run `python lessons/book/build.py`")
        print("metadata ok; generated files are up to date")
    else:
        cs.write_all(files)
        print(f"generated {len(files)} file(s)")

def links():
    """`--check-links`: do the external links in the prose still load? Needs the network; not part of --check."""
    model = cs.Model()
    if model.problems:
        raise SystemExit("\n".join(model.problems))
    bad = cs.check_links(model)
    print("\n".join("BROKEN  " + b for b in bad) or "all external links load")
    sys.exit(1 if bad else 0)

def orphans():
    model = cs.Model()
    if model.problems:
        print("\n".join("PROBLEM " + p for p in model.problems))
        raise SystemExit(f"{len(model.problems)} metadata problem(s)")
    lines, bad = cs.orphan_report(model)
    print("\n".join(lines))
    if bad:
        raise SystemExit(f"{bad} concept(s) have no entry, no cross-cutting reason and no exercise")

def diagram_gate():
    """`--check-diagrams`: the FULL RENDER GATE. Renders every diagram in the book with the pinned renderer and reports, for each,
    its family, natural size, the scale that fits it to one printed page and the printed size of its labels. Fails on a render
    error, an illegible figure, an orphaned cached file, or a second pass that does not come entirely from the cache."""
    model = cs.Model()
    if model.problems:
        print("\n".join("PROBLEM " + p for p in model.problems))
        raise SystemExit(f"{len(model.problems)} metadata problem(s)")
    texts = chapter_texts()
    wanted = collect_diagrams(texts)
    renderer, why = diagrams.find_renderer()
    if renderer is None:
        raise SystemExit(f"FULL RENDER GATE NOT RUN: {why}")
    figs, errors = diagrams.render_all(renderer, wanted)
    print(f"renderer: {renderer.describe()}")
    print(f"{'family':<16}{'natural px':>12}{'fit px':>12}{'scale':>7}{'label pt':>9}  where")
    bad = list(errors)
    for f in sorted(figs.values(), key=lambda f: f.where):
        if not hasattr(f, "scale"):
            continue
        flag = "" if f.scale >= diagrams.MIN_SCALE else "  <-- TOO SMALL"
        print(f"{f.family:<16}{f'{f.w:.0f}x{f.h:.0f}':>12}{f'{f.pw}x{f.ph}':>12}{f.scale:>7.2f}{f.points:>9.1f}  {f.where}{flag}")
        if flag:
            bad.append(f"{f.where}: labels would print at {f.points:.1f} pt")
    stale = diagrams.orphans(figs)
    if stale:
        print(f"note: {len(stale)} cached file(s) belong to no current diagram (an older text or style); a normal build deletes them")
    again, _ = diagrams.render_all(renderer, wanted)
    misses = [f.where for f in again.values() if not f.hit]
    if misses:
        bad += [f"second pass was not served from the cache: {m}" for m in misses]
    families = sorted({f.family for f in figs.values()})
    if bad:
        print("\n".join("DIAGRAM " + b for b in bad))
        raise SystemExit(f"FULL RENDER GATE FAILED: {len(bad)} problem(s)")
    print(f"FULL RENDER GATE PASSED: {len(figs)} diagram(s) rendered in {len(families)} families ({', '.join(families)}); "
          f"every one fits a printed page at >= {diagrams.MIN_SCALE:.0%} scale; a second pass came entirely from the cache")

def lint_written_pdf(path, release):
    """Use the same standalone checker for both documents, with the actual output path."""
    folder = os.path.join(OUT, "pdf-lint", os.path.splitext(os.path.basename(path))[0])
    command = [sys.executable, os.path.join(HERE, "lint_pdf.py"), path,
               "--json", os.path.join(folder, "report.json"), "--annotate-dir", os.path.join(folder, "pages")]
    if release:
        command.append("--release")
    status = subprocess.run(command).returncode
    if status and release:
        raise SystemExit(status)
    if status:
        print("note: PDF lint returned", status, "(use --release to gate a full build)")


def release_mode():
    release = "--release" in sys.argv
    if release and any(flag in sys.argv for flag in ("--check", "--check-diagrams", "--generate", "--orphans", "--check-links")):
        raise SystemExit("--release requires a full PDF build")
    return release


def main():
    release_mode()
    if "--orphans" in sys.argv:
        orphans()
        return
    if "--check-links" in sys.argv:
        links()
    if "--check-diagrams" in sys.argv:
        generate(True)
        diagram_gate()
        return
    pandoc = shutil.which("pandoc")
    if not pandoc:
        raise SystemExit("pandoc not found (https://pandoc.org/installing.html)")
    generate("--check" in sys.argv)
    if "--generate" in sys.argv:        # refresh the generated Markdown only; skip pandoc
        return
    checking = "--check" in sys.argv
    texts = chapter_texts()
    html = build_documents(texts, BOOK, os.path.join(HERE, "metadata.yaml"), FRONT, "weird-way.html", "book", checking)
    if checking:
        check(html)

def write_front(front, md_stem):
    """The title and copyright pages with the repository's address filled in, written beside the other build output."""
    with open(front, encoding="utf-8") as f:
        text = repo_links.fill_placeholders(f.read())
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, md_stem + "-front.html")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return path

def build_documents(texts, stem, metadata, front, html_name, md_stem, checking, prune_cache=True):
    """Build one document set from `texts` ({chapter path relative to lessons/: Markdown}): standalone HTML in lessons/book/out/
    and, unless `checking`, `<stem>.epub` and `<stem>.pdf` in the artifacts directory. The book and the study guides both call this,
    so they share one Pandoc command line, one stylesheet, one diagram renderer and one reproducibility rule. Returns the HTML path."""
    release = release_mode()
    engine = None if checking else pdf_engine()
    if release and not engine:
        raise SystemExit("release PDF build requires weasyprint")
    os.environ["SOURCE_DATE_EPOCH"] = source_date_epoch(metadata)
    figs = render_figures(texts, required=not checking, prune_cache=prune_cache)     # a full build needs the renderer; --check only notes its absence
    document = prepare_document(texts, figs, "svg", md_stem)
    base = ["pandoc", "-f", "json", "--metadata-file", metadata, "--wrap=none", "--toc", "--toc-depth=2",
            "--number-sections"]
    front = write_front(front, md_stem)
    front_option = ["--include-before-body", front]
    outs = [("html", document, front_option + ["-s", "--embed-resources", "--css", CSS, "-o", os.path.join(OUT, html_name)])]
    if not checking:
        # The EPUB gets PNGs (every e-reader draws them); the PDF and HTML get SVG, which is sharper and scales to the page.
        epub_document = prepare_document(texts, figs, "png", md_stem + "-epub", front=front)
        outs.append(("epub", epub_document, ["--epub-title-page=false", "--css", CSS, "-o", os.path.join(artifacts_dir(), stem + ".epub")]))
        if engine:
            outs.append(("pdf", document, front_option + ["--pdf-engine=" + engine, "--css", CSS, "--lua-filter", os.path.join(HERE, "wrap-code.lua"),
                                     "--metadata", "toc-title=Contents", "-o", os.path.join(artifacts_dir(), stem + ".pdf")]))
        else:
            print("note: weasyprint not found (uv tool install weasyprint); skipping PDF")
    for name, src, extra in outs:
        subprocess.run(base + extra, input=src, encoding="utf-8", check=True)
        print("wrote", extra[-1], flush=True)
        if name == "pdf":
            lint_written_pdf(extra[-1], release)
    return os.path.join(OUT, html_name)

def check(html_path):
    with open(html_path, encoding="utf-8") as f:
        html = f.read()
    ids = set(re.findall(r'\bid="([^"]+)"', html))
    bad = sorted({h for h in re.findall(r'href="#([^"]+)"', html) if h not in ids})
    for b in bad:
        print("BROKEN internal link: #" + b)
    # Our prediction of the ids pandoc gives repeated headings must match what pandoc really wrote, or a link
    # to "Run it" in one chapter could silently land in another.
    wrong = sorted({i for m in ID_MAPS.values() for i in m.values() if i not in ids})
    for w in wrong:
        print("ID MISMATCH: expected pandoc to produce #" + w)
    dup = sorted({i for i in re.findall(r'\bid="([^"]+)"', html) if re.findall(r'\bid="([^"]+)"', html).count(i) > 1})
    for d in dup:
        print("DUPLICATE id in the book: #" + d)
    n = sum(len(m) for m in ID_MAPS.values())
    print("internal links ok" if not (bad or wrong or dup) else f"{len(bad)} broken, {len(wrong)} mismatched, {len(dup)} duplicate")
    print(f"{n} headings checked; every repeated title has its own id")
    sys.exit(1 if (bad or wrong or dup) else 0)

if __name__ == "__main__":
    main()
