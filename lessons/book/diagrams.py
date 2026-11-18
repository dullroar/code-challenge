"""Program Flow diagrams for the book: find them, check them, render them, put them in the page.

The source of truth is text. Every `src/<entry>/README.md` has one `## Program Flow` section with one Mermaid
fenced block and a few sentences. This module:

  * reads Markdown *structurally* (a fence-aware scanner, not a regex over loose text), so a heading or a
    fence inside a code block is never mistaken for the real thing;
  * validates a Program Flow section against the README contract (see CONTRIBUTING.md);
  * renders Mermaid text to SVG (for the PDF and HTML) and PNG (for the EPUB) with one pinned renderer,
    Mermaid CLI, and caches the result under a key made from the diagram text, the renderer and browser versions
    and the style configuration, so changing any of them re-renders exactly the affected figures;
  * replaces each ```mermaid fence in the book's Markdown with an HTML <figure> before pandoc sees it.

Standard library only. The renderer (Node + Mermaid CLI + a Chromium) is needed only to render. The structural
checks run without it, and `build.py --check` says which kind of check ran.
"""
import concurrent.futures, glob, hashlib, json, os, re, shutil, struct, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
DIAGRAM_TOOLS = os.path.join(HERE, "diagrams")           # package.json, package-lock.json, mermaid-config.json
CONFIG = os.path.join(DIAGRAM_TOOLS, "mermaid-config.json")
CACHE = os.path.join(HERE, "out", "diagrams")            # git-ignored build output (lessons/book/out/)

SECTION = "Program Flow"
PNG_SCALE = 3          # the PNG (EPUB) is rendered at 3x so that it stays sharp on a high-density e-reader

# ---- Page geometry, in CSS pixels (1 px = 1/96 inch). Letter paper, 2.2 cm side margins (see book.css).
FIT_W = 640            # content width is 17.2 cm = 650 px; a little air
FIT_H = 700            # 18.5 cm. Heading, source line, caption and some prose share the page; tall figures use the rest
NOMINAL_PT = 12.0      # Mermaid's 16 px label font is 12 pt at scale 1
MIN_SCALE = 0.70       # below this the labels print smaller than 8.4 pt (and Mermaid's 14 px actor/note text below 7.4 pt)


class DiagramError(Exception):
    pass


# ---------------------------------------------------------------- structural Markdown scanning

FENCE_OPEN = re.compile(r"^ {0,3}(`{3,}|~{3,})[ \t]*([^\s`]*)[^`]*$")
HEADING = re.compile(r"^ {0,3}(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$")


def scan(text):
    """Return the headings and fenced blocks of CommonMark-ish `text`, in order, with 1-based line numbers.

    ('heading', level, title, line)  and  ('fence', info, body, first_line, last_line).
    Anything inside a fence is literal, so `## Program Flow` inside a code sample is not a heading."""
    out, lines, i = [], text.replace("\r\n", "\n").split("\n"), 0
    while i < len(lines):
        m = FENCE_OPEN.match(lines[i])
        if m:
            mark, info, start = m.group(1), m.group(2), i
            close = re.compile(r"^ {0,3}" + re.escape(mark[0]) + "{" + str(len(mark)) + r",}[ \t]*$")
            i += 1
            body = []
            while i < len(lines) and not close.match(lines[i]):
                body.append(lines[i])
                i += 1
            out.append(("fence", info, "\n".join(body), start + 1, i + 1))
        else:
            h = HEADING.match(lines[i])
            if h:
                out.append(("heading", len(h.group(1)), h.group(2).strip(), i + 1))
        i += 1
    return out


