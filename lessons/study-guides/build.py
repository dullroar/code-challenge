#!/usr/bin/env python3
"""Build the study guides as their own document set: one HTML file, one EPUB and one PDF.

    python lessons/study-guides/build.py            # writes learn-programming-the-weird-way-study-guides.pdf and .epub in the repo root
    python lessons/study-guides/build.py --check    # lint the guides, build the HTML and verify every internal link resolves
    python lessons/study-guides/build.py --check-links   # (network) verify every external link in the guides loads
    python lessons/study-guides/build.py --artifacts-dir DIR   # write the PDF and EPUB to DIR (used to test reproducibility)

The guides are hand-written Markdown (see lessons/study-guides/README.md). This script does not write prose. It only
  * checks them with lessons/book/study_guides.py (the template, the diagrams, the links), and
  * gives them to the book's own pipeline, lessons/book/build.py, which does the link rewriting, the Mermaid rendering, the Pandoc call, the
    stylesheet and the reproducibility rule. Nothing is copied from that file; it is imported and called, so a fix there fixes both.

Reading order is chapters.txt (paths relative to lessons/study-guides/). A link from one guide to another becomes an anchor in the
standalone document. A link to the book, to an exercise or to a source file becomes its GitHub URL, because the book is a different
document. The existing book (lessons/book/chapters.txt) does not contain the guides.
"""
import importlib.util, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LESSONS = os.path.dirname(HERE)
BOOKDIR = os.path.join(LESSONS, "book")
sys.path.insert(0, BOOKDIR)
import study_guides

def load_book_build():
    sys.dont_write_bytecode = True      # importing the book's build must not rewrite a __pycache__ file
    # Loaded by path: this file is also called build.py, so `import build` would find itself.
    spec = importlib.util.spec_from_file_location("book_build", os.path.join(BOOKDIR, "build.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

STEM = "learn-programming-the-weird-way-study-guides"
HTML = "study-guides.html"

def main():
    book = load_book_build()
    book.release_mode()
    if "--check-links" in sys.argv:        # (network) every external link in the guides must load; separate from the build, like the book's
        bad = study_guides.check_external()
        print("\n".join("BROKEN  " + b for b in bad) or "all external links in the study guides load")
        sys.exit(1 if bad else 0)
    checking = "--check" in sys.argv
    problems = study_guides.check_all()
    if problems:
        print("\n".join("PROBLEM " + p for p in problems))
        raise SystemExit(f"{len(problems)} study-guide problem(s)")
    print("study guides: template, diagrams, links and index ok")
    import shutil
    if not shutil.which("pandoc"):
        raise SystemExit("pandoc not found (https://pandoc.org/installing.html)")
    # The book's pipeline wants chapter paths relative to lessons/ so that its link rewriting finds the right neighbours.
    texts = {f"study-guides/{c}": study_guides.read(os.path.join(HERE, c)) for c in study_guides.manifest(HERE)}
    html = book.build_documents(texts, STEM, os.path.join(HERE, "metadata.yaml"), os.path.join(HERE, "front-matter.md"),
                                HTML, "study-guides", checking, prune_cache=False)
    if checking:
        book.check(html)

if __name__ == "__main__":
    main()
