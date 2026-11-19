#!/usr/bin/env python3
"""Queue guides for review after source changes. See the study-guide README."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import posixpath
import re
import subprocess
from urllib.parse import unquote, urlsplit

import cs
import study_guides

ROOT = Path(study_guides.REPO)
GUIDE_ROOT = "lessons/study-guides/"
MANIFEST = "lessons/book/guide-dependencies.json"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, stdout=subprocess.PIPE).stdout


def changed_sources(base, head, worktree):
    target = [] if worktree else [head]
    paths = git("diff", "--name-only", "-z", "--no-renames", base, *target, "--").split(b"\0")
    if worktree:
        paths += git("ls-files", "--others", "--exclude-standard", "-z").split(b"\0")
    return sorted({p.decode() for p in paths if p and is_source(p.decode())})


def is_source(path):
    return bool(re.match(
        r"^(?:src/[^/]+/.+|lessons/(?:cs-source/.+|solutions/.+|tools/.+|languages/[^/]+\.md|[^/]+\.md))$",
        path,
    )) and path != "lessons/index.md"


def linked_paths(guide, text):
    base = posixpath.dirname(GUIDE_ROOT + guide)
    paths = set()
    for link in study_guides.LINK.finditer(text):
        target = urlsplit(link[2])
        if target.path and not target.scheme and not target.netloc:
            paths.add(posixpath.normpath(posixpath.join(base, unquote(target.path))))
    return paths


def candidate_reviews(paths, guides, indirect):
    """Return the source paths that triggered review of each candidate guide."""
    queue = {}
    links = {guide: linked_paths(guide, text) for guide, text in guides.items()}
    for path in paths:
        parts = PurePosixPath(path).parts
        subject = parts[1] if parts[0] == "src" else PurePosixPath(path).stem
        # A guide can name an entry or concept without linking to this file.
        mentions = re.compile(r"(?<![\w-])" + re.escape(subject) + r"(?![\w-])", re.I)
        dependencies = indirect.get(path, ())
        for guide, text in guides.items():
            explicit = path in links[guide] or mentions.search(text)
            if parts[0] == "src":
                explicit = explicit or subject in study_guides.EXPECTED_DIAGRAMS.get(guide, ())
            if explicit or guide in dependencies or "*" in dependencies:
                queue.setdefault(guide, []).append(path)
    return queue


def review_token(sources, before, after, guide_text):
    evidence = [
        (path, hashlib.sha256(before[path]).hexdigest() if before[path] is not None else None,
         hashlib.sha256(after[path]).hexdigest() if after[path] is not None else None)
        for path in sorted(sources)
    ]
    return hashlib.sha256(json.dumps([evidence, guide_text]).encode()).hexdigest()


def missing_reviews(tokens, reviewed):
    return sorted(guide for guide, token in tokens.items() if reviewed.get(guide) != token)


def snapshot(ref, path):
    if ref is None:
        file = ROOT / path
        return file.read_bytes() if file.is_file() else None
    blob = subprocess.run(["git", "show", f"{ref}:{path}"], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return blob.stdout if blob.returncode == 0 else None


def author_text(path, content):
    if content is not None and path.startswith("lessons/languages/"):
        return cs.MARK.sub("", content.decode()).encode()
    return content


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", help="Git revision to compare with HEAD")
    parser.add_argument("--worktree", action="store_true", help="Review local edits before committing")
    parser.add_argument("--check-review", type=Path, help="Require current tokens from this reviewed JSON record")
    args = parser.parse_args()
    base = git("rev-parse", "--verify", "--end-of-options", args.base + "^{commit}").decode().strip()
    head = git("rev-parse", "HEAD").decode().strip()
    target = None if args.worktree else head
    paths = changed_sources(base, head, args.worktree)
    before = {path: author_text(path, snapshot(base, path)) for path in paths}
    after = {path: author_text(path, snapshot(target, path)) for path in paths}
    # Generated blocks in language lessons are already accounted for by their authoritative sources.
    paths = [path for path in paths if before[path] != after[path]]
    guides = {}
    for guide in study_guides.ALL_GUIDES:
        content = snapshot(target, GUIDE_ROOT + guide)
        if content is not None:
            guides[guide] = content.decode()
    indirect = json.loads(snapshot(target, MANIFEST) or b"{}")
    queue = candidate_reviews(paths, guides, indirect)
    tokens = {}
    for guide, sources in sorted(queue.items()):
        tokens[guide] = review_token(sources, before, after, guides[guide])
        print(f"{guide} {tokens[guide]}\n  " + "\n  ".join(sorted(sources)))
    matched = {path for sources in queue.values() for path in sources}
    unmatched = sorted(set(paths) - matched - indirect.keys())
    for path in unmatched:
        print(f"Review for indirect dependencies: {path} (no candidate guide found)")
    if args.check_review:
        reviewed = json.loads(args.check_review.read_text(encoding="utf-8"))
        missing = missing_reviews(tokens, reviewed)
        for guide in missing:
            print(f"Review missing or stale: {guide}")
        return int(bool(missing or unmatched))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
