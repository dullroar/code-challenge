#!/usr/bin/env python3
"""Build the curriculum (docs/curriculum.md) as its own document set: one HTML file, one EPUB and one PDF.

    python lessons/curriculum/build.py            # writes curriculum.pdf and curriculum.epub in the repository root
    python lessons/curriculum/build.py --release  # build and require the PDF layout and content checks
    python lessons/curriculum/build.py --check    # lint the curriculum, build the HTML and verify every internal link resolves
    python lessons/curriculum/build.py --artifacts-dir DIR   # write the PDF and EPUB to DIR (used to test reproducibility)

The curriculum is one hand-written Markdown file. This script does not write prose. It only
  * checks it with check_curriculum() below (links, the one diagram, the plan, the house style and the length), and
  * gives it to the book's own pipeline, lessons/book/build.py, which does the link rewriting, the Mermaid rendering, the Pandoc call,
    the stylesheet and the reproducibility rule. Nothing is copied from that file; it is imported and called, so a fix there fixes
    every document set.

A link from the curriculum to a chapter, a study guide or an exercise becomes its GitHub URL, because those are different documents.
"""
import importlib.util, os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LESSONS = os.path.dirname(HERE)
REPO = os.path.dirname(LESSONS)
BOOKDIR = os.path.join(LESSONS, "book")
SOURCE = os.path.join(REPO, "docs", "curriculum.md")
sys.path.insert(0, BOOKDIR)
import diagrams, study_guides

STEM = "curriculum"
HTML = "curriculum.html"
CHAPTER = "../docs/curriculum.md"     # relative to lessons/, as the book's link rewriting expects
WEEKS = 16
TARGET_PAGES, MAX_PAGES = 8, 12       # the plan: aim for about 8 pages in the whole PDF, never more than 12 (the rubric and the log template added two)
MAX_WORDS = 25                        # Simplified Technical English: at most 25 words in a descriptive sentence

