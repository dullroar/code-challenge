"""Tests for the metadata rules in cs.py: what grounds a concept, what the linter refuses, and that the output is stable.

    python lessons/book/test_cs.py

Each test copies the real sources into a scratch folder and breaks one thing, so the rules are tested against the real data
and nothing in the repository is touched. Needs only the Python standard library.
"""
import os, re, shutil, sys, tempfile, unittest
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cs

REPO = cs.REPO

def snapshot(dest):
    """Copy what cs.Model reads (the entries' READMEs and the whole lessons tree, minus build output) and point cs at it."""
    shutil.copytree(os.path.join(REPO, "lessons"), os.path.join(dest, "lessons"), ignore=shutil.ignore_patterns("out", "__pycache__"))
    for d in os.listdir(os.path.join(REPO, "src")):
        r = os.path.join(REPO, "src", d, "README.md")
        if os.path.isfile(r):
            os.makedirs(os.path.join(dest, "src", d))
            shutil.copy(r, os.path.join(dest, "src", d, "README.md"))
    cs.REPO, cs.SRC = dest, os.path.join(dest, "src")
    cs.LESSONS, cs.CSSRC, cs.CSOUT = os.path.join(dest, "lessons"), os.path.join(dest, "lessons", "cs-source"), os.path.join(dest, "lessons", "cs")

class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.saved = (cs.REPO, cs.SRC, cs.LESSONS, cs.CSSRC, cs.CSOUT)
        snapshot(self.tmp)
    def tearDown(self):
        cs.REPO, cs.SRC, cs.LESSONS, cs.CSSRC, cs.CSOUT = self.saved
        shutil.rmtree(self.tmp)
    def edit(self, rel, fn):
        p = os.path.join(self.tmp, rel)
        with open(p, encoding="utf-8") as f:
            s = f.read()
        t = fn(s)
        self.assertNotEqual(s, t, f"the edit changed nothing in {rel}")
        with open(p, "w", encoding="utf-8") as f:
            f.write(t)
    def problems(self):
        return list(cs.Model().problems)

class TestRepositoryAsItIs(Base):
    def test_no_problems_and_no_orphans(self):
        m = cs.Model()
        self.assertEqual(list(m.problems), [])
        lines, bad = cs.orphan_report(m)
        self.assertEqual(bad, 0, "\n".join(lines))

    def test_output_is_deterministic(self):
        a, b = cs.generate_all(cs.Model()), cs.generate_all(cs.Model())
        self.assertEqual(a, b)

    def test_generated_text_never_says_a_concept_is_unused(self):
        for rel, text in cs.generate_all(cs.Model()).items():
            self.assertNotIn("no entry uses this yet", text.lower(), rel)

    def test_every_new_entry_is_in_the_by_language_by_pattern_and_concept_indexes(self):
        files = cs.generate_all(cs.Model())
        for d in ("tar-gnu", "tar-gnu-weird", "ed-weird", "ex-weird", "javascript", "javascript-weird"):
            self.assertIn(f"`{d}`", files["index.md"], d)
            self.assertIn(f"src/{d}/README.md", files["cs/09-comparative-case-studies.md"], d)
            with open(os.path.join(cs.LESSONS, "languages", "README.md"), encoding="utf-8") as f:
                self.assertIn(f"`{d}`", f.read(), f"{d} is missing from the By language page")
            self.assertIn(f"src/{d}/README.md", cs.generate_blocks(cs.Model(), "patterns.md"), f"{d} is missing from the By solution patterns page")

    def test_teaches_line_matches_the_frontmatter_for_every_entry(self):
        m = cs.Model()
        for d, e in m.entries.items():
            hit = re.search(r"^\*\*Teaches you:\*\* (.+)$", e["_body"], re.M)
            if hit:
                self.assertEqual(hit.group(1).strip(), e["teaches"], d)

    def test_the_two_cross_cutting_claims_are_true(self):
        """applies-to: all is a statement about every entry, so check it. (sandbox: a Dockerfile or a Windows Sandbox section;
        code-review: a How the stunt works section.)"""
        m = cs.Model()
        for d in m.entries:
            with open(os.path.join(cs.SRC, d, "README.md"), encoding="utf-8") as f:
                readme = f.read()
            self.assertIn("\n## How the stunt works\n", readme, d)
            has_docker = os.path.isfile(os.path.join(REPO, "src", d, "Dockerfile"))
            self.assertTrue(has_docker or "\n## Run it in Windows Sandbox" in readme, d)

