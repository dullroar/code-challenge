"""Tests for diagrams.py: the Program Flow contract, the structural scanner, the cache keys, and (when a renderer is installed) a real render.

    python lessons/book/test_diagrams.py

Needs only the Python standard library. The two render tests are skipped, and say so, when Mermaid CLI or a Chromium is missing.
"""
import os, sys, tempfile, unittest
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import diagrams

GOOD = '''# Title

## Run it

text

## Program Flow

```mermaid
flowchart TD
    accTitle: A caption
    accDescr: What it shows.
    A["one"] --> B["two"]
```

**What this shows:** x.

**Why this mechanism matters:** y.

## How the stunt works
'''


def read(path):
    with open(path, "rb") as f:
        return f.read()


class Contract(unittest.TestCase):
    def check(self, text):
        return diagrams.program_flow(text, "src/x/README.md")

    def test_a_good_section(self):
        sec, probs = self.check(GOOD)
        self.assertEqual(probs, [])
        self.assertTrue(sec.startswith("```mermaid") and sec.rstrip().endswith("y."))
        self.assertNotIn("How the stunt works", sec)

    def test_missing_section(self):
        sec, probs = self.check(GOOD.replace("## Program Flow", "## Something else"))
        self.assertIsNone(sec)
        self.assertIn("no '## Program Flow' section", probs[0])

    def test_a_synonym_heading_is_refused(self):
        _, probs = self.check(GOOD.replace("## Program Flow", "## Program flow"))
        self.assertTrue(any("exactly '## Program Flow'" in p for p in probs))

    def test_a_heading_inside_a_code_block_is_not_a_heading(self):
        text = GOOD.replace("## Program Flow", "## Other") + "\n```text\n## Program Flow\n```\n"
        sec, probs = self.check(text)
        self.assertIsNone(sec)

    def test_two_diagrams_are_refused(self):
        _, probs = self.check(GOOD.replace("**What this shows:**", "```mermaid\nflowchart TD\n  A-->B\n```\n\n**What this shows:**"))
        self.assertTrue(any("exactly one" in p for p in probs))

    def test_a_non_mermaid_fence_is_refused(self):
        _, probs = self.check(GOOD.replace("**What this shows:**", "```text\nx\n```\n\n**What this shows:**"))
        self.assertTrue(any("only a ```mermaid block" in p for p in probs))

    def test_alt_text_and_caption_are_required(self):
        _, probs = self.check(GOOD.replace("    accTitle: A caption\n", ""))
        self.assertTrue(any("accTitle" in p for p in probs))
        _, probs = self.check(GOOD.replace("    accDescr: What it shows.\n", ""))
        self.assertTrue(any("accDescr" in p for p in probs))

    def test_html_in_a_diagram_is_refused(self):
        _, probs = self.check(GOOD.replace('"one"', '"one<br/>two"'))
        self.assertTrue(any("HTML" in p for p in probs))

    def test_sub_headings_are_refused(self):
        _, probs = self.check(GOOD.replace("**What this shows:** x.", "### Sub\n\n**What this shows:** x."))
        self.assertTrue(any("sub-headings" in p for p in probs))

    def test_both_lead_ins_are_required(self):
        _, probs = self.check(GOOD.replace("**Why this mechanism matters:**", "**Why:**"))
        self.assertTrue(any("Why this mechanism matters" in p for p in probs))

    def test_links_to_the_same_readme_are_refused_but_file_links_are_not(self):
        _, probs = self.check(GOOD.replace("x.", "see [a](#b)."))
        self.assertTrue(any("heading in this README" in p for p in probs))
        _, probs = self.check(GOOD.replace("x.", "see [a](../cobol/README.md)."))
        self.assertEqual(probs, [])

    def test_the_real_entries_all_pass(self):
        src = os.path.join(diagrams.HERE, "..", "..", "src")
        for d in sorted(os.listdir(src)):
            r = os.path.join(src, d, "README.md")
            if os.path.isfile(r):
                with open(r, encoding="utf-8") as f:
                    sec, probs = diagrams.program_flow(f.read(), d)
                self.assertEqual(probs, [], d)


class Scanner(unittest.TestCase):
    def test_fences_and_headings(self):
        items = diagrams.scan("# A\n\n```mermaid\n## not a heading\n```\n\n~~~~\n```inner\n~~~~\n\n## B\n")
        self.assertEqual([(i[0], i[2] if i[0] == "heading" else i[1]) for i in items], [("heading", "A"), ("fence", "mermaid"), ("fence", ""), ("heading", "B")])

    def test_diagram_family(self):
        self.assertEqual(diagrams.diagram_type("sequenceDiagram\n  A->>B: x"), "sequenceDiagram")
        self.assertEqual(diagrams.diagram_type("%% c\n\nstateDiagram-v2\n"), "stateDiagram-v2")


class FakeRenderer(diagrams.Renderer):
    def __init__(self, version="1", chrome="c1"):
        self.version, self.chrome_version = version, chrome
        with open(diagrams.CONFIG, "rb") as f:
            self.config_bytes = f.read()


