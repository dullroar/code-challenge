#!/usr/bin/env python3
"""Build "Learn Programming the Weird Way!" as one book (EPUB, HTML and, if an engine exists, PDF).

    python lessons/book/build.py            # writes lessons/book/out/
    python lessons/book/build.py --check    # build HTML and verify every internal link resolves
    python lessons/book/build.py --check-links   # (network) verify every external link in the computer-science prose loads

Needs pandoc (https://pandoc.org). PDF additionally needs WeasyPrint (`uv tool install weasyprint`
or `pipx install weasyprint`). Without it, use the EPUB or HTML.

The chapters are ordinary Markdown files that link to each other and to the repo with relative
links, which is what you want on GitHub and is wrong in a single document. This script reads the
chapters in chapters.txt order and rewrites each relative link before pandoc sees it:
  * to another chapter           -> an in-book anchor (#heading-id)
  * to lessons/README.md         -> plain text (the web index is not part of the book)
  * to anything else in the repo -> its GitHub URL

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
import calendar, os, re, shutil, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cs
from pathlib import PurePosixPath

HERE = os.path.dirname(os.path.abspath(__file__))
LESSONS = os.path.dirname(HERE)
REPO = os.path.dirname(LESSONS)
OUT = os.path.join(HERE, "out")
GITHUB = "https://github.com/dullroar/code-challenge/blob/master/"

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
    """Repo-root-relative path (posix) of a relative link target found in `chapter`."""
    base = PurePosixPath("lessons") / PurePosixPath(chapter).parent
    parts = []
    for p in (base / target).parts:
        if p == "..":
            parts.pop()
        elif p != ".":
            parts.append(p)
    return "/".join(parts)

LINK = re.compile(r"(?<!!)\[([^\]]*)\]\(([^)\s]+)\)")
HEADING = re.compile(r"^(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$")

def headings(text):
    """Heading texts of a Markdown file, in order, skipping fenced code."""
    fenced = False
    for line in text.splitlines():
        if line.lstrip().startswith(("```", "~~~")):
            fenced = not fenced
        elif not fenced:
            m = HEADING.match(line)
            if m:
                yield m.group(2)

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

def rewrite(text, chapter, ids, maps):
    def book_id(ch, frag):
        return maps[ch].get(frag, frag)    # an unknown fragment is left alone; --check reports it
    def sub(m):
        label, target = m.group(1), m.group(2)
        if re.match(r"[a-z]+:", target):
            return m.group(0)
        if target.startswith("#"):                       # a link inside this chapter
            return f"[{label}](#{book_id(chapter, target[1:])})"
        path, _, frag = target.partition("#")
        full = normalize(chapter, path.replace("%20", " ")) if path else None
        if full is None:
            return m.group(0)
        if full == "lessons/README.md":
            return label
        rel = full[len("lessons/"):] if full.startswith("lessons/") else None
        if rel in ids:
            return f"[{label}](#{book_id(rel, frag) if frag else ids[rel]})"
        if full.endswith("/") or os.path.isdir(os.path.join(REPO, full)):
            return f"[{label}]({GITHUB.replace('/blob/', '/tree/')}{full})"
        return f"[{label}]({GITHUB}{full}{'#' + frag if frag else ''})"
    return LINK.sub(sub, text)

def build_markdown():
    global ID_MAPS
    names = chapters()
    texts = {c: read(c) for c in names}
    ID_MAPS = id_maps(texts)
    ids = {c: next(iter(ID_MAPS[c].values())) for c in texts}     # a chapter's id is its first heading's, the H1
    parts = [rewrite(t, c, ids, ID_MAPS) for c, t in texts.items()]
    os.makedirs(OUT, exist_ok=True)
    md = os.path.join(OUT, "book.md")
    with open(md, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n\n".join(parts))
    return md

ID_MAPS = {}

BOOK = "learn-programming-the-weird-way"
ARTIFACTS = REPO   # --artifacts-dir DIR writes the PDF and EPUB there instead (used to test reproducibility)
PDF_NAME = BOOK + ".pdf"
FRONT = os.path.join(LESSONS, "front-matter.md")
CSS = os.path.join(HERE, "book.css")

def artifacts_dir():
    if "--artifacts-dir" in sys.argv:
        return os.path.abspath(sys.argv[sys.argv.index("--artifacts-dir") + 1])
    return ARTIFACTS

def pdf_engine():
    # The title/copyright pages and the layout are HTML + CSS, so the PDF needs an HTML-to-PDF engine
    # (LaTeX engines would drop the front matter).
    for e in ("weasyprint",):
        if shutil.which(e):
            return e

def source_date_epoch():
    """Midnight UTC of `date:` in metadata.yaml; the only 'now' the build ever sees."""
    with open(os.path.join(HERE, "metadata.yaml"), encoding="utf-8") as f:
        m = re.search(r"^date:\s*(\d{4}-\d\d-\d\d)\s*$", f.read(), re.M)
    if not m:
        raise SystemExit("metadata.yaml needs a `date: YYYY-MM-DD` line (it fixes the build timestamp)")
    return str(calendar.timegm(time.strptime(m.group(1), "%Y-%m-%d")))

def generate(check):
    """Validate the metadata and refresh (or, with --check, verify) the generated files."""
    model = cs.Model()
    files = cs.generate_all(model)
    if model.problems:
        print("\n".join("PROBLEM " + p for p in model.problems))
        raise SystemExit(f"{len(model.problems)} metadata problem(s)")
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

def main():
    if "--check-links" in sys.argv:
        links()
    pandoc = shutil.which("pandoc")
    if not pandoc:
        raise SystemExit("pandoc not found (https://pandoc.org/installing.html)")
    generate("--check" in sys.argv)
    if "--generate" in sys.argv:        # refresh the generated Markdown only; skip pandoc
        return
    os.environ["SOURCE_DATE_EPOCH"] = source_date_epoch()
    md = build_markdown()
    base = ["pandoc", "-f", "gfm+gfm_auto_identifiers+yaml_metadata_block", "--metadata-file", os.path.join(HERE, "metadata.yaml"),
            "--wrap=none", "--toc", "--toc-depth=2", "--number-sections", "--include-before-body", FRONT, md]
    # Pandoc's gfm reader does not read a YAML block from --metadata-file as document metadata
    # for every writer, so pass it explicitly too.
    outs = [("html", ["-s", "--embed-resources", "--css", CSS, "-o", os.path.join(OUT, "weird-way.html")]),
            ("epub", ["--epub-title-page=false", "--css", CSS, "-o", os.path.join(artifacts_dir(), BOOK + ".epub")])]
    engine = pdf_engine()
    if engine and "--check" not in sys.argv:
        outs.append(("pdf", ["--pdf-engine=" + engine, "--css", CSS, "--lua-filter", os.path.join(HERE, "wrap-code.lua"),
                             "--metadata", "toc-title=Contents", "-o", os.path.join(artifacts_dir(), PDF_NAME)]))
    elif "--check" not in sys.argv:
        print("note: weasyprint not found (uv tool install weasyprint); skipping PDF")
    if "--check" in sys.argv:
        outs = outs[:1]
    for name, extra in outs:
        subprocess.run(base + extra, check=True)
        print("wrote", extra[-1])
    if "--check" in sys.argv:
        check(os.path.join(OUT, "weird-way.html"))

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
