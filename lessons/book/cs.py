"""Metadata-driven parts of the book: entry frontmatter, concept pages, generated chapters and tables.

Everything here is a pure function of files in the repository. There are no timestamps, no network
access and no dependence on directory listing order (every list is sorted), so the same sources
always produce the same bytes.

Sources (hand-written):
  src/<entry>/README.md          YAML frontmatter: name, kind, tags, ... (see ENTRY_FIELDS)
  lessons/cs-source/chapters/    one intro file per chapter:        NN-slug.md  (title)
  lessons/cs-source/concepts/    one file per computer-science concept: <id>.md (title, chapter, order)
  lessons/cs-source/roles/       one file per "what plays the loop" role: <id>.md (title, order)
  lessons/cs-source/index.md     intro of the "By computer science concept" opener
  lessons/book/link-hosts.txt    the only external hosts prose may link to

Output (generated, committed, and checked for drift by `build.py --check`):
  lessons/cs/*.md               the chapters and the opener
  <!-- BEGIN GENERATED name --> ... <!-- END GENERATED name -->   blocks inside other lessons pages

The frontmatter dialect is a strict subset of YAML so that no parser library is needed:
  key: plain text            key: "quoted text"           key: [item, item]
  # comment lines and blank lines are ignored. Anything else is an error.
"""
import json, os, posixpath, re
from urllib.parse import urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
LESSONS = os.path.dirname(HERE)
REPO = os.path.dirname(LESSONS)
SRC = os.path.join(REPO, "src")
CSSRC = os.path.join(LESSONS, "cs-source")
CSOUT = os.path.join(LESSONS, "cs")

KINDS = ("idiomatic", "weird", "port")
ASSURANCE = ("guaranteed", "implementation-permitted", "accidentally-exploited")
EVALUATION = ("eager", "lazy", "deferred", "rewriting", "search", "declarative")
# field -> (type, required)   type: str | list
ENTRY_FIELDS = {
    "name": ("str", True), "teaches": ("str", True), "kind": ("str", True), "languages": ("list", True),
    "lesson": ("str", True), "loop-by": ("str", True), "evaluation": ("str", True), "assurance": ("str", True),
    "tags": ("list", True), "pairs-with": ("str", False), "machine": ("str", False), "state": ("str", False),
}
CONCEPT_FIELDS = {"title": "str", "chapter": "str", "order": "str"}
ROLE_FIELDS = {"title": "str", "order": "str"}
CHAPTER_FIELDS = {"title": "str"}

def slug(heading):
    h = re.sub(r"`", "", heading.strip().lower())
    h = re.sub(r"[^\w\- ]", "", h)
    return h.replace(" ", "-")

class Problems(list):
    def add(self, where, msg):
        self.append(f"{where}: {msg}")

# ---------------------------------------------------------------- frontmatter

def parse_frontmatter(text, where, problems):
    """Return (dict, body). A file without frontmatter gives ({}, text)."""
    text = text.replace("\r\n", "\n")
    if not text.startswith("---\n"):
        return {}, text
    rest = text[4:] if text.endswith("\n") else text[4:] + "\n"
    end = rest.find("\n---\n") if not rest.startswith("---\n") else -1
    if rest.startswith("---\n"):          # empty block
        return {}, rest[4:]
    if end < 0:
        problems.add(where, "frontmatter starts with --- but has no closing ---")
        return {}, text
    block, body = rest[:end], rest[end + 5:]
    data = {}
    for n, line in enumerate(block.split("\n"), 2):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.fullmatch(r"([a-z][a-z0-9-]*):\s*(.*?)\s*", line)
        if not m:
            problems.add(where, f"line {n}: not 'key: value' ({line[:40]!r})")
            continue
        key, raw = m.groups()
        if key in data:
            problems.add(where, f"line {n}: duplicate key {key!r}")
        if raw.startswith("["):
            if not raw.endswith("]"):
                problems.add(where, f"line {n}: list does not end with ]")
                continue
            inner = raw[1:-1].strip()
            data[key] = [i.strip() for i in inner.split(",")] if inner else []
        elif raw.startswith('"'):
            try:
                data[key] = json.loads(raw)
            except ValueError:
                problems.add(where, f"line {n}: bad quoted string")
        else:
            if " #" in raw:
                problems.add(where, f"line {n}: '#' comment after a value; quote the value or move the comment")
            data[key] = raw
    return data, body

