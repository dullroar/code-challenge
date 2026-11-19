"""Tests for study_guides.py: the rules that keep the hand-written study guides honest.

    python lessons/book/test_study_guides.py

The first group runs the rules against the real guides and the real book. The second group copies the lessons tree and the entries' READMEs into a
scratch folder, breaks one thing, and checks that the right problem is reported, so each rule is shown to be able to fail. Nothing in the
repository is touched. Needs only the Python standard library.
"""
import os, re, shutil, sys, tempfile, unittest
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import study_guides as sg

REPO = sg.REPO


def snapshot(dest):
    """Copy what the checks read: the lessons tree (minus build output and the Mermaid tools), the entries (minus build output, so source-line
    links can be checked) and the root Markdown files that guides link to."""
    shutil.copytree(os.path.join(REPO, "lessons"), os.path.join(dest, "lessons"),
                    ignore=shutil.ignore_patterns("out", "__pycache__", "node_modules"))
    shutil.copytree(os.path.join(REPO, "src"), os.path.join(dest, "src"),
                    ignore=shutil.ignore_patterns("target", "node_modules", "obj", "bin", ".gradle", "build", "__pycache__", ".git"))
    for f in os.listdir(REPO):
        if f.endswith(".md") and os.path.isfile(os.path.join(REPO, f)):
            shutil.copy(os.path.join(REPO, f), os.path.join(dest, f))
    for sub in ("docs",):
        if os.path.isdir(os.path.join(REPO, sub)):
            shutil.copytree(os.path.join(REPO, sub), os.path.join(dest, sub))


class RealRepository(unittest.TestCase):
    def test_every_rule_passes_on_the_real_guides(self):
        problems = sg.check_all()
        self.assertEqual(problems, [], "\n".join(problems))

    def test_thirteen_language_guides_and_eight_concept_guides(self):
        self.assertEqual(len(sg.LANGUAGE_GUIDES), 13)
        self.assertEqual(len(sg.CONCEPT_GUIDES), 8)
        for g in sg.ALL_GUIDES:
            self.assertTrue(os.path.isfile(os.path.join(sg.GUIDES, g)), g)

    def test_every_guide_is_in_the_manifest_and_the_index(self):
        chap = sg.manifest()
        index = sg.read(os.path.join(sg.GUIDES, "README.md"))
        for g in sg.ALL_GUIDES:
            self.assertIn(g, chap)
            self.assertIn(f"]({g}", index, f"the index does not link to {g}")

    def test_the_book_does_not_contain_the_guides(self):
        book = sg.read(os.path.join(sg.LESSONS, "book", "chapters.txt"))
        self.assertNotIn("study-guides", book)

    def test_every_expected_program_flow_diagram_is_reused_verbatim(self):
        for rel, entries in sg.EXPECTED_DIAGRAMS.items():
            found = {m[1] for _, _, m in sg.guide_diagrams(sg.read(os.path.join(sg.GUIDES, rel))) if m and m[0] == "source"}
            for e in entries:
                self.assertIn(f"src/{e}/README.md#program-flow", found, f"{rel} lacks the Program Flow diagram of {e}")

    def test_the_book_points_at_each_guide(self):
        for g, pages in sg.BOOK_LINKS.items():
            for page in pages:
                head = "\n".join(sg.read(os.path.join(sg.LESSONS, page)).split("\n")[:40])
                self.assertIn(f"study-guides/{g}", head, f"lessons/{page} should link to {g} near its start")

    def test_the_generated_chapters_were_not_edited_by_hand(self):
        # The links in lessons/cs/ come from lessons/cs-source/. Both must carry them.
        for g, pages in sg.BOOK_LINKS.items():
            for page in (p for p in pages if p.startswith("cs/")):
                src = os.path.join(sg.LESSONS, "cs-source", "chapters", os.path.basename(page))
                self.assertIn(f"study-guides/{g}", sg.read(src), f"{src} is the source of {page}")

    def test_the_companion_edition_matches_the_book(self):
        book = re.search(r'^title:\s*"(.+)"', sg.read(os.path.join(sg.LESSONS, "book", "metadata.yaml")), re.M).group(1)
        self.assertIn(f'companion-to: "{book}"', sg.read(os.path.join(sg.GUIDES, "metadata.yaml")))


class Scanner(unittest.TestCase):
    def test_sections_ignore_headings_inside_fences(self):
        text = "# T study guide\n\n## One\n\nbody\n\n```text\n## Not a heading\n```\n\n## Two\n\nmore\n"
        self.assertEqual([t for t, _, _ in sg.sections(text)], ["One", "Two"])

    def test_canonical_source_by_block_number_and_heading(self):
        a = sg.canonical_source("lessons/cs-source/chapters/04-evaluation-and-demand.md#block-1")
        self.assertTrue(a.startswith("flowchart"))
        b = sg.canonical_source("lessons/intro.md#what-the-challenge-does")
        self.assertIn("What the challenge does", b)
        c = sg.canonical_source("src/cobol-weird/README.md#program-flow")
        self.assertTrue(c.startswith("stateDiagram-v2"))

    def test_canonical_source_refuses_generated_files(self):
        for ref in ("lessons/cs/04-evaluation-and-demand.md#block-1", "lessons/languages/cobol.md#block-1"):
            with self.assertRaises(ValueError):
                sg.canonical_source(ref)

    def test_diagram_markers_are_found_across_blank_lines(self):
        text = "<!-- diagram-source: src/x/README.md#program-flow -->\n\n```mermaid\nflowchart TD\n```\n\n<!-- diagram-new: lazy-demand-trace - why -->\n```mermaid\nflowchart TD\n```\n\n```mermaid\nflowchart TD\n```\n"
        found = [m for _, _, m in sg.guide_diagrams(text)]
        self.assertEqual(found[0], ("source", "src/x/README.md#program-flow"))
        self.assertEqual(found[1][:2], ("new", "lazy-demand-trace"))
        self.assertIsNone(found[2])