class TestTheLintersRefuse(Base):
    def test_an_ungrounded_concept(self):
        self.edit("lessons/cs-source/concepts/sandbox.md", lambda s: re.sub(r"applies-to: all\napplies-because: .*\n", "", s))
        self.assertTrue(any("sandbox" in p and "no entry demonstrates" in p for p in self.problems()), self.problems())

    def test_a_cross_cutting_claim_needs_its_reason(self):
        self.edit("lessons/cs-source/concepts/sandbox.md", lambda s: re.sub(r"applies-because: .*\n", "applies-because: \"short\"\n", s))
        self.assertTrue(any("applies-because" in p for p in self.problems()), self.problems())

    def test_a_bad_applies_to_value(self):
        self.edit("lessons/cs-source/concepts/sandbox.md", lambda s: s.replace("applies-to: all", "applies-to: some"))
        self.assertTrue(any("applies-to must be one of" in p for p in self.problems()), self.problems())

    def test_an_exercise_link_that_does_not_exist(self):
        self.edit("lessons/cs-source/concepts/trojan-source.md", lambda s: s.replace("#f2-trojan-source-hide-a-character-then-find-it-verified", "#no-such-exercise"))
        self.assertTrue(any("trojan-source" in p and "no heading with that anchor" in p for p in self.problems()), self.problems())

    def test_an_unknown_concept_in_analogies(self):
        self.edit("src/javascript-weird/README.md", lambda s: s.replace("analogies: [", "analogies: [no-such-concept, ", 1))
        self.assertTrue(any("no-such-concept" in p for p in self.problems()), self.problems())

    def test_a_concept_cannot_be_a_tag_and_an_analogy_of_one_entry(self):
        self.edit("src/javascript-weird/README.md", lambda s: s.replace("analogies: [", "analogies: [closure, ", 1))
        self.assertTrue(any("both a tag" in p for p in self.problems()), self.problems())

    def test_stale_wording_cannot_come_back(self):
        self.edit("lessons/cs-source/concepts/closure.md", lambda s: s + "\nIn this repo: no entry uses this yet; it is background for the others.\n")
        self.assertTrue(any("stale wording" in p for p in self.problems()), self.problems())

    def test_removing_the_last_demonstration_leaves_only_an_analogy_which_is_still_allowed_but_visible(self):
        """continuation has analogies and counterexamples only: the report must say so, and not call it demonstrated."""
        lines, bad = cs.orphan_report(cs.Model())
        text = "\n".join(lines)
        self.assertIn("only an analogy or counterexample", text)
        self.assertRegex(text, r"continuation \(.*analogy.*\)")
        self.assertEqual(bad, 0)

    def test_an_unknown_tag(self):
        self.edit("src/tar-gnu/README.md", lambda s: s.replace("tags: [", "tags: [not-a-concept, ", 1))
        self.assertTrue(any("not-a-concept" in p for p in self.problems()), self.problems())

    def test_a_missing_teaches_match(self):
        self.edit("src/tar-gnu/README.md", lambda s: s.replace("**Teaches you:** that a tar archive", "**Teaches you:** that a TAR archive", 1))
        self.assertTrue(any("'teaches' differs" in p for p in self.problems()), self.problems())

if __name__ == "__main__":
    unittest.main(verbosity=2)
