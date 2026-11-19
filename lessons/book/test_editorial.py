"""Cross-volume editorial regressions. Run from any directory with Python 3."""
from collections import Counter
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

import build
import cs
import guide_impact
import study_guides

ROOT = Path(cs.REPO)
ASIDE = "Weird Execution, Indirect Results and Data"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def aside_count(book, guides):
    return sum(text.count(ASIDE) for text in book), sum(text.count(ASIDE) for text in guides)


class Editorial(unittest.TestCase):
    def test_opening_aside_occurs_once_in_the_book_only(self):
        guide_files = [f"lessons/study-guides/{path}" for path in study_guides.manifest(study_guides.GUIDES)]
        book = list(build.chapter_texts().values()) + [read("lessons/front-matter.md")]
        guides = [read(path) for path in guide_files + ["lessons/study-guides/front-matter.md"]]
        self.assertIn(ASIDE, read("lessons/intro.md").split("## What the challenge does")[0])
        self.assertEqual(aside_count(book, guides), (1, 0))
        self.assertEqual(aside_count(book + [ASIDE], guides), (2, 0))
        self.assertEqual(aside_count(book, guides + [ASIDE]), (1, 1))

    def test_count_and_assurance_tally_follow_the_model(self):
        model = cs.Model()
        files = cs.generate_all(model)
        index = files["index.md"].split("## Index of entries", 1)[1]
        roles = cs.blk_roles(model, cs.Links(model, "cs/09-comparative-case-studies.md"), lambda text: text)
        for text, marker in [(index, r"^- "), (roles, r"^\| ")]:
            entries = re.findall(marker + r"\[`([^`]+)`\]\([^)]*src/[^)]*\)", text, re.M)
            self.assertEqual(Counter(entries), Counter(model.entries.keys()))
        root_count = re.search(r"\*\*(\d+) challenges in (\d+) languages\*\*", read("README.md"))
        self.assertEqual(tuple(map(int, root_count.groups())), (
            len(model.entries), len({language for e in model.entries.values() for language in e["languages"]}),
        ))
        guide = read("lessons/study-guides/concepts/portability-abstraction-and-cost.md")
        assurance = Counter(entry["assurance"] for entry in model.entries.values())
        self.assertEqual(
            {label.replace(" ", "-"): int(count) for count, label in re.findall(
                r"\*\*(\d+)\*\* (?:entries )?are (guaranteed|implementation-permitted|accidentally exploited)", guide
            )},
            assurance,
        )

    def test_apl_explanations_match_the_four_array_assignments(self):
        source = read("src/apl/timecards.apl")
        assignments = re.findall(r"^(Drawn|Hours|Totals|Kinds)←(.+?)(?:\s+⍝.*)?$", source, re.M)
        self.assertEqual(assignments, [
            ("Drawn", "(10-⎕IO)+?5⍴10"),
            ("Hours", "Drawn↑⍨1++/40≥+\\Drawn"),
            ("Totals", "+\\Hours"),
            ("Kinds", "(≢Hours)⍴Categories"),
        ])
        for path in ["src/apl/README.md", "lessons/languages/apl.md", "lessons/study-guides/languages/apl.md"]:
            text = read(path)
            with self.subTest(path=path):
                self.assertIn("four named array assignments", text.lower())
                self.assertRegex(text, r"five (rolls|draws)")
                self.assertIn("up to five", text)
                self.assertNotIn("seven slots", text)

    @unittest.skipUnless(shutil.which("weasyprint") and shutil.which("gs"), "needs WeasyPrint and Ghostscript")
    def test_a_table_row_moves_together_across_pdf_pages(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            html = directory / "rows.html"
            html.write_text("""<html><meta charset="utf-8"><style>
                @page { size: 400px 210px; margin: 16px; }
                table { break-inside: auto; }
                td { font: 12px/22px sans-serif; }
                </style><body>
                <table><thead><tr><th>Heading</th><th>Meaning</th><th>Evidence</th></tr></thead>
                <tbody><tr><td>One<br>Two<br>Three<br>Four</td><td></td><td></td></tr>
                <tr><td>RowStarts<br>MiddleOne<br>MiddleTwo<br>MiddleThree<br>RowEnds</td>
                <td>Explanation</td><td>Witness</td></tr></tbody></table></body></html>
                """, encoding="utf-8")
            pdf = directory / "rows.pdf"
            subprocess.run(["weasyprint", "-q", "-s", str(ROOT / "lessons/book/book.css"), str(html), str(pdf)], check=True)
            subprocess.run(["gs", "-q", "-dBATCH", "-dNOPAUSE", "-sDEVICE=txtwrite",
                            f"-sOutputFile={directory}/page-%d.txt", str(pdf)], check=True, capture_output=True)
            pages = sorted(directory.glob("page-*.txt"))
            self.assertEqual(len(pages), 2)
            first, second = (page.read_text(encoding="utf-8") for page in pages)
            self.assertIn("Four", first)
            self.assertNotIn("Witness", first)
            for term in ("Heading", "RowStarts", "RowEnds", "Explanation", "Witness"):
                self.assertIn(term, second)

    def test_changed_source_invalidates_a_guide_review(self):
        path = "src/regex-dotnet/README.md"
        guide = "languages/regex-engines-and-sed.md"
        text = "[pattern](../../../src/regex-dotnet/README.md#program-flow)"
        queue = guide_impact.candidate_reviews([path], {guide: text}, {})
        self.assertEqual(queue, {guide: [path]})
        original = {path: b"capture witness"}
        before = {path: b"earlier witness"}
        token = guide_impact.review_token(queue[guide], before, original, text)
        changed = guide_impact.review_token(queue[guide], before, {path: b"changed witness"}, text)
        self.assertEqual(guide_impact.missing_reviews({guide: token}, {guide: token}), [])
        self.assertEqual(guide_impact.missing_reviews({guide: changed}, {guide: token}), [guide])

    def test_indirect_dependencies_can_add_guides(self):
        path = "src/awk-weird/README.md"
        guide = "concepts/comparative-machine-design.md"
        text = {guide: "An input engine supplies the next record."}
        self.assertEqual(guide_impact.candidate_reviews([path], text, {}), {})
        self.assertEqual(guide_impact.candidate_reviews([path], text, {path: [guide]}), {guide: [path]})


if __name__ == "__main__":
    unittest.main()
