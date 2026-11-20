"""Fixtures for the PDF layout gate. Install requirements-pdf-lint.txt before running."""
from contextlib import redirect_stdout
from io import StringIO
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image
import pymupdf as pdf

import diagrams
import lint_pdf
from pdf_sentinels import Sentinel
from pdf_layout import EDGE_TOLERANCE, MARGIN_TOLERANCE, overflow, read_geometry, table_edges

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


class BuildHookTests(unittest.TestCase):
    def test_only_the_new_pdf_is_linted_and_release_propagates_status(self):
        import build

        with tempfile.TemporaryDirectory() as directory:
            for checking in (True, False):
                args = ["build.py", "--artifacts-dir", directory, "--check" if checking else "--release"]
                with (patch.object(build.sys, "argv", args),
                      patch.object(build, "source_date_epoch", return_value="0"),
                      patch.object(build, "render_figures"),
                      patch.object(build, "prepare_document", return_value="{}"),
                      patch.object(build, "write_front", side_effect=lambda front, stem: front),   # "front" is not a real file here
                      patch.object(build, "pdf_engine", return_value="weasyprint"),
                      patch.object(build.subprocess, "run") as run):
                    run.return_value.returncode = 2
                    with redirect_stdout(StringIO()):
                        if checking:
                            build.build_documents({}, "custom", "metadata", "front", "check.html", "test", True)
                        else:
                            with self.assertRaises(SystemExit) as raised:
                                build.build_documents({}, "custom", "metadata", "front", "test.html", "test", False)
                            self.assertEqual(raised.exception.code, 2)
                    commands = [call.args[0] for call in run.call_args_list]
                    if checking:
                        self.assertEqual(len(commands), 1)
                        self.assertTrue(commands[0][-1].endswith("check.html"))
                    else:
                        self.assertEqual(len(commands), 4)
                        expected = str(Path(directory) / "custom.pdf")
                        self.assertEqual(commands[2][-1], expected)
                        self.assertEqual(commands[3][2], expected)
                        self.assertEqual(commands[3][-1], "--release")


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
        return {f["rule"] for f in lint_pdf.scan_page(page, pdf, GEOMETRY)[0] if f["severity"] == "error"}

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

    def test_warning_overlap_and_preview(self):
        doc, page = self.document()
        page.insert_text((100, 150), "A strongly overlapping line", fontsize=14)
        page.insert_text((104, 153), "Another overlapping line", fontsize=14)
        status, report = self.lint(self.save(doc), options=("--release", "--annotate-dir", str(self.directory)))
        self.assertEqual(status, 0, report)
        items = [f for f in report["documents"][0]["findings"] if f["rule"] == "PDF-008"]
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["severity"], "warning")
        self.assertTrue((self.directory / items[0]["preview"]).is_file())

    def test_kerning_and_table_rules_are_not_overlaps(self):
        _, page = self.document()
        page.insert_text((100, 150), "AVATAR Table")
        page.draw_line((99, 145), (200, 145), color=(.8, .8, .8), width=.75)
        page.insert_text((100, 165), "Another row")
        items, _, _ = lint_pdf.scan_page(page, pdf, GEOMETRY)
        self.assertNotIn("PDF-008", {f["rule"] for f in items})

    def test_table_continuation_grid_requires_open_edge(self):
        y = GEOMETRY.content[3]
        vertical = [(x, y - 22, x, y) for x in (90, 150, 211)]
        horizontal = [(90, y, 150, y), (150, y, 211, y)]
        _, edge = table_edges(vertical + horizontal, GEOMETRY)
        self.assertEqual(edge, ((90, 150, 211), y, True))
        _, edge = table_edges(vertical + horizontal[:1], GEOMETRY)
        self.assertFalse(edge[2])

    def test_blank_publication_page_and_encryption(self):
        doc, _ = self.document()
        _, report = self.lint(self.save(doc))
        self.assertEqual(report["warnings"], 1, report)
        with patch.dict(lint_pdf.PROFILES, {"book": ()}):
            status, report = self.lint(self.save(doc, "blank-book.pdf"), options=("--profile", "book"))
        self.assertEqual(status, 1, report)
        self.assertEqual(report["documents"][0]["findings"][0]["rule"], "PDF-007")
        status, report = self.lint(self.save(doc, "locked.pdf", encryption=pdf.PDF_ENCRYPT_AES_256,
                                            owner_pw="owner"))
        self.assertEqual(status, 2, report)

    def test_clipped_vector_extents_are_not_reported_as_visible_overflow(self):
        doc, page = self.document()
        page.insert_text((100, 120), "Vector clipping fixture")
        page.draw_rect(pdf.Rect(100, 200, 566, 230), color=(0, 0, 0), fill=(.4, .4, .4))
        content = page.get_contents()[-1]
        original = doc.xref_stream(content)
        before, _, _ = lint_pdf.scan_page(page, pdf, GEOMETRY)
        self.assertIn("PDF-006", {f["rule"] for f in before})
        doc.update_stream(content, b"q 100 530 430 70 re W n\n" + original + b"\nQ")
        after, _, _ = lint_pdf.scan_page(page, pdf, GEOMETRY)
        self.assertNotIn("PDF-006", {f["rule"] for f in after})

    def test_page_scan_abort_is_incomplete(self):
        doc, page = self.document()
        page.insert_text((100, 120), "Page one")
        doc.new_page()
        source = self.save(doc)
        real_scan = lint_pdf.scan_page

        def fail_second(page, *args, **kwargs):
            if page.number == 1:
                raise RuntimeError("simulated read failure")
            return real_scan(page, *args, **kwargs)

        with patch.object(lint_pdf, "scan_page", side_effect=fail_second):
            status, report = self.lint(source)
        self.assertEqual(status, 2, report)
        result = report["documents"][0]
        self.assertEqual(result["pages_scanned"], 1)
        self.assertEqual(result["page_failures"], [2])
        self.assertFalse(result["complete"])

    def test_release_raster_flags_substantial_white_only_page(self):
        doc, page = self.document()
        for y in range(100, 160, 10):
            page.insert_text((100, y), "Invisible in the render", color=(1, 1, 1))
        source = self.save(doc)
        self.assertEqual(self.lint(source)[0], 0)
        status, report = self.lint(source, options=("--release",))
        self.assertEqual(status, 1, report)
        self.assertIn("PDF-011", {f["rule"] for f in report["documents"][0]["findings"]})

    def test_pdf_parser_recovery_does_not_count_as_a_scanned_page(self):
        doc, page = self.document()
        page.insert_text((100, 120), "Valid portion of page")
        ref = page.get_contents()[0]
        doc.update_stream(ref, doc.xref_stream(ref) + b"\nq /Missing Do Q\n")
        status, report = self.lint(self.save(doc))
        self.assertEqual(status, 2, report)
        result = report["documents"][0]
        self.assertEqual(result["page_failures"], [1])
        self.assertEqual(result["findings"][0]["rule"], "PDF-001")

    def test_selectable_glyph_corruption(self):
        with patch.dict(lint_pdf.PROFILES, {"book": (Sentinel("comparison", "total >= 40"),)}):
            for snippet, status in [("total >= 40", 0), ("total = 40", 1)]:
                doc, page = self.document()
                page.insert_text((100, 120), snippet)
                actual, report = self.lint(self.save(doc), options=("--profile", "book"))
                self.assertEqual(actual, status, report)
                checks = report["documents"][0]["content_checks"]
                self.assertEqual(checks[0]["page"], None if status else 1)
                if status:
                    self.assertIn("PDF-010", {f["rule"] for f in report["documents"][0]["findings"]})

    def test_weasyprint_pandoc_wrap_and_pinned_mermaid_glyphs(self):
        renderer, why = diagrams.find_renderer()
        self.assertIsNotNone(renderer, why)
        # Mermaid’s named escape and literal ASCII/Unicode operators both reach the PDF through flattened SVG.
        source = """flowchart TD
            A["higher: total #gt; 40"] --> B["lower: total < 40"]
            B --> C["ceil: total ≥ 40"]
            C --> D["floor: total ≤ 40"]
        """
        svg = self.directory / "sentinels.svg"
        renderer.run(source, str(svg))
        renderer.flatten(str(svg))
        # Force a mid-token break with no discarded source whitespace.
        literal = "X" * 79 + r"[\] \\ \(" + "Y" * 22
        md = f'<img src="{svg.as_uri()}" style="width: 200px" />\n\n```text\n{literal}\n⍴ ⍳ ⎕ ⎕FX\n```\n'
        output = self.directory / "sentinels.pdf"
        subprocess.run(["pandoc", "-f", "markdown", "--pdf-engine=weasyprint", "--css", str(CSS),
                        "--lua-filter", str(lint_pdf.HERE / "wrap-code.lua"), "-o", str(output)],
                       input=md, text=True, check=True, capture_output=True)
        with pdf.open(output) as doc:
            text = "\n".join(line["text"] for page in doc for line in lint_pdf.text_lines(page, pdf))
            for label, operator in [("higher", ">"), ("lower", "<"), ("ceil", "≥"), ("floor", "≤")]:
                self.assertRegex(text, rf"{label}: total *{operator} *40")
            self.assertIn("⍴ ⍳ ⎕ ⎕FX", text)
            self.assertIn("↩\n↪ ", text)
            self.assertIn(literal, text.replace("↩\n↪ ", ""))
            for page in doc:
                for line in lint_pdf.text_lines(page, pdf):
                    if line["text"].startswith(("higher:", "lower:", "ceil:", "floor:")):
                        self.assertTrue(any(pixel < 255 for pixel in
                                            page.get_pixmap(clip=line["box"], colorspace=pdf.csGRAY).samples))
        self.assertEqual(self.lint(output, options=("--release",))[0], 0)

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
