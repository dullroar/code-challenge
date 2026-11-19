"""Fixtures for the PDF layout gate. Install requirements-pdf-lint.txt before running."""
from contextlib import redirect_stdout
from io import StringIO
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from PIL import Image
import pymupdf as pdf

import lint_pdf
from pdf_layout import EDGE_TOLERANCE, MARGIN_TOLERANCE, overflow, read_geometry

CSS = lint_pdf.HERE / "book.css"
GEOMETRY = read_geometry(CSS.read_text(encoding="utf-8"))


class GeometryTests(unittest.TestCase):
    def test_margin_shorthand_and_units(self):
        for css, margins in [
            ("1in", (72, 72, 72, 72)), ("0 96px", (0, 72, 0, 72)),
            ("0 1pt 2pt", (0, 1, 2, 1)), ("1in 2.54cm 25.4mm 72pt", (72, 72, 72, 72)),
        ]:
            with self.subTest(css=css):
                actual = read_geometry(f"@page {{ size: Letter; margin: {css} }}").margins
                for a, b in zip(actual, margins):
                    self.assertAlmostEqual(a, b)

    def test_unknown_css_fails_closed(self):
        base = "@page {size: Letter; margin: 2cm;}"
        for css in [base.replace("Letter", "A4"), base.replace("2cm", "10%"),
                    base[:-1] + "margin-left: 0;}", base + "@page :left {margin: 0;}",
                    base + "@page:first {size: A4;}", base + "@page:first {@top-center {}}"]:
            with self.subTest(css=css), self.assertRaises(ValueError):
                read_geometry(css)

    def test_thresholds(self):
        region = (10, 10, 90, 90)
        self.assertEqual(overflow((20, 20, 91.49, 80), region, 1.5), {})
        self.assertAlmostEqual(overflow((20, 20, 91.51, 80), region, 1.5)["right"], 1.51)


class Fixtures(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)

    def document(self, *, size=(612, 792)):
        doc = pdf.open()
        self.addCleanup(doc.close)
        return doc, doc.new_page(width=size[0], height=size[1])

    def save(self, doc, name="fixture.pdf", **options):
        path = self.directory / name
        doc.save(path, **options)
        return path

    def lint(self, *sources, options=()):
        report = self.directory / "report.json"
        with redirect_stdout(StringIO()):
            status = lint_pdf.main([str(s) for s in sources] + ["--json", str(report), *options])
        return status, json.loads(report.read_bytes())

    def page_rules(self, page):
        return {f["rule"] for f in lint_pdf.scan_page(page, pdf, GEOMETRY) if f["severity"] == "error"}

    def test_text_margin_and_edge_mutations(self):
        for edge, tolerance, rule in [
            (GEOMETRY.content[2], MARGIN_TOLERANCE, "PDF-004"), (612, EDGE_TOLERANCE, "PDF-003"),
        ]:
            for delta, flagged in [(tolerance - .05, False), (tolerance + .05, True), (10, True)]:
                with self.subTest(rule=rule, delta=delta):
                    _, page = self.document()
                    width = pdf.get_text_length("XXXX", fontsize=12)
                    page.insert_text((edge + delta - width, 120), "XXXX", fontsize=12)
                    self.assertEqual(rule in self.page_rules(page), flagged)

    def test_raster_placement_and_threshold(self):
        pix = pdf.Pixmap(pdf.csGRAY, pdf.IRect(0, 0, 4000, 300), False)
        pix.clear_with(123)
        right = GEOMETRY.content[2]
        for delta, flagged in [(1.45, False), (1.55, True), (10, True)]:
            with self.subTest(delta=delta):
                _, page = self.document()
                page.insert_image(pdf.Rect(120, 120, right + delta, 150), pixmap=pix, keep_proportion=False)
                self.assertEqual("PDF-005" in self.page_rules(page), flagged)

    def test_dimension_rotation_and_crop(self):
        _, page = self.document(size=(595, 842))
        self.assertIn("PDF-002", self.page_rules(page))
        _, page = self.document(size=(612.09, 792))
        self.assertNotIn("PDF-002", self.page_rules(page))
        _, page = self.document(size=(612.11, 792))
        self.assertIn("PDF-002", self.page_rules(page))
        _, page = self.document()
        page.set_cropbox(pdf.Rect(10, 15, 605, 790))
        self.assertIn("PDF-002", self.page_rules(page))
        _, page = self.document()
        page.set_mediabox(pdf.Rect(10, 20, 622, 812))
        self.assertNotIn("PDF-002", self.page_rules(page))

    def test_rotation_transform_and_preview(self):
        doc, page = self.document()
        page.insert_text((100, 215), "Inside the unrotated margins")
        page.set_rotation(90)
        pixmap = page.get_pixmap(dpi=144)
        self.assertEqual(lint_pdf.pixel_box((100, 200, 140, 220), page, pixmap, pdf),
                         [1144, 200, 1184, 280])
        self.assertEqual(self.page_rules(page), {"PDF-002"})
        preview = self.directory / "pages"
        self.assertEqual(self.lint(self.save(doc), options=("--annotate-dir", str(preview)))[0], 1)
        with Image.open(preview / "fixture-p0001.png") as image:
            self.assertEqual(image.size, (1584 + 390, 1224))

    def test_real_front_matter_and_footer(self):
        front = (lint_pdf.HERE.parent / "front-matter.md").read_text(encoding="utf-8")
        html = self.directory / "front.html"
        html.write_text(front + "<p>A short final page.</p>", encoding="utf-8")
        subprocess.run(["weasyprint", "-s", str(CSS), str(html), str(self.directory / "front.pdf")],
                       check=True, capture_output=True)
        status, report = self.lint(self.directory / "front.pdf")
        self.assertEqual(status, 0, report)
        self.assertEqual(report["documents"][0]["pages_scanned"], 3)

    def test_body_text_in_footer_region_and_displaced_title(self):
        for text, y in [("Not a counter", 758), ("1", 780), ("Learn Programming the Weird Way!", 58)]:
            with self.subTest(text=text):
                _, page = self.document()
                page.insert_text((200, y), text)
                self.assertIn("PDF-004", self.page_rules(page))

    def test_incomplete_pdf_and_multi_input(self):
        invalid = self.directory / "invalid.pdf"
        invalid.write_bytes(b"%PDF-1.7\ntruncated\n")
        doc, page = self.document()
        page.insert_text((100, 150), "Ordinary body text.")
        valid = self.save(doc)
        self.assertEqual(self.lint(valid)[0], 0)
        status, report = self.lint(invalid, valid)
        self.assertEqual(status, 2)
        good, bad = report["documents"]
        self.assertTrue(good["complete"])
        self.assertFalse(bad["complete"])
        self.assertEqual(bad["findings"][0]["rule"], "PDF-001")

    def test_stable_report_and_read_only_outputs(self):
        doc, page = self.document()
        page.insert_text((547, 130), "Margin intrusion")
        source = self.save(doc)
        original = source.read_bytes()
        args = ("--annotate-dir", str(self.directory / "pages"))
        status, report = self.lint(source, options=args)
        self.assertEqual(status, 1)
        first = (self.directory / "report.json").read_bytes()
        self.assertEqual(self.lint(source, options=args), (status, report))
        self.assertEqual((self.directory / "report.json").read_bytes(), first)
        self.assertNotIn(str(self.directory), first.decode())
        alias = self.directory / "alias.json"
        alias.hardlink_to(source)
        with redirect_stdout(StringIO()):
            self.assertEqual(lint_pdf.main([str(source), "--json", str(alias)]), 2)
        self.assertEqual(source.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