def check_fields(data, spec, where, problems):
    for k in data:
        if k not in spec:
            problems.add(where, f"unknown frontmatter key {k!r} (allowed: {', '.join(sorted(spec))})")

# ---------------------------------------------------------------- loading

def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read().replace("\r\n", "\n")

def load_entries(problems):
    entries = {}
    for d in sorted(os.listdir(SRC)):
        readme = os.path.join(SRC, d, "README.md")
        if not os.path.isfile(readme):
            continue
        where = f"src/{d}/README.md"
        text = read(readme)
        data, body = parse_frontmatter(text, where, problems)
        if not data:
            problems.add(where, "no frontmatter; add the block described in CONTRIBUTING.md")
            continue
        check_fields(data, {k: v[0] for k, v in ENTRY_FIELDS.items()}, where, problems)
        for k, (typ, req) in ENTRY_FIELDS.items():
            if k not in data:
                if req:
                    problems.add(where, f"missing required key {k!r}")
                continue
            if typ == "list" and not isinstance(data[k], list):
                problems.add(where, f"{k!r} must be a [list]")
            if typ == "str" and not isinstance(data[k], str):
                problems.add(where, f"{k!r} must be text, not a list")
        data["dir"] = d
        data["_body"] = body
        entries[d] = data
    return entries

def load_dir(sub, spec, problems):
    out = {}
    base = os.path.join(CSSRC, sub)
    if not os.path.isdir(base):
        return out
    for fn in sorted(os.listdir(base)):
        if not fn.endswith(".md"):
            continue
        where = f"lessons/cs-source/{sub}/{fn}"
        data, body = parse_frontmatter(read(os.path.join(base, fn)), where, problems)
        check_fields(data, spec, where, problems)
        for k in spec:
            if k not in data:
                problems.add(where, f"missing required key {k!r}")
        data["id"] = fn[:-3]
        data["body"] = body.strip("\n")
        out[data["id"]] = data
    return out