def program_flow(body, where):
    """The `## Program Flow` section of a README body: (section_text or None, [problems]).

    `section_text` is everything between that heading and the next level-1 or level-2 heading, trimmed. Problems
    name `where` (the README path). The README contract:
      * exactly one heading `## Program Flow`, spelled exactly like that (not "Program flow", not a synonym);
      * inside it, exactly one ```mermaid block and no sub-headings;
      * the diagram has `accTitle:` (the figure caption) and `accDescr:` (the alt text), and no HTML tags;
      * the prose after it has a **What this shows:** and a **Why this mechanism matters:** paragraph.
    Relative links to other files are fine: the book copies the section into a lesson page and re-aims them (cs.py). Links to a
    heading in the same README are not, because the heading is not on the page it is copied to."""
    items = scan(body)
    lines = body.replace("\r\n", "\n").split("\n")
    problems = []
    heads = [(it[3], it[2]) for it in items if it[0] == "heading" and it[1] == 2]
    flow = [h for h in heads if h[1] == SECTION]
    near = [h for h in heads if h[1] != SECTION and re.sub(r"[^a-z]", "", h[1].lower()) in ("programflow", "flow")]
    for line, title in near:
        problems.append(f"{where}:{line}: the heading must be exactly '## {SECTION}', not '## {title}'")
    if not flow:
        if not near:
            problems.append(f"{where}: no '## {SECTION}' section (see CONTRIBUTING.md, 'Program Flow')")
        return None, problems
    if len(flow) > 1:
        problems.append(f"{where}:{flow[1][0]}: more than one '## {SECTION}' heading")
    start = flow[0][0]
    end = next((it[3] for it in items if it[0] == "heading" and it[1] <= 2 and it[3] > start), len(lines) + 1)
    inside = [it for it in items if start < it[3] < end]
    subs = [it for it in inside if it[0] == "heading"]
    for it in subs:
        problems.append(f"{where}:{it[3]}: no sub-headings inside '## {SECTION}' (found '{it[2]}'); use bold lead-ins")
    fences = [it for it in inside if it[0] == "fence"]
    mer = [f for f in fences if f[1] == "mermaid"]
    if len(mer) != 1:
        problems.append(f"{where}:{start}: '## {SECTION}' needs exactly one ```mermaid block, found {len(mer)}")
    for f in fences:
        if f[1] != "mermaid":
            problems.append(f"{where}:{f[3]}: only a ```mermaid block belongs in '## {SECTION}', not ```{f[1]}")
    section = "\n".join(lines[start:end - 1]).strip("\n")
    if mer:
        src = mer[0][2]
        for key in ("accTitle", "accDescr"):
            if not re.search(rf"^\s*{key}\s*[:{{]", src, re.M):
                problems.append(f"{where}:{mer[0][3]}: the diagram needs a line '{key}: ...' ({'the figure caption' if key == 'accTitle' else 'the alt text'})")
        if re.search(r"<\/?[A-Za-z][^>\n]*>", src):
            problems.append(f"{where}:{mer[0][3]}: no HTML-like tags in the diagram (use plain text labels)")
        prose = "\n".join(l for k, l in enumerate(lines[start:end - 1]) if not any(f[3] - start - 1 <= k <= f[4] - start - 1 for f in mer))
        for k, l in enumerate(lines[start:end - 1]):
            if re.search(r"\]\(#", l) and not any(f[3] - start - 1 <= k <= f[4] - start - 1 for f in fences):
                problems.append(f"{where}:{start + k + 1}: no links to a heading in this README inside '## {SECTION}' (the section is copied to another page)")
        for label in ("What this shows:", "Why this mechanism matters:"):
            if f"**{label}**" not in prose:
                problems.append(f"{where}:{start}: the prose needs a paragraph that starts with **{label}**")
    return section, problems


def mermaid_blocks(text):
    """The ```mermaid fences of `text`: [(first_line, last_line, source)], 1-based and inclusive."""
    return [(it[3], it[4], it[2]) for it in scan(text) if it[0] == "fence" and it[1] == "mermaid"]


def diagram_type(source):
    """The Mermaid diagram family: the first word of the first line that is not a comment, directive or blank."""
    for line in source.split("\n"):
        s = line.strip()
        if s and not s.startswith(("%%", "---")):
            return s.split()[0].rstrip(":")
    return "empty"


def acc(source, key):
    """Value of an `accTitle:` / `accDescr:` line (one-line forms), else None."""
    m = re.search(rf"^\s*{key}\s*:\s*(.+?)\s*$", source, re.M)
    return m.group(1) if m else None


# ---------------------------------------------------------------- the renderer

