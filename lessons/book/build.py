#!/usr/bin/env python3
"""Build "Learn Programming the Weird Way!" as one book (EPUB, HTML and, if an engine exists, PDF).

    python lessons/book/build.py            # writes lessons/book/out/
    python lessons/book/build.py --check    # build HTML and verify every internal link resolves

Needs pandoc (https://pandoc.org). PDF additionally needs a PDF engine pandoc can find
(xelatex, lualatex, typst, weasyprint...). Without one, use the EPUB or HTML.

The chapters are ordinary Markdown files that link to each other and to the repo with relative
links, which is what you want on GitHub and is wrong in a single document. This script reads the
chapters in chapters.txt order and rewrites each relative link before pandoc sees it:
  * to another chapter           -> an in-book anchor (#heading-id)
  * to lessons/README.md         -> plain text (the web index is not part of the book)
  * to anything else in the repo -> its GitHub URL
"""
import os, re, shutil, subprocess, sys
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

def rewrite(text, chapter, ids):
    def sub(m):
        label, target = m.group(1), m.group(2)
        if re.match(r"[a-z]+:", target) or target.startswith("#"):
            return m.group(0)
        path, _, frag = target.partition("#")
        full = normalize(chapter, path.replace("%20", " ")) if path else None
        if full is None:
            return m.group(0)
        if full == "lessons/README.md":
            return label
        rel = full[len("lessons/"):] if full.startswith("lessons/") else None
        if rel in ids:
            return f"[{label}](#{frag or ids[rel]})"
        if full.endswith("/") or os.path.isdir(os.path.join(REPO, full)):
            return f"[{label}]({GITHUB.replace('/blob/', '/tree/')}{full})"
        return f"[{label}]({GITHUB}{full}{'#' + frag if frag else ''})"
    return LINK.sub(sub, text)

def build_markdown():
    names = chapters()
    texts = {c: read(c) for c in names}
    ids = {c: slug(h1(t)) for c, t in texts.items()}
    parts = [rewrite(t, c, ids) for c, t in texts.items()]
    os.makedirs(OUT, exist_ok=True)
    md = os.path.join(OUT, "book.md")
    with open(md, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n\n".join(parts))
    return md

def pdf_engine():
    for e in ("xelatex", "lualatex", "typst", "weasyprint", "wkhtmltopdf", "pdflatex"):
        if shutil.which(e):
            return e

def main():
    pandoc = shutil.which("pandoc")
    if not pandoc:
        raise SystemExit("pandoc not found (https://pandoc.org/installing.html)")
    md = build_markdown()
    base = ["pandoc", "-f", "gfm+gfm_auto_identifiers+yaml_metadata_block", "--metadata-file", os.path.join(HERE, "metadata.yaml"),
            "--wrap=none", "--toc", "--toc-depth=2", "--number-sections", md]
    # Pandoc's gfm reader does not read a YAML block from --metadata-file as document metadata
    # for every writer, so pass it explicitly too.
    outs = [("html", ["-s", "--embed-resources", "-o", os.path.join(OUT, "weird-way.html")]),
            ("epub", ["-o", os.path.join(OUT, "weird-way.epub")])]
    engine = pdf_engine()
    if engine and "--check" not in sys.argv:
        outs.append(("pdf", ["--pdf-engine=" + engine, "-V", "geometry:margin=2.2cm", "-o", os.path.join(OUT, "weird-way.pdf")]))
    elif "--check" not in sys.argv:
        print("note: no PDF engine found (xelatex, lualatex, typst, weasyprint...); skipping PDF")
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
    print("internal links ok" if not bad else f"{len(bad)} broken")
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