class Model:
    def __init__(self):
        self.problems = Problems()
        p = self.problems
        self.entries = load_entries(p)
        self.concepts = load_dir("concepts", CONCEPT_FIELDS, p)
        self.roles = load_dir("roles", ROLE_FIELDS, p)
        self.chapters = load_dir("chapters", CHAPTER_FIELDS, p)
        self.index = parse_frontmatter(read(os.path.join(CSSRC, "index.md")), "cs-source/index.md", p)[1].strip("\n") \
            if os.path.isfile(os.path.join(CSSRC, "index.md")) else ""
        self.hosts = self._hosts()
        self.languages = self._languages()
        for c in self.concepts.values():
            try:
                c["chapter"], c["order"] = int(c["chapter"]), int(c["order"])
            except (ValueError, KeyError):
                p.add(f"concept {c['id']}", "chapter and order must be whole numbers")
                c["chapter"], c["order"] = 0, 0
        for r in self.roles.values():
            try:
                r["order"] = int(r["order"])
            except (ValueError, KeyError):
                p.add(f"role {r['id']}", "order must be a whole number"); r["order"] = 0
        self.chapter_files = {}      # chapter number -> file name
        for cid, ch in self.chapters.items():
            m = re.fullmatch(r"(\d\d)-.+", cid)
            if not m:
                p.add(f"chapter {cid}", "file name must start with two digits, e.g. 03-control-flow.md")
                continue
            ch["number"] = int(m.group(1))
            self.chapter_files[ch["number"]] = cid + ".md"
        self._lint()

    def _languages(self):
        """id -> display name, from lessons/cs-source/languages.txt (`id: Name`, optional quotes)."""
        path = os.path.join(CSSRC, "languages.txt")
        out = {}
        if not os.path.isfile(path):
            self.problems.add("lessons/cs-source/languages.txt", "missing")
            return out
        for n, line in enumerate(read(path).splitlines(), 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            m = re.fullmatch(r"([a-z][a-z0-9-]*):\s*(.+?)\s*", line)
            if not m:
                self.problems.add("lessons/cs-source/languages.txt", f"line {n}: not 'id: Name'")
                continue
            name = m.group(2)
            out[m.group(1)] = name[1:-1] if len(name) > 1 and name[0] == name[-1] == '"' else name
        return out

    def lang_names(self, e):
        return ", ".join(self.languages.get(l, l) for l in e["languages"])

    def _hosts(self):
        path = os.path.join(HERE, "link-hosts.txt")
        if not os.path.isfile(path):
            return set()
        return {l.strip() for l in read(path).splitlines() if l.strip() and not l.startswith("#")}

    def _lint(self):
        p = self.problems
        for d, e in sorted(self.entries.items()):
            w = f"src/{d}/README.md"
            if e.get("kind") not in KINDS and "kind" in e:
                p.add(w, f"kind must be one of {KINDS}")
            if e.get("assurance") not in ASSURANCE and "assurance" in e:
                p.add(w, f"assurance must be one of {ASSURANCE}")
            if e.get("evaluation") not in EVALUATION and "evaluation" in e:
                p.add(w, f"evaluation must be one of {EVALUATION}")
            if e.get("loop-by") and e["loop-by"] not in self.roles:
                p.add(w, f"loop-by {e['loop-by']!r} is not a role in lessons/cs-source/roles/")
            for t in e.get("tags", []):
                if t not in self.concepts:
                    p.add(w, f"unknown tag {t!r}; tags are the file names in lessons/cs-source/concepts/ "
                             f"(a maintainer adds new ones)")
            if len(set(e.get("tags", []))) != len(e.get("tags", [])):
                p.add(w, "duplicate tag")
            for l in e.get("languages", []):
                if l not in self.languages:
                    p.add(w, f"unknown language {l!r}; languages are listed in lessons/cs-source/languages.txt "
                             f"(a maintainer adds new ones)")
            if "pairs-with" in e and e["pairs-with"] not in self.entries:
                p.add(w, f"pairs-with {e['pairs-with']!r} is not an entry")
            if ("machine" in e) != ("state" in e):
                p.add(w, "machine and state go together: give both or neither")
            if "lesson" in e:
                self._check_lesson(w, e["lesson"])
            m = re.search(r"^\*\*Teaches you:\*\* (.+)$", e["_body"], re.M)
            if m and "teaches" in e and m.group(1).strip() != e["teaches"]:
                p.add(w, "'teaches' differs from the README's **Teaches you:** line; make them identical")
        for cid, c in sorted(self.concepts.items()):
            w = f"concept {cid}"
            if not re.fullmatch(r"[a-z][a-z0-9-]*", cid):
                p.add(w, "id must be lowercase letters, digits and hyphens")
            if c["chapter"] not in self.chapter_files:
                p.add(w, f"chapter {c['chapter']} has no file in lessons/cs-source/chapters/")
            if c["chapter"] == 9:
                p.add(w, "chapter 9 is generated from roles; concepts belong in 1-8")
            if not c["body"].strip():
                p.add(w, "empty body")
            self._lint_links(w, c["body"])
        for rid, r in sorted(self.roles.items()):
            self._lint_links(f"role {rid}", r["body"])
        for n in range(1, 10):
            if n not in self.chapter_files:
                p.add("chapters", f"chapter {n} is missing in lessons/cs-source/chapters/")
        for cid, ch in self.chapters.items():
            self._lint_links(f"chapter {cid}", ch["body"])
        for name, o in (("concept", self.concepts), ("role", self.roles)):
            orders = {}
            for i, x in o.items():
                key = (x.get("chapter", 0), x["order"]) if name == "concept" else x["order"]
                orders.setdefault(key, []).append(i)
            for k, ids in orders.items():
                if len(ids) > 1:
                    p.add(name + "s", f"same order {k} for {', '.join(sorted(ids))}")

    def _check_lesson(self, where, lesson):
        path, _, frag = lesson.partition("#")
        full = os.path.join(LESSONS, path)
        if not os.path.isfile(full):
            self.problems.add(where, f"lesson {lesson!r}: no such file under lessons/")
        elif frag:
            heads = {slug(m.group(2)) for m in re.finditer(r"^(#{1,6}) (.+)$", read(full), re.M)}
            if frag not in heads:
                self.problems.add(where, f"lesson {lesson!r}: no heading with that anchor")

    def _lint_links(self, where, text):
        for url in urls_in(text):
            u = urlparse(url)
            if u.scheme != "https":
                self.problems.add(where, f"external link must be https: {url}")
            elif u.hostname not in self.hosts:
                self.problems.add(where, f"link host {u.hostname!r} is not in lessons/book/link-hosts.txt: {url}")
            elif u.hostname == "en.wikipedia.org" and not re.match(r"/wiki/[^/?#]+$", u.path):
                self.problems.add(where, f"Wikipedia links must look like https://en.wikipedia.org/wiki/Title: {url}")
            elif u.hostname == "www.rfc-editor.org" and not re.fullmatch(r"/rfc/rfc\d+", u.path):
                self.problems.add(where, f"RFC links must look like https://www.rfc-editor.org/rfc/rfc2119: {url}")

def urls_in(text):
    found = []
    for m in re.finditer(r"https?://[^\s<>\"]+", text):
        u = m.group(0)
        while u and (u[-1] in ".,;:*_" or (u[-1] == ")" and u.count(")") > u.count("("))):
            u = u[:-1]
        found.append(u)
    return found

# ---------------------------------------------------------------- generation helpers

def cell(text):
    return text.replace("|", "\\|").replace("\n", " ")

def table(header, rows):
    out = ["| " + " | ".join(header) + " |", "| " + " | ".join("---" for _ in header) + " |"]
    out += ["| " + " | ".join(cell(c) for c in r) + " |" for r in rows]
    return "\n".join(out)

class Links:
    """Relative links from a file in lessons/<where>/ (where = '' for lessons/ itself)."""
    def __init__(self, model, where):
        self.m, self.where = model, where
    def lessons(self, path):
        return posixpath.relpath(path, self.where or ".")
    def repo(self, path):
        return posixpath.relpath("../" + path, self.where or ".")
    def entry(self, d):
        return f"[`{d}`]({self.repo('src/' + d + '/README.md')})"
    def concept(self, cid, text=None):
        c = self.m.concepts[cid]
        return f"[{text or c['title']}]({self.lessons('cs/' + self.m.chapter_files[c['chapter']])}#{slug(c['title'])})"
    def role(self, rid, text=None):
        r = self.m.roles[rid]
        return f"[{text or r['title']}]({self.lessons('cs/' + self.m.chapter_files[9])}#{slug(r['title'])})"
    def lesson(self, lesson):
        return f"[{lesson.partition('#')[0].rsplit('/', 1)[-1][:-3]}]({self.lessons(lesson)})"

def sorted_entries(model, pred=lambda e: True):
    return sorted((e for e in model.entries.values() if pred(e)), key=lambda e: (e["name"].casefold(), e["dir"]))

def tbl_machines(model, L):
    rows = [(e["name"], e["machine"], e["state"],
             f"[{e['lesson'].partition('#')[0].rsplit('/', 1)[-1][:-3]}]({L.lessons(e['lesson'])})")
            for e in sorted_entries(model, lambda e: "machine" in e)]
    return table(["Language / tool", "The machine it really is", "Where the program's state lives", "Lesson"], rows)

def tbl_control_state(model, L):
    rows = [(e["state"], f"{L.lesson(e['lesson'])}: {L.entry(e['dir'])}") for e in sorted_entries(model, lambda e: "state" in e)]
    return table(["Place", "Entry"], rows)

def tbl_evaluation(model, L):
    rows = [(L.entry(e["dir"]), e["name"], e["evaluation"]) for e in sorted_entries(model)]
    rows.sort(key=lambda r: (EVALUATION.index(r[2]), r[1].casefold()))
    return table(["Entry", "Name", "Evaluation"], rows)

def tbl_glance(model, L):
    rows = []
    for e in sorted_entries(model):
        rows.append((L.entry(e["dir"]), model.lang_names(e), e["kind"], L.role(e["loop-by"], model.roles[e["loop-by"]]["title"]), e["evaluation"],
                     e["assurance"], L.entry(e["pairs-with"]) if "pairs-with" in e else ""))
    return table(["Entry", "Languages", "Kind", "What plays the loop", "Evaluation", "Assurance", "Pairs with"], rows)

def cap(text):
    return text[:1].upper() + text[1:]

def tbl_entries_for(model, L, pred):
    rows = [(L.entry(e["dir"]), model.lang_names(e), cap(e["teaches"])) for e in sorted_entries(model, pred)]
    return table(["Entry", "Language", "What it teaches"], rows) if rows else ""

def blk_roles(model, L, expand):
    parts = []
    for rid, r in sorted(model.roles.items(), key=lambda kv: kv[1]["order"]):
        rows = [(L.entry(e["dir"]), model.lang_names(e), e.get("machine", ""), e.get("state", ""), e["evaluation"], e["assurance"])
                for e in sorted_entries(model, lambda e: e["loop-by"] == rid)]
        body = expand(r["body"])
        if rows:
            body += "\n\n**Entries:**\n\n" + table(["Entry", "Language", "The machine", "Where the state lives", "Evaluation", "Assurance"], rows)
        else:
            body += "\n\n*No entry uses this yet.*"
        parts.append(f"## {r['title']}\n\n{body}")
    return "\n\n".join(parts)

def blk_concepts_of(model, L, lesson_file):
    ids = sorted({t for e in model.entries.values() if e["lesson"].partition("#")[0] == lesson_file for t in e["tags"]},
                 key=lambda t: (model.concepts[t]["chapter"], model.concepts[t]["order"]))
    if not ids:
        return ""
    return "The computer-science ideas behind this page: " + ", ".join(L.concept(t) for t in ids) + "."

TABLES = {"machines": tbl_machines, "control-state": tbl_control_state, "evaluation": tbl_evaluation, "glance": tbl_glance}

def make_expander(model, L):
    def expand(text):
        def wiki(m):
            target, _, label = m.group(1).partition("|")
            if target.startswith("entry:"):
                d = target[6:]
                if d not in model.entries:
                    model.problems.add("prose", f"[[{m.group(1)}]]: no such entry")
                    return m.group(0)
                return f"[{label}]({L.repo('src/' + d + '/README.md')})" if label else L.entry(d)
            if target.startswith("role:"):
                if target[5:] not in model.roles:
                    model.problems.add("prose", f"[[{m.group(1)}]]: no such role"); return m.group(0)
                return L.role(target[5:], label or None)
            if target not in model.concepts:
                model.problems.add("prose", f"[[{m.group(1)}]]: no such concept")
                return m.group(0)
            return L.concept(target, label or None)
        text = re.sub(r"\[\[([^\]]+)\]\]", wiki, text)
        def tbl(m):
            name = m.group(1)
            if name == "roles":
                return blk_roles(model, L, expand)
            if name not in TABLES:
                model.problems.add("prose", f"{{{{table:{name}}}}}: no such table"); return m.group(0)
            return TABLES[name](model, L)
        return re.sub(r"\{\{table:([a-z-]+)\}\}", tbl, text)
    return expand

# ---------------------------------------------------------------- generated files

BANNER = "<!-- GENERATED by lessons/book/build.py from lessons/cs-source/ and the entries' frontmatter. Do not edit; edit the sources and run build.py. -->"

def generate_cs(model):
    """-> {path relative to lessons/: text}"""
    out = {}
    L = Links(model, "cs")
    expand = make_expander(model, L)
    for n, fn in sorted(model.chapter_files.items()):
        ch = model.chapters[fn[:-3]]
        parts = [BANNER, f"# {ch['title']}", expand(ch["body"])]
        for cid, c in sorted(((i, c) for i, c in model.concepts.items() if c["chapter"] == n), key=lambda kv: kv[1]["order"]):
            parts.append(f"## {c['title']}\n\n{expand(c['body'])}")
            tbl = tbl_entries_for(model, L, lambda e, cid=cid: cid in e["tags"])
            parts.append("**In this repo:**\n\n" + tbl if tbl else "**In this repo:** no entry uses this yet; it is background for the others.")
        out["cs/" + fn] = "\n\n".join(p for p in parts if p.strip()) + "\n"
    # opener: chapter list, then an A-Z index
    chapters = []
    for n, fn in sorted(model.chapter_files.items()):
        title = model.chapters[fn[:-3]]["title"]
        ids = [c["title"] for _, c in sorted(((i, c) for i, c in model.concepts.items() if c["chapter"] == n), key=lambda kv: kv[1]["order"])]
        if n == 9:
            ids = [r["title"] for r in sorted(model.roles.values(), key=lambda r: r["order"])]
        chapters.append(f"- [{title}]({fn})" + (f": {', '.join(ids)}" if ids else ""))
    idx = table(["Concept", "Chapter", "Entries that use it"], [
        (L.concept(cid), model.chapters[model.chapter_files[c["chapter"]][:-3]]["title"],
         ", ".join(f"`{d}`" for d in sorted((d for d, e in model.entries.items() if cid in e["tags"]), key=str.casefold)))
        for cid, c in sorted(model.concepts.items(), key=lambda kv: kv[1]["title"].casefold())])
    out["cs/README.md"] = "\n\n".join([BANNER, "# By computer science concept", expand(model.index),
                                       "## The chapters\n\n" + "\n".join(chapters), "## Concept index\n\n" + idx]) + "\n"
    return out

def letter(text):
    for ch in text:
        if ch.isalnum():
            return ch.upper() if ch.isalpha() else "0-9"
    return "#"

def lettered(items):
    """items: [(sort key, markdown line)] -> markdown with a bold letter heading before each group."""
    out, cur = [], None
    for key, line in sorted(items, key=lambda kv: (kv[0].casefold(), kv[0])):
        l = letter(key)
        if l != cur:
            out += ["", f"**{l}**", ""]
            cur = l
        out.append(line)
    return "\n".join(out).strip("\n")

def lesson_title(rel):
    for line in read(os.path.join(LESSONS, rel)).splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return rel

def generate_index(model):
    L = Links(model, "")
    dirs = lambda ids: ", ".join(L.entry(d) for d in sorted(ids, key=str.casefold))
    concepts = [(c["title"], f"- {L.concept(cid)}: "
                 + (dirs(d for d, e in model.entries.items() if cid in e["tags"]) or "background for the others"))
                for cid, c in model.concepts.items()]
    langs = []
    for lid, name in model.languages.items():
        es = [d for d, e in model.entries.items() if lid in e["languages"]]
        if not es:
            continue
        pages = sorted({model.entries[d]["lesson"].partition("#")[0] for d in es})
        langs.append((name, f"- **{name}**: lesson " + ", ".join(f"[{lesson_title(p)}]({p})" for p in pages)
                      + "; entries " + dirs(es)))
    entries = [(d, f"- {L.entry(d)}: {model.lang_names(e)}; {e['kind']}; "
                   + L.role(e["loop-by"], model.roles[e["loop-by"]]["title"]))
               for d, e in model.entries.items()]
    roles = [(r["title"], f"- {L.role(rid)}: " + dirs(d for d, e in model.entries.items() if e["loop-by"] == rid))
             for rid, r in model.roles.items()]
    wrap = lambda body: '<div class="book-index">\n\n' + body + "\n\n</div>"
    parts = [BANNER, "# Index",
             "Three indexes, all built from the metadata at the top of each entry's README: the computer-science "
             "concepts, the languages, and the entries themselves. In the PDF, a page number follows each link "
             "that points inside the book.",
             "## Index of concepts", wrap(lettered(concepts)),
             "## Index of languages", wrap(lettered(langs)),
             "## Index of entries", wrap(lettered(entries)),
             "## Index of roles: what plays the loop", wrap(lettered(roles))]
    return "\n\n".join(parts) + "\n"

MARK = re.compile(r"(<!-- BEGIN GENERATED ([\w:./-]+) -->)\n.*?(<!-- END GENERATED \2 -->)", re.S)

def generate_blocks(model, rel):
    """Return the text of lessons/<rel> with its generated blocks refreshed (unchanged if it has none)."""
    text = read(os.path.join(LESSONS, rel))
    L = Links(model, posixpath.dirname(rel))
    def sub(m):
        name = m.group(2)
        if name in TABLES:
            body = TABLES[name](model, L)
        elif name.startswith("concepts:"):
            body = blk_concepts_of(model, L, name[9:])
        else:
            model.problems.add(rel, f"unknown generated block {name!r}")
            return m.group(0)
        return m.group(1) + "\n" + body + "\n" + m.group(3)
    return MARK.sub(sub, text)

BLOCK_FILES = ["goals.md", "patterns.md", "languages/README.md"] + \
              [f"languages/{f}" for f in sorted(os.listdir(os.path.join(LESSONS, "languages"))) if f.endswith(".md") and f != "README.md"]

def generate_all(model):
    files = generate_cs(model)
    files["index.md"] = generate_index(model)
    for rel in BLOCK_FILES:
        new = generate_blocks(model, rel)
        if new != read(os.path.join(LESSONS, rel)):
            files[rel] = new
    return files

def write_all(files):
    for rel, text in files.items():
        path = os.path.join(LESSONS, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

def drift(files):
    """Generated files whose committed text differs from what the sources produce."""
    bad = []
    for rel, text in sorted(files.items()):
        path = os.path.join(LESSONS, rel)
        if not os.path.isfile(path) or read(path) != text:
            bad.append("lessons/" + rel)
    cs = os.path.join(CSOUT)
    if os.path.isdir(cs):
        for fn in sorted(os.listdir(cs)):
            if "cs/" + fn not in files:
                bad.append(f"lessons/cs/{fn} (stale: no source produces it)")
    return bad

def check_links(model):
    """Network check (NOT part of the deterministic build): every external link in the prose must load.
    Returns a list of failure strings."""
    import urllib.request, urllib.error
    urls = {}
    texts = [(f"concept {i}", c["body"]) for i, c in model.concepts.items()] + \
            [(f"role {i}", r["body"]) for i, r in model.roles.items()] + \
            [(f"chapter {i}", c["body"]) for i, c in model.chapters.items()] + [("index", model.index)]
    for where, text in texts:
        for u in urls_in(text):
            urls.setdefault(u, where)
    bad = []
    for u, where in sorted(urls.items()):
        req = urllib.request.Request(u, headers={"User-Agent": "code-challenge-link-check/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                if r.status != 200:
                    bad.append(f"{where}: HTTP {r.status}: {u}")
        except urllib.error.HTTPError as e:
            bad.append(f"{where}: HTTP {e.code}: {u}")
        except Exception as e:
            bad.append(f"{where}: {type(e).__name__}: {u}")
    print(f"checked {len(urls)} external link(s)")
    return bad