class Renderer:
    def __init__(self, mmdc, chrome):
        self.mmdc, self.chrome = mmdc, chrome
        self.version = subprocess.run([mmdc, "--version"], capture_output=True, text=True, check=True).stdout.strip()
        self.chrome_version = subprocess.run([chrome, "--version"], capture_output=True, text=True).stdout.strip() or os.path.basename(chrome)
        with open(CONFIG, "rb") as f:
            self.config_bytes = f.read()
        self.pp = None

    def describe(self):
        return f"mermaid-cli {self.version}, {self.chrome_version}"

    def key(self, source):
        h = hashlib.sha256()
        for part in (source.strip("\n"), self.version, self.chrome_version, f"png-scale-{PNG_SCALE}"):
            h.update(part.encode()); h.update(b"\0")
        h.update(self.config_bytes)
        return h.hexdigest()[:16]

    def puppeteer_config(self):
        if self.pp is None:
            cfg = {"executablePath": self.chrome, "args": ["--no-sandbox"] if os.environ.get("MERMAID_NO_SANDBOX") else []}
            fd, self.pp = tempfile.mkstemp(suffix=".json", prefix="puppeteer-")
            with os.fdopen(fd, "w") as f:
                json.dump(cfg, f)
        return self.pp

    def run(self, source, out, extra=()):
        with tempfile.TemporaryDirectory() as d:
            src = os.path.join(d, "diagram.mmd")
            with open(src, "w", encoding="utf-8", newline="\n") as f:
                f.write(source.strip("\n") + "\n")
            p = subprocess.run([self.mmdc, "-q", "-p", self.puppeteer_config(), "-c", CONFIG, "-i", src, "-o", out, "-b", "white", *extra],
                               capture_output=True, text=True, timeout=180)
        if p.returncode != 0 or not os.path.isfile(out):
            raise DiagramError(clean_diagnostics(p.stderr or p.stdout) or f"mmdc exited {p.returncode}")


def clean_diagnostics(text):
    """The part of Mermaid CLI's error that tells an author what is wrong: the parse error and the line it points at, without the
    JavaScript stack trace."""
    keep = [l for l in text.strip().splitlines() if l.strip() and not re.match(r"\s+at |\s*(Parser|fromText|Object)\.|mermaid-cli-intercept|^Expecting ", l.strip())]
    return "\n".join(keep[:8])


def find_renderer():
    """The pinned Mermaid CLI (lessons/book/diagrams/node_modules, from `npm ci`) and a Chromium, or (None, why)."""
    mmdc = os.path.join(DIAGRAM_TOOLS, "node_modules", ".bin", "mmdc")
    if not os.path.isfile(mmdc):
        mmdc = shutil.which("mmdc")
    if not mmdc:
        return None, "Mermaid CLI is not installed: run `npm ci` in lessons/book/diagrams (see lessons/book/README.md)"
    chrome = os.environ.get("MERMAID_CHROME")
    if not chrome:
        cands = sorted(glob.glob(os.path.expanduser("~/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell"))) \
              + sorted(glob.glob(os.path.expanduser("~/.cache/puppeteer/chrome-headless-shell/*/chrome-headless-shell-linux64/chrome-headless-shell"))) \
              + sorted(glob.glob(os.path.expanduser("~/.cache/puppeteer/chrome/*/chrome-linux64/chrome"))) \
              + [shutil.which(n) for n in ("chromium", "chromium-browser", "google-chrome", "chrome-headless-shell")]
        chrome = next((c for c in cands if c and os.access(c, os.X_OK)), None)
    if not chrome or not os.access(chrome, os.X_OK):
        return None, "no Chromium found: set MERMAID_CHROME=/path/to/chrome (see lessons/book/README.md)"
    try:
        return Renderer(mmdc, chrome), ""
    except (subprocess.CalledProcessError, OSError) as e:
        return None, f"cannot run the renderer: {e}"


def svg_size(path):
    with open(path, encoding="utf-8") as f:
        tag = re.search(r"<svg\b[^>]*>", f.read(4000))
    if tag:
        w = re.search(r'\swidth="([\d.]+)(?:px)?"', tag.group(0))
        h = re.search(r'\sheight="([\d.]+)(?:px)?"', tag.group(0))
        if w and h:
            return float(w.group(1)), float(h.group(1))
        vb = re.search(r'viewBox="[-\d.]+ [-\d.]+ ([\d.]+) ([\d.]+)"', tag.group(0))
        if vb:
            return float(vb.group(1)), float(vb.group(2))
    raise DiagramError(f"{path}: cannot read the size of the SVG")


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        raise DiagramError(f"{path}: not a PNG")
    return struct.unpack(">II", head[16:24])


def fit(w, h):
    """How the figure is scaled to fit one printed page: (printed width px, printed height px, scale)."""
    s = min(1.0, FIT_W / w, FIT_H / h)
    return round(w * s), round(h * s), s


