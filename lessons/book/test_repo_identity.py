"""Keep the repository's old name (`code-challenge`) from creeping back in as a functional dependency.

The repository was renamed from dullroar/code-challenge to dullroar/learn-programming-the-weird-way. GitHub redirects the
old address, but a redirect is not a plan: nothing built or shipped from here may depend on it, and the published
PDFs and EPUBs must not link to it. This test scans every tracked text file for the hyphenated or underscored old name.
The phrase "code challenge" in ordinary English is not a match; only the identifier is.

ALLOWED is the whole list of exceptions. Each one is a deliberate decision, not an oversight:
  * `code-challenge-sandbox:local` is the name of the trusted build-toolchain image. It is an internal contract: the sandbox
    scripts, the Dockerfile linter's deny-by-default FROM rule, nine entry Dockerfiles and the Actions gate all agree on it.
    It names no repository and no URL, and renaming it would change the security boundary's allow-list for no gain.
  * `.cache/code-challenge/` is a per-user build cache directory. Renaming it would only force a one-time Rust rebuild.
  * `code-challenge entry` in lessons/tools/check-demo.sh is the ordinary phrase, in a comment.
Add to the list only with a reason.
"""
import re
import subprocess
import unittest
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OLD_NAME = re.compile(r"code[-_]challenge", re.I)
ALLOWED = [
    re.compile(r"code-challenge-sandbox"),          # internal Docker image tag (see above)
    re.compile(r"\.cache/code-challenge/"),         # local build cache directory
    re.compile(r"#.*any code-challenge entry"),     # shell comment, ordinary phrase
]
SKIP_SUFFIXES = {".pdf", ".epub", ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".zip", ".woff", ".woff2", ".ttf", ".jar"}
THIS = Path(__file__).resolve()


def tracked_files():
    out = subprocess.run(["git", "-C", str(REPO), "ls-files", "-z"], capture_output=True, check=True).stdout
    return [REPO / name for name in out.decode("utf-8").split("\0") if name]


def functional_matches(text):
    """Lines holding the old name, once the allowed uses are blanked out. Returns (line number, line) pairs."""
    found = []
    for number, line in enumerate(text.splitlines(), 1):
        rest = line
        for allowed in ALLOWED:
            rest = allowed.sub("", rest)
        if OLD_NAME.search(rest):
            found.append((number, line.strip()[:160]))
    return found


class Identity(unittest.TestCase):
    def test_no_tracked_source_depends_on_the_old_name(self):
        problems = []
        for path in tracked_files():
            if path.suffix.lower() in SKIP_SUFFIXES or path.name == "package-lock.json" or path == THIS or not path.is_file():
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            problems += [f"{path.relative_to(REPO).as_posix()}:{n}: {line}" for n, line in functional_matches(text)]
        self.assertEqual(problems, [], "the old repository name is back; use repo_links.py or the new name")

    def test_the_allow_list_still_allows_only_what_it_says(self):
        self.assertEqual(functional_matches("FROM code-challenge-sandbox:local AS build"), [])
        self.assertEqual(functional_matches('CARGO_TARGET_DIR="$HOME/.cache/code-challenge/x"'), [])
        self.assertEqual(functional_matches("# Validates any code-challenge entry's output."), [])
        for bad in ("https://github.com/dullroar/code-challenge/blob/master/x", "rootProject.name = 'code-challenge'",
                    "ghcr.io/dullroar/code-challenge:latest", "code_challenge_url", "FROM code-challenge-sandbox:local  # see dullroar/code-challenge"):
            with self.subTest(bad=bad):
                self.assertTrue(functional_matches(bad), bad)

    def test_published_epubs_do_not_link_to_the_old_name(self):
        checked = 0
        for epub in sorted(REPO.glob("*.epub")):
            with zipfile.ZipFile(epub) as z:
                for name in z.namelist():
                    if name.endswith((".xhtml", ".html", ".opf", ".ncx", ".xml", ".css")):
                        text = z.read(name).decode("utf-8", "replace")
                        self.assertIsNone(OLD_NAME.search(text), f"{epub.name}:{name} still mentions the old repository name")
                        checked += 1
        self.assertGreater(checked, 0, "no EPUB content was scanned")

    def test_published_pdfs_do_not_link_to_the_old_name(self):
        try:
            import fitz
        except ImportError:
            self.skipTest("PyMuPDF is required to read link annotations (requirements-pdf-lint.txt)")
        for pdf in sorted(REPO.glob("*.pdf")):
            with fitz.open(pdf) as doc:
                uris = [link.get("uri", "") for page in doc for link in page.get_links()]
                self.assertFalse([u for u in uris if OLD_NAME.search(u)], f"{pdf.name} links to the old repository name")
                for key, value in doc.metadata.items():
                    self.assertIsNone(OLD_NAME.search(value or ""), f"{pdf.name} metadata {key!r} mentions the old name")


if __name__ == "__main__":
    unittest.main()
