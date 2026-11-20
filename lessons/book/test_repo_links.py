"""Tests for the one place that knows the repository's web address, and for how the book's link rewrite uses it."""
import os
import unittest
from unittest.mock import patch

import build
import repo_links

BASE = "https://github.com/dullroar/learn-programming-the-weird-way"


class Resolver(unittest.TestCase):
    def test_canonical_default_needs_no_environment_and_no_git(self):
        self.assertEqual(repo_links.web_base({}), BASE)
        self.assertEqual(repo_links.blob_base({}), BASE + "/blob/master/")
        self.assertEqual(repo_links.tree_base({}), BASE + "/tree/master/")

    def test_a_fork_overrides_the_base_and_the_branch(self):
        env = {"REPOSITORY_WEB_BASE": "https://github.com/someone/their-fork/", "REPOSITORY_BRANCH": "release/2"}
        self.assertEqual(repo_links.file_url("src/apl/README.md", environ=env),
                         "https://github.com/someone/their-fork/blob/release/2/src/apl/README.md")
        self.assertEqual(repo_links.folder_url("src/apl", environ=env), "https://github.com/someone/their-fork/tree/release/2/src/apl")

    def test_an_empty_override_means_the_default(self):
        self.assertEqual(repo_links.web_base({"REPOSITORY_WEB_BASE": ""}), BASE)

    def test_a_bad_override_is_refused(self):
        for bad in ("http://github.com/a/b", "github.com/a/b", "https://github.com", "https://github.com/a/b c", "javascript:alert(1)"):
            with self.subTest(bad=bad), self.assertRaises(SystemExit):
                repo_links.web_base({"REPOSITORY_WEB_BASE": bad})
        with self.assertRaises(SystemExit):
            repo_links.branch({"REPOSITORY_BRANCH": "a b"})

    def test_paths_and_anchors_are_encoded(self):
        self.assertEqual(repo_links.file_url("lessons/My Code Challenge.pdf", environ={}), BASE + "/blob/master/lessons/My%20Code%20Challenge.pdf")
        self.assertEqual(repo_links.file_url("a/b.md", "run-it-1", environ={}), BASE + "/blob/master/a/b.md#run-it-1")
        self.assertEqual(repo_links.file_url("a/b.md", "a b?", environ={}), BASE + "/blob/master/a/b.md#a%20b%3F")
        self.assertEqual(repo_links.file_url("src/c#/x.md", environ={}), BASE + "/blob/master/src/c%23/x.md")

    def test_the_label_has_no_scheme_and_placeholders_are_filled(self):
        self.assertEqual(repo_links.label({}), "github.com/dullroar/learn-programming-the-weird-way")
        text = '<a href="{{REPOSITORY_WEB_URL}}">{{REPOSITORY_WEB_LABEL}}</a>'
        self.assertEqual(repo_links.fill_placeholders(text, {}), f'<a href="{BASE}">github.com/dullroar/learn-programming-the-weird-way</a>')


class LinkTarget(unittest.TestCase):
    """build.link_target for a link written in lessons/languages/x.md (so ../ reaches lessons/, ../../ the repository root)."""
    chapter = "languages/x.md"

    def resolve(self, target):
        return build.link_target(target, self.chapter, {}, {self.chapter: {}})

    def test_a_file_in_the_repository_becomes_a_blob_url(self):
        self.assertEqual(self.resolve("../../src/apl/README.md"), BASE + "/blob/master/src/apl/README.md")

    def test_a_folder_becomes_a_tree_url_and_ignores_the_anchor_rule(self):
        self.assertEqual(self.resolve("../../src/apl"), BASE + "/tree/master/src/apl")
        self.assertEqual(self.resolve("../../src/apl/"), BASE + "/tree/master/src/apl")

    def test_anchors_and_encoded_spaces_survive(self):
        self.assertEqual(self.resolve("../../README.md#the-list"), BASE + "/blob/master/README.md#the-list")
        self.assertEqual(self.resolve("../../src/a%20b/c.md"), BASE + "/blob/master/src/a%20b/c.md")

    def test_links_that_are_not_repository_paths_are_left_alone(self):
        for target in ("https://example.org/x", "mailto:a@b.c", "/absolute", "../../../outside.md", ""):
            with self.subTest(target=target):
                self.assertEqual(self.resolve(target), target)

    def test_the_old_repository_name_never_appears(self):
        self.assertNotIn("code-challenge", self.resolve("../../src/apl/README.md"))

    def test_an_override_reaches_every_published_link(self):
        with patch.dict(os.environ, {"REPOSITORY_WEB_BASE": "https://github.com/x/y"}):
            self.assertEqual(build.repo_links.file_url("a.md"), "https://github.com/x/y/blob/master/a.md")


if __name__ == "__main__":
    unittest.main()