class Figure:
    """A rendered diagram: its cache key, files, natural size and the facts the legibility gate reports."""
    def __init__(self, key, source, where):
        self.key, self.source, self.where = key, source, where
        self.svg, self.png = os.path.join(CACHE, key + ".svg"), os.path.join(CACHE, key + ".png")
        self.title = acc(source, "accTitle") or "Diagram"
        self.descr = acc(source, "accDescr") or self.title
        self.family = diagram_type(source)
        self.hit = None
        self.w = self.h = 0.0

    def measure(self):
        self.w, self.h = svg_size(self.svg)
        self.pw, self.ph, self.scale = fit(self.w, self.h)
        self.points = NOMINAL_PT * self.scale       # printed size of Mermaid's nominal 16 px label font


def render_all(renderer, wanted):
    """Render every distinct diagram in `wanted` ({source: where}), using the cache. Returns ({source: Figure}, [errors]).

    A figure is reused when both files exist under its key; the key changes when the text, the renderer, the browser or the
    style configuration changes, so nothing stale is ever served and nothing unrelated is re-rendered."""
    os.makedirs(CACHE, exist_ok=True)
    figs = {src: Figure(renderer.key(src), src, where) for src, where in wanted.items()}
    todo = [f for f in figs.values() if not (os.path.isfile(f.svg) and os.path.isfile(f.png))]
    for f in figs.values():
        f.hit = f not in todo
    errors = []

    def one(f):
        try:
            tmp_svg, tmp_png = f.svg + ".part.svg", f.png + ".part.png"
            renderer.run(f.source, tmp_svg)
            renderer.run(f.source, tmp_png, ("-s", str(PNG_SCALE)))
            with open(tmp_svg, "rb") as fh:
                svg_bytes = fh.read()
            if b"<svg" not in svg_bytes[:4000] or b"Syntax error" in svg_bytes:
                raise DiagramError("Mermaid drew an error figure instead of the diagram (syntax error)")
            png_size(tmp_png)
            os.replace(tmp_png, f.png)
            os.replace(tmp_svg, f.svg)       # the SVG last: its presence marks a finished figure
        except (DiagramError, subprocess.TimeoutExpired) as e:
            for p in (f.svg + ".part.svg", f.png + ".part.png"):
                if os.path.exists(p):
                    os.remove(p)
            errors.append(f"{f.where}: Mermaid could not render the diagram:\n    " + str(e).replace("\n", "\n    "))
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(4, os.cpu_count() or 1)) as ex:
        list(ex.map(one, todo))
    for f in figs.values():
        if os.path.isfile(f.svg):
            f.measure()
    return figs, sorted(errors)


def orphans(figs):
    """Files in the cache that no current diagram uses (they are deleted by a normal build)."""
    keep = {os.path.basename(p) for f in figs.values() for p in (f.svg, f.png)}
    if not os.path.isdir(CACHE):
        return []
    return sorted(fn for fn in os.listdir(CACHE) if fn not in keep)


def prune(figs):
    gone = orphans(figs)
    for fn in gone:
        os.remove(os.path.join(CACHE, fn))
    return gone


# ---------------------------------------------------------------- putting figures in the page

def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def figure_html(fig, number, fmt):
    """HTML for one figure. fmt 'svg' (PDF and HTML): the printed size is fixed so the figure fits one page.
    fmt 'png' (EPUB): natural width, scaled down to the reader's screen by CSS."""
    if fmt == "svg":
        src, size = fig.svg, f'style="width:{fig.pw}px;height:{fig.ph}px"'
    else:
        src, size = fig.png, f'width="{round(fig.w)}"'
    return (f'<figure class="diagram">\n<img src="{esc(src)}" alt="{esc(fig.descr)}" {size} />\n'
            f'<figcaption>Figure {number}. {esc(fig.title)}</figcaption>\n</figure>')


def embed(text, figs, fmt, counter):
    """Replace each ```mermaid fence in `text` with a figure. `counter` is a one-item list holding the next figure number."""
    lines, out, pos = text.split("\n"), [], 0
    for first, last, src in mermaid_blocks(text):
        out.extend(lines[pos:first - 1])
        out.append("\n" + figure_html(figs[src], counter[0], fmt) + "\n")
        counter[0] += 1
        pos = last
    out.extend(lines[pos:])
    return "\n".join(out)