class CacheKeys(unittest.TestCase):
    def test_the_key_follows_the_text_the_renderer_and_the_browser(self):
        r = FakeRenderer()
        a = r.key("flowchart TD\n A-->B")
        self.assertEqual(a, r.key("flowchart TD\n A-->B\n"), "trailing newlines do not matter")
        self.assertNotEqual(a, r.key("flowchart TD\n A-->C"), "editing the text changes the key")
        self.assertNotEqual(a, FakeRenderer(version="2").key("flowchart TD\n A-->B"), "a new Mermaid CLI changes the key")
        self.assertNotEqual(a, FakeRenderer(chrome="c2").key("flowchart TD\n A-->B"), "a new browser changes the key")
        r.config_bytes += b" "
        self.assertNotEqual(a, r.key("flowchart TD\n A-->B"), "a new style changes the key")

    def test_fit_never_enlarges_and_respects_the_page(self):
        self.assertEqual(diagrams.fit(300, 300)[2], 1.0)
        w, h, s = diagrams.fit(1280, 400)
        self.assertEqual(w, diagrams.FIT_W)
        w, h, s = diagrams.fit(300, 1400)
        self.assertEqual(h, diagrams.FIT_H)


class Embedding(unittest.TestCase):
    def test_a_fence_becomes_a_numbered_figure_with_alt_text_and_caption(self):
        src = "flowchart TD\n    accTitle: Cap <b>\n    accDescr: Alt \"q\"\n    A-->B"
        fig = diagrams.Figure("k", src, "somewhere")
        fig.w, fig.h = 400.0, 200.0
        fig.pw, fig.ph, fig.scale = 400, 200, 1.0
        out = diagrams.embed("before\n\n```mermaid\n" + src + "\n```\n\nafter", {src: fig}, "svg", [5])
        self.assertIn("<figcaption>Figure 5. Cap &lt;b&gt;</figcaption>", out)
        self.assertIn('alt="Alt &quot;q&quot;"', out)
        self.assertIn("width:400px;height:200px", out)
        self.assertNotIn("```", out)
        self.assertTrue(out.startswith("before") and out.endswith("after"))
        self.assertIn('width="400"', diagrams.embed("```mermaid\n" + src + "\n```", {src: fig}, "png", [1]))


@unittest.skipIf(diagrams.find_renderer()[0] is None, "Mermaid CLI or Chromium not installed: the render tests are skipped")
class RealRender(unittest.TestCase):
    def setUp(self):
        self.r = diagrams.find_renderer()[0]
        self.saved = diagrams.CACHE
        diagrams.CACHE = tempfile.mkdtemp()

    def tearDown(self):
        diagrams.CACHE = self.saved

    GOOD = "flowchart TD\n    accTitle: T\n    accDescr: D\n    A[one] --> B[two]"

    def test_render_cache_and_invalidation_touch_only_the_changed_figure(self):
        other = self.GOOD.replace("two", "three")
        figs, errs = diagrams.render_all(self.r, {self.GOOD: "a", other: "b"})
        self.assertEqual(errs, [])
        self.assertFalse(figs[self.GOOD].hit)
        self.assertTrue(figs[self.GOOD].w > 0 and os.path.getsize(figs[self.GOOD].png) > 100)
        files = {f: os.path.getmtime(os.path.join(diagrams.CACHE, f)) for f in os.listdir(diagrams.CACHE)}
        edited = self.GOOD.replace("one", "uno")
        figs2, errs = diagrams.render_all(self.r, {edited: "a", other: "b"})
        self.assertEqual(errs, [])
        self.assertFalse(figs2[edited].hit, "the edited diagram is drawn again")
        self.assertTrue(figs2[other].hit, "the unrelated diagram comes from the cache")
        for f in (figs[other].svg, figs[other].png):
            self.assertEqual(files[os.path.basename(f)], os.path.getmtime(f), "and its files were not touched")
        self.assertEqual(len(diagrams.orphans(figs2)), 2, "the old figure's two files are orphans")
        diagrams.prune(figs2)
        self.assertEqual(diagrams.orphans(figs2), [])

    def test_a_syntax_error_is_reported_and_leaves_no_figure(self):
        bad = "sequenceDiagram\n    A->>B: one; two"
        figs, errs = diagrams.render_all(self.r, {bad: "src/x/README.md, section '## Program Flow'"})
        self.assertEqual(len(errs), 1)
        self.assertIn("src/x/README.md", errs[0])
        self.assertIn("Parse error", errs[0])
        self.assertEqual(os.listdir(diagrams.CACHE), [], "no blank or partial figure is left behind")

    def test_the_output_is_the_same_twice(self):
        a, _ = diagrams.render_all(self.r, {self.GOOD: "a"})
        first = read(a[self.GOOD].svg)
        for f in os.listdir(diagrams.CACHE):
            os.remove(os.path.join(diagrams.CACHE, f))
        b, _ = diagrams.render_all(self.r, {self.GOOD: "a"})
        self.assertEqual(first, read(b[self.GOOD].svg))


if __name__ == "__main__":
    unittest.main(verbosity=1)