class Mutations(unittest.TestCase):
    """Each test breaks one thing in a scratch copy and expects the matching problem."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        snapshot(self.tmp)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def path(self, rel):
        return os.path.join(self.tmp, rel)

    def edit(self, rel, fn):
        p = self.path(rel)
        with open(p, encoding="utf-8") as f:
            s = f.read()
        t = fn(s)
        self.assertNotEqual(s, t, f"the edit changed nothing in {rel}")
        with open(p, "w", encoding="utf-8") as f:
            f.write(t)

    def guide(self, g="languages/cobol.md"):
        return sg.read(self.path(f"lessons/study-guides/{g}"))

    def problems(self, g="languages/cobol.md"):
        return [p for p in sg.check_guide(g, self.guide(g), self.tmp)]

    def edit_guide(self, fn, g="languages/cobol.md"):
        self.edit(f"lessons/study-guides/{g}", fn)

    def assertProblem(self, text, g="languages/cobol.md"):
        ps = self.problems(g)
        self.assertTrue(any(text in p for p in ps), f"expected a problem containing {text!r}; got {ps}")

    def test_the_copy_starts_clean(self):
        self.assertEqual(sg.check_all(self.tmp), [])

    def test_a_drifted_diagram_is_caught(self):
        self.edit_guide(lambda s: s.replace("A[\"SET-UP, OPEN-SCRIPT", "A[\"SET UP, OPEN SCRIPT", 1))
        self.assertProblem("differs from its canonical source")

    def test_a_diagram_without_accessibility_text_is_caught(self):
        self.edit_guide(lambda s: re.sub(r"^\s*accDescr:.*\n", "", s, count=1, flags=re.M))
        self.assertProblem("needs 'accDescr:'")
        self.edit_guide(lambda s: re.sub(r"^\s*accTitle:.*\n", "", s, count=1, flags=re.M))
        self.assertProblem("needs 'accTitle:'")

    def test_a_diagram_without_provenance_is_caught(self):
        self.edit_guide(lambda s: re.sub(r"<!-- diagram-source: [^>]*-->\n", "", s, count=1))
        self.assertProblem("needs the line before it")

    def test_a_diagram_copied_from_a_generated_file_is_caught(self):
        self.edit_guide(lambda s: s.replace("diagram-source: src/cobol/README.md#program-flow", "diagram-source: lessons/languages/cobol.md#block-1", 1))
        self.assertProblem("never generated files")

    def test_a_new_diagram_needs_an_allowed_kind(self):
        self.edit_guide(lambda s: s.replace("diagram-source: src/cobol/README.md#program-flow", "diagram-new: pretty-picture - because", 1))
        self.assertProblem("must add one of")

    def test_a_language_guide_needs_a_diagram(self):
        self.edit_guide(lambda s: re.sub(r"<!-- diagram-source:.*?```mermaid\n.*?\n```\n", "", s, flags=re.S))
        self.assertProblem("at least one diagram")

    def test_a_missing_expected_flow_is_caught(self):
        self.edit_guide(lambda s: re.sub(r"<!-- diagram-source: src/cobol-weird/README.md#program-flow -->\n\n```mermaid\n.*?\n```\n", "", s, flags=re.S))
        self.assertProblem("must reuse the Program Flow diagram of src/cobol-weird")

    def test_placeholder_text_is_caught(self):
        for word in ("TODO", "TBD", "lorem ipsum"):
            self.edit_guide(lambda s, w=word: s.replace("## Further reading\n", f"## Further reading\n\n{w}: fill this in.\n", 1))
            self.assertProblem("placeholder text")
            self.edit_guide(lambda s, w=word: s.replace(f"{w}: fill this in.\n\n", "", 1))

    def test_an_empty_required_section_is_caught(self):
        self.edit_guide(lambda s: re.sub(r"(## Self-check\n).*?(\n## Further reading)", r"\1\nNothing.\n\2", s, flags=re.S))
        self.assertProblem("section 'Self-check' is empty or too short")

    def test_a_missing_or_reordered_section_is_caught(self):
        self.edit_guide(lambda s: s.replace("## Trace one run\n", "## Trace\n", 1))
        self.assertProblem("exactly the template")

    def test_the_title_must_say_study_guide(self):
        self.edit_guide(lambda s: s.replace("# COBOL study guide", "# COBOL notes", 1))
        self.assertProblem("# <Topic> study guide")

    def test_the_safety_model_is_required(self):
        self.edit_guide(lambda s: s.replace("DEMO ONLY", "demo", -1))
        self.assertProblem("safety model")

    def test_shared_challenge_paragraph_must_use_standard_wording(self):
        self.edit_guide(lambda s: s.replace("first card that takes the total over 40", "card that makes the total exceed 40", 1))
        self.assertProblem("must start with the standard paragraph")

    def test_exactly_40_must_be_stated(self):
        self.edit_guide(lambda s: s.replace("exactly 40", "forty", -1))
        self.assertProblem("exactly 40")

    def test_the_five_questions_and_the_four_self_check_questions_are_required(self):
        self.edit_guide(lambda s: s.replace("**What stops it.**", "**Stopping.**", 1))
        self.assertProblem("**What stops it.**")
        self.edit_guide(lambda s: s.replace("**Evidence.**", "**Proof.**", 1))
        self.assertProblem("**Evidence.**")

    def test_a_link_to_a_missing_file_or_heading_is_caught(self):
        self.edit_guide(lambda s: s.replace("(../../exercises.md#a1-read-the-rows-verified)", "(../../exercises.md#a1-no-such-heading)", 1))
        self.assertProblem("missing heading")
        self.edit_guide(lambda s: s.replace("(forth.md)", "(nowhere.md)", 1))
        self.assertProblem("missing file")

    def test_a_source_line_anchor_out_of_range_is_caught(self):
        self.edit_guide(lambda s: s.replace("timecards.cob#L93)", "timecards.cob#L9999)", 1))
        self.assertProblem("out of range")

    def test_a_line_link_whose_text_and_anchor_disagree_is_caught(self):
        self.edit_guide(lambda s: s.replace("[L93](../../../src/cobol/timecards.cob#L93)", "[L93](../../../src/cobol/timecards.cob#L94)", 1))
        self.assertProblem("the link text says L93 but the anchor is #L94")

    def test_an_external_host_must_be_on_the_allowlist(self):
        self.edit_guide(lambda s: s.replace("## Further reading\n", "## Further reading\n\n- [Blog](https://example.com/a-blog-post) (a blog).\n", 1))
        self.assertProblem("is not in lessons/book/link-hosts.txt")

    def test_generated_markers_are_refused_in_a_guide(self):
        self.edit_guide(lambda s: s.replace("## Further reading\n", "## Further reading\n\n<!-- BEGIN GENERATED x -->\n", 1))
        self.assertProblem("BEGIN/END GENERATED")

    def test_a_guide_missing_from_the_manifest_or_the_index_is_caught(self):
        self.edit("lessons/study-guides/chapters.txt", lambda s: s.replace("languages/cobol.md\n", "", 1))
        self.assertTrue(any("chapters.txt: missing languages/cobol.md" in p for p in sg.check_set(self.tmp)))
        self.edit("lessons/study-guides/README.md", lambda s: s.replace("(languages/haskell.md)", "(languages/hask.md)", 1))
        self.assertTrue(any("the index does not link to languages/haskell.md" in p for p in sg.check_set(self.tmp)))

    def test_a_missing_guide_file_is_caught(self):
        os.remove(self.path("lessons/study-guides/languages/m4.md"))
        self.assertTrue(any("languages/m4.md: the guide does not exist" in p for p in sg.check_set(self.tmp)))

    def test_a_guide_that_is_not_planned_is_caught(self):
        with open(self.path("lessons/study-guides/languages/extra.md"), "w", encoding="utf-8") as f:
            f.write("# Extra study guide\n")
        self.assertTrue(any("not one of the planned guides" in p for p in sg.check_set(self.tmp)))

    def test_the_guides_must_stay_out_of_the_book_manifest(self):
        self.edit("lessons/book/chapters.txt", lambda s: s + "study-guides/languages/cobol.md\n")
        self.assertTrue(any("separate set, not book chapters" in p for p in sg.check_set(self.tmp)))

    def test_the_book_page_must_link_to_its_guide(self):
        self.edit("lessons/languages/cobol.md", lambda s: s.replace("study-guides/languages/cobol.md", "study-guides/", 1))
        self.assertTrue(any("lessons/languages/cobol.md: needs a link to study-guides/languages/cobol.md" in p for p in sg.check_set(self.tmp)))

    def test_the_index_pages_need_a_study_guides_section(self):
        self.edit("lessons/README.md", lambda s: s.replace("study-guides/README.md", "study-guides/", 1))
        self.assertTrue(any("lessons/README.md: needs a Study Guides section" in p for p in sg.check_set(self.tmp)))

    def test_the_companion_edition_must_match_the_book(self):
        self.edit("lessons/study-guides/metadata.yaml", lambda s: s.replace("companion-to: \"Learn Programming the Weird Way! v4\"", "companion-to: \"Learn Programming the Weird Way! v3\"", 1))
        self.assertTrue(any("companion-to must equal the book title" in p for p in sg.check_set(self.tmp)))


if __name__ == "__main__":
    unittest.main(verbosity=1)
