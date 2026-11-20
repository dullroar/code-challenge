"""Where the published documents point when they link into the repository.

The Markdown sources link to files with relative paths, which is right on GitHub and in a clone. A PDF or EPUB is one
document with no repository around it, so those links become absolute GitHub URLs when the document is built. This module
is the only place that knows the repository's web address.

  * The default is the canonical repository below. It is a constant, not a guess: the build never reads `git remote`, so a
    fork, a clone with a remote alias, an offline checkout and a release build all produce the same bytes.
  * A fork that wants its own links sets REPOSITORY_WEB_BASE (and, if it publishes another branch, REPOSITORY_BRANCH).
  * Renaming the repository again means changing DEFAULT_WEB_BASE here and nowhere else.
"""
import os
import re
from urllib.parse import quote

DEFAULT_WEB_BASE = "https://github.com/dullroar/learn-programming-the-weird-way"
DEFAULT_BRANCH = "master"

# RFC 3986 pchar: what may stay unescaped in a path segment or a fragment.
_SAFE = "-_.~!$&'()*+,;=:@/"


def web_base(environ=None):
    """The repository's web address, without a trailing slash. REPOSITORY_WEB_BASE overrides the default."""
    env = os.environ if environ is None else environ
    base = (env.get("REPOSITORY_WEB_BASE") or DEFAULT_WEB_BASE).strip().rstrip("/")
    if not re.fullmatch(r"https://[A-Za-z0-9.-]+(?::\d+)?(?:/[A-Za-z0-9._~-]+)+", base):
        raise SystemExit(f"REPOSITORY_WEB_BASE must be an https URL with a path, such as {DEFAULT_WEB_BASE}; got {base!r}")
    return base


def branch(environ=None):
    env = os.environ if environ is None else environ
    name = (env.get("REPOSITORY_BRANCH") or DEFAULT_BRANCH).strip()
    if not re.fullmatch(r"[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*", name):
        raise SystemExit(f"REPOSITORY_BRANCH is not a plain branch name: {name!r}")
    return name


def blob_base(environ=None):
    """The prefix of a link to a file: .../blob/<branch>/ (with the trailing slash)."""
    return f"{web_base(environ)}/blob/{quote(branch(environ), safe='/')}/"


def tree_base(environ=None):
    return f"{web_base(environ)}/tree/{quote(branch(environ), safe='/')}/"


def file_url(path, fragment="", environ=None):
    """URL of a file given its repo-root-relative posix path; the fragment (an anchor, without '#') is kept."""
    return blob_base(environ) + quote(path, safe=_SAFE) + ("#" + quote(fragment, safe=_SAFE) if fragment else "")


def folder_url(path, environ=None):
    """URL of a folder given its repo-root-relative posix path. A folder has no anchor."""
    return tree_base(environ) + quote(path, safe=_SAFE)


def label(environ=None):
    """The address as shown to a reader: no scheme."""
    return web_base(environ).removeprefix("https://")


def fill_placeholders(text, environ=None):
    """Replace the two placeholders the front-matter files use: {{REPOSITORY_WEB_URL}} and {{REPOSITORY_WEB_LABEL}}."""
    return text.replace("{{REPOSITORY_WEB_URL}}", web_base(environ)).replace("{{REPOSITORY_WEB_LABEL}}", label(environ))