def load_book_build():
    sys.dont_write_bytecode = True      # importing the book's build must not rewrite a __pycache__ file
    spec = importlib.util.spec_from_file_location("book_build", os.path.join(BOOKDIR, "build.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

def prose_sentences(text):
    """The sentences of running prose: no code, tables, headings, comments or links' targets. A list item counts as prose."""
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    out = []
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith(("|", "#")):
            continue
        line = re.sub(r"^\s*(?:[-*]|\d+\.)\s+", "", line)
        line = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", line)       # keep the label, drop the target
        line = re.sub(r"[*_`]", "", line)
        out += [s.strip() for s in re.split(r"(?<=[.!?])\s+", line) if s.strip()]
    return out

def check_curriculum(text=None, repo=REPO):
    """Problems (a list of strings) in docs/curriculum.md."""
    text = study_guides.read(SOURCE) if text is None else text
    where = "docs/curriculum.md"
    problems = []
    add = lambda msg: problems.append(f"{where}: {msg}")

    # the plan: every week of a standard semester appears once, in order
    weeks = [int(m.group(1)) for m in re.finditer(r"^\| (\d+) \|", text, re.M)]
    if weeks != list(range(1, WEEKS + 1)):
        add(f"the week-by-week table must list weeks 1 to {WEEKS} once each, in order; it lists {weeks}")

    # the diagram: exactly one, described for readers who cannot see it
    blocks = list(diagrams.mermaid_blocks(text))
    if len(blocks) != 1:
        add(f"expected exactly one Mermaid diagram, found {len(blocks)}")
    for _, _, src in blocks:
        for key in ("accTitle", "accDescr"):
            if f"{key}:" not in src:
                add(f"the diagram needs '{key}:'")
        if not re.search(r"flowchart|stateDiagram", src.split("\n", 1)[0]):
            add("the diagram must be a flowchart or a state diagram")

    # printed chapter numbers: "Ch N" must be the chapter's number in the printed book (chapters.txt order, numbered from 1)
    order = [l.strip() for l in study_guides.read(os.path.join(BOOKDIR, "chapters.txt")).splitlines() if l.strip() and not l.startswith("#")]
    for m in re.finditer(r"\[Ch (\d+)\]\(\.\./lessons/(cs/[^)#]+)", text):
        want = order.index(m.group(2)) + 1 if m.group(2) in order else None
        if want != int(m.group(1)):
            add(f"'Ch {m.group(1)}' links to {m.group(2)}, which is chapter {want} of the printed book")
    # the diagram's arrows must land on a node, not on the box around the nodes
    for _, _, src in blocks:
        for box in re.findall(r"^\s*subgraph\s+(\w+)", src, re.M):
            if re.search(r"(?:-->|---)\s*(?:\|[^|]*\|\s*)?" + box + r"\b", src) or re.search(r"\b" + box + r"\s*(?:-->|---)", src):
                add(f"the diagram has an arrow to or from the box '{box}'; point arrows at a node inside it")

    # links: relative ones resolve to a file and a heading, external ones use an allowed host over https
    stripped = re.sub(r"```.*?```", "", text, flags=re.S)
    base = os.path.dirname(SOURCE)
    for m in study_guides.LINK.finditer(stripped):
        target = m.group(2)
        if re.match(r"[a-z][a-z0-9+.-]*:", target):
            continue
        path, _, frag = target.partition("#")
        full = os.path.normpath(os.path.join(base, path)) if path else SOURCE
        if not os.path.exists(full):
            add(f"link to a missing file: {target}")
        elif frag and full.endswith(".md") and frag not in study_guides.anchors(study_guides.read(full)):
            add(f"link to a missing heading: {target}")
    allowed = study_guides.hosts(repo)
    for url in study_guides.external_urls(stripped):
        u = re.match(r"https://([^/]+)(/.*)?$", url)
        if not u:
            add(f"external links must use https: {url}")
        elif u.group(1) not in allowed and not any("/" in h and (u.group(1) + (u.group(2) or "")).startswith(h) for h in allowed):
            add(f"host {u.group(1)!r} is not in lessons/book/link-hosts.txt: {url}")

    # house style (house-style.md): Simplified Technical English, plain punctuation
    for s in prose_sentences(text):
        n = len(s.split())
        if n > MAX_WORDS:
            add(f"sentence of {n} words (the limit is {MAX_WORDS}): {s[:70]}...")
        if re.search(r"\b\w+n't\b|\b(?:it|we|you|they|that|there)'(?:s|re|ve|ll|d)\b", s, re.I):
            add(f"contraction in body prose: {s[:70]}...")
    for ch, name in (("—", "em dash"), ("–", "en dash"), ("“", "curly quote"), ("’", "curly apostrophe")):
        if ch in text:
            add(f"contains a {name}; house style types straight quotes and breaks the sentence instead of using a dash")
    if re.search(r"\b(?:TODO|TBD|lorem ipsum)\b", text, re.I):
        add("contains placeholder text")

    # the book's edition: when it changes, someone must review the curriculum against it
    meta = study_guides.read(os.path.join(HERE, "metadata.yaml"))
    book = study_guides.read(os.path.join(BOOKDIR, "metadata.yaml"))
    title = re.search(r'^title:\s*"(.+)"', book, re.M).group(1)
    companion = re.search(r'^companion-to:\s*"(.+)"', meta, re.M).group(1)
    if companion != title:
        add(f"metadata.yaml says it accompanies {companion!r}, but the book is now {title!r}: review the curriculum, then update `companion-to` and front-matter.md")
    return problems

def pdf_pages(path):
    """Page count of a PDF, from Ghostscript."""
    gs = shutil.which("gs")
    if not gs:
        return None
    out = subprocess.run([gs, "-q", "-dNODISPLAY", "-dNOSAFER", "-dBATCH", "-c", f"({path}) (r) file runpdfbegin pdfpagecount = quit"],
                         stdout=subprocess.PIPE, encoding="utf-8", check=True).stdout
    return int(out.strip())

def main():
    book = load_book_build()
    book.release_mode()
    checking = "--check" in sys.argv
    problems = check_curriculum()
    if problems:
        print("\n".join("PROBLEM " + p for p in problems))
        raise SystemExit(f"{len(problems)} curriculum problem(s)")
    print("curriculum: plan, diagram, links and house style ok")
    if not shutil.which("pandoc"):
        raise SystemExit("pandoc not found (https://pandoc.org/installing.html)")
    texts = {CHAPTER: study_guides.read(SOURCE)}
    html = book.build_documents(texts, STEM, os.path.join(HERE, "metadata.yaml"), os.path.join(HERE, "front-matter.md"),
                                HTML, "curriculum", checking, prune_cache=False)
    if checking:
        book.check(html)
        return
    pdf = os.path.join(book.artifacts_dir(), STEM + ".pdf")
    pages = pdf_pages(pdf) if os.path.exists(pdf) else None
    if pages is not None:
        print(f"curriculum.pdf: {pages} pages (title page and contents included; the plan is about {TARGET_PAGES} in all and at most {MAX_PAGES})")
        if pages > MAX_PAGES:
            raise SystemExit(f"curriculum.pdf has {pages} pages; the limit is {MAX_PAGES}")

if __name__ == "__main__":
    main()
