"""Tests for lessons/curriculum/build.py: the rules that keep docs/curriculum.md inside its plan.

    python lessons/book/test_curriculum.py

The first group runs the checks against the real curriculum. The second group breaks one thing in a copy of the text and checks that the right
problem is reported, so each rule is shown to be able to fail. Nothing in the repository is touched. Needs only the Python standard library.
"""
import importlib.util, os, re, sys, unittest
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True
_spec = importlib.util.spec_from_file_location("curriculum_build", os.path.join(os.path.dirname(HERE), "curriculum", "build.py"))
cb = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cb)


def real():
    with open(cb.SOURCE, encoding="utf-8") as f:
        return f.read()


class RealCurriculum(unittest.TestCase):
    def test_has_no_problems(self):
        self.assertEqual(cb.check_curriculum(), [])

    def test_has_the_weird_phases_in_order(self):
        text = real()
        self.assertEqual(re.findall(r"^\| \| \*\*([WEIRD]): ", text, re.M), list("WEIRD"))

    def test_points_at_the_study_guides_and_chapters_it_names(self):
        text = real()
        for target in ("study-guides/concepts/reading-adversarial-programs.md", "cs/10-events-callbacks-and-reactive-control-flow.md",
                       "exercises.md#f1-test-a-claim-of-your-choice"):
            self.assertIn(target, text)


class BrokenCurriculum(unittest.TestCase):
    def problems(self, old, new):
        text = real()
        self.assertIn(old, text)
        return cb.check_curriculum(text.replace(old, new, 1))

    def test_a_missing_week_is_reported(self):
        self.assertTrue(any("weeks 1 to 16" in p for p in self.problems("| 9 | What does a closure", "| 99 | What does a closure")))

    def test_a_diagram_without_a_description_is_reported(self):
        self.assertTrue(any("accDescr" in p for p in self.problems("accDescr:", "accDesc:")))

    def test_a_wrong_chapter_number_is_reported(self):
        self.assertTrue(any("chapter 4 of the printed book" in p for p in self.problems("[Ch 4](../lessons/cs/01-", "[Ch 1](../lessons/cs/01-")))

    def test_an_arrow_to_the_box_is_reported(self):
        self.assertTrue(any("arrow to or from the box" in p for p in self.problems("    S([\"Start: phase = W\"]) --> W", "    S([\"Start: phase = W\"]) --> weeks")))

    def test_the_loop_is_bounded(self):
        text = real()
        self.assertIn("A second failed review ends the course", text)
        self.assertIn("Stop and report the gap", text)

    def test_every_week_has_a_required_guide_in_bold(self):
        rows = [l for l in real().splitlines() if re.match(r"^\| \d+ \|", l)]
        self.assertEqual(len(rows), 16)
        for row in rows:
            self.assertIn("**[", row, row[:40])

    def test_a_broken_link_is_reported(self):
        self.assertTrue(any("missing file" in p for p in self.problems("study-guides/languages/cobol.md", "study-guides/languages/cobol-gone.md")))
        self.assertTrue(any("missing heading" in p for p in self.problems("#running-things-safely", "#running-things-safe")))

    def test_a_host_outside_the_allowlist_is_reported(self):
        self.assertTrue(any("not in lessons/book/link-hosts.txt" in p for p in self.problems("https://en.wikipedia.org/wiki/Sed", "https://example.com/sed")))

    def test_a_long_sentence_is_reported(self):
        long = "This sentence keeps going " + "and going " * 12 + "until it breaks the limit."
        self.assertTrue(any("sentence of" in p for p in self.problems("The ideas are the subject.", long)))

    def test_a_contraction_and_a_dash_are_reported(self):
        self.assertTrue(any("contraction" in p for p in self.problems("You do not need a degree.", "You don't need a degree.")))
        self.assertTrue(any("em dash" in p for p in self.problems("The ideas are the subject.", "The ideas — not the syntax — are the subject.")))


class Pages(unittest.TestCase):
    def test_the_written_pdf_is_within_the_page_limit(self):
        pdf = os.path.join(cb.REPO, "curriculum.pdf")
        pages = cb.pdf_pages(pdf) if os.path.exists(pdf) else None
        if pages is None:
            self.skipTest("needs curriculum.pdf and Ghostscript")
        self.assertLessEqual(pages, cb.MAX_PAGES)


if __name__ == "__main__":
    unittest.main()
