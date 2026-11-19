"""Regression tests for the link rewrite shared by the two publications."""
from html.parser import HTMLParser
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from xml.etree import ElementTree as ET
from zipfile import ZipFile

import build


class Document(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.html = html
        self.links = []
        self.code = []
        self.in_code = False
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        if tag == "code":
            self.code.append("")
            self.in_code = True
        if tag == "a" and "href" in dict(attrs):
            self.links.append(dict(attrs)["href"])

    def handle_endtag(self, tag):
        if tag == "code":
            self.in_code = False

    def handle_data(self, data):
        if self.in_code:
            self.code[-1] += data


@unittest.skipUnless(shutil.which("pandoc"), "Pandoc is required for the publication pipeline")
class PublicationLinks(unittest.TestCase):
    def build(self, temp, texts, checking=True):
        with patch.object(build, "OUT", temp), patch.object(build, "ARTIFACTS", temp):
            return Path(build.build_documents(texts, "test", str(Path(build.HERE) / "metadata.yaml"),
                                              build.FRONT, "test.html", "test", checking=checking))

    def render(self, texts):
        with tempfile.TemporaryDirectory() as temp:
            html = self.build(temp, texts)
            markdown = (Path(temp) / "test.md").read_text(encoding="utf-8")
            return Document(html.read_text(encoding="utf-8")), markdown

    @staticmethod
    def c2(source):
        return source.split("## C2. Make the constraint real\n", 1)[1].split("## C3.", 1)[0]

    def test_c2_shell_survives_real_book_chapter(self):
        source = build.read("answers-key.md")
        code = self.c2(source).split("```bash\n", 1)[1].split("\n```", 1)[0]
        document, markdown = self.render({"answers-key.md": source})
        self.assertIn(code, markdown)
        self.assertTrue(any(code in block for block in document.code))
        self.assertIn(build.GITHUB + "lessons/solutions/c2-forth-rule-check.sh", document.links)

    @unittest.skipUnless(shutil.which("weasyprint") and shutil.which("gs"),
                         "WeasyPrint and Ghostscript are required for the PDF code check")
    def test_c2_shell_survives_pdf(self):
        chapter = "# C2. Make the constraint real\n" + self.c2(build.read("answers-key.md"))
        with tempfile.TemporaryDirectory() as temp:
            self.build(temp, {"answers-key.md": chapter}, checking=False)
            pdf = Path(temp) / "test.pdf"
            result = subprocess.run(["gs", "-q", "-dBATCH", "-dNOPAUSE", "-sDEVICE=txtwrite",
                                     "-sOutputFile=-", str(pdf)], check=True, capture_output=True, text=True)
        self.assertIn(r"'s/(^|[[:space:]])[\]([[:space:]].*)?$//'", result.stdout)

    def test_epub_front_matter_is_well_formed_and_appears_once(self):
        chapters = {"one.md": "# First chapter\n\nFirst.", "two.md": "# Second chapter\n\nSecond."}
        for front in (build.FRONT, str(Path(build.LESSONS) / "study-guides/front-matter.md")):
            with self.subTest(front=front), tempfile.TemporaryDirectory() as tmp:
                with patch.object(build, "OUT", tmp), patch.object(build, "ARTIFACTS", tmp), patch.object(build, "pdf_engine", return_value=None):
                    build.build_documents(chapters, "test", str(Path(build.HERE) / "metadata.yaml"),
                                          front, "test.html", "test", checking=False)
                with ZipFile(Path(tmp) / "test.epub") as epub:
                    pages = [ET.fromstring(epub.read(name)) for name in epub.namelist() if name.endswith(".xhtml")]
                classes = [node.get("class") for page in pages for node in page.iter()]
                self.assertEqual(classes.count("titlepage"), 1)
                self.assertEqual(classes.count("copyrightpage"), 1)

    def test_only_links_are_rewritten_in_guide_chapters(self):
        snippets = {
            "python": 'result = "[list](result)"',
            "forth": '.( [stack](word) )',
            "perl": 'print "[capture](return)";',
            "xml": '<TextBlock Text="[binding](value)" />',
            "regex": '^[ab](value)$',
        }
        fences = "\n\n".join(f"~~~~{lang}\n{code}\n~~~~" for lang, code in snippets.items())
        first = r"""# First guide

## Details

[`next guide`](two.md#details) and [local](#details).
[Book chapter](../../intro.md) and [repository index](../../README.md).
[Reference link][ref].

[ref]: ../../../src/apl/README.md

Literal \[escaped](value) and ``one ` [inline](code)``.

    [indented](code)

````text
```
[still](code)
## Details
````
""" + "\n" + fences + "\n"
        second = "# Second guide\n\n## Details\n\n[Back](one.md#details)\n"
        prefix = "study-guides/languages/"
        document, markdown = self.render({prefix + "one.md": first, prefix + "two.md": second})
        for code in (*snippets.values(), "[indented](code)", "```\n[still](code)\n## Details", "one ` [inline](code)"):
            with self.subTest(code=code):
                self.assertIn(code, markdown)
                self.assertTrue(any(code in block for block in document.code))
        body_links = [link for link in document.links if link.startswith(build.GITHUB)]
        self.assertCountEqual(body_links, [build.GITHUB + "lessons/intro.md",
                                           build.GITHUB + "src/apl/README.md"])
        self.assertIn('<a href="#details-1"><code>next guide</code></a>', document.html)
        self.assertIn('<a href="#details">local</a>', document.html)
        self.assertIn('<a href="#details">Back</a>', document.html)


if __name__ == "__main__":
    unittest.main()
