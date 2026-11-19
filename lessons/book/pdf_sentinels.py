"""Expected selectable snippets from the two publications' current sources.

Each check is restricted to a distinctive snippet on one page, anywhere in the
document. Diagram labels may lose spaces at SVG tspan boundaries during extraction.
"""
from dataclasses import dataclass
import re


@dataclass(frozen=True)
class Sentinel:
    name: str
    expected: str
    pattern: str = ""

    def matches(self, page_text):
        return bool(re.search(self.pattern, page_text)) if self.pattern else self.expected in page_text


APL_DIAGRAM = Sentinel("Mermaid apl-weird ≤", "Alive: total ≤ 40?", r"Alive: total ≤ ?40\?")
ASCII_DIAGRAM = Sentinel("Mermaid forth-weird <=", "-1 while total <= 40, else 0")
FORTH_DIAGRAM = Sentinel("Mermaid Forth parse position >", "Interpreter reads: 0 0 >in @")
APL_CODE = Sentinel("APL stop rule ≥", "Alive←40≥T")
PROFILES = {
    "book": (
        APL_DIAGRAM, ASCII_DIAGRAM, FORTH_DIAGRAM, APL_CODE,
        Sentinel("Mermaid awk-weird ≥", "Last rule: t ≥ 41?", r"Last rule: t ≥ ?41\?"),
        Sentinel("APL reshape and iota", "⍴ (reshape), ⍳ (index generator)"),
        Sentinel("APL function definition", "Kid←⎕FX Alive/"),
        Sentinel("Forth checker regex", r"[\]([[:space:]].*)?$//"),
        Sentinel("sed capture groups", r"sed -i 's/^\(4[1-5]\)"),
        Sentinel("wrapped Forth alternation", "recurse|e↩ / ↪ xit|leave", r"recurse\|e↩\n[ \t]*↪ xit\|leave"),
    ),
    "study-guides": (
        APL_DIAGRAM, ASCII_DIAGRAM, FORTH_DIAGRAM,
        Sentinel("APL reshape and iota", "basic APL: ⍳, ⍴"),
        Sentinel("APL function definition", "Kid←⎕FX Alive/"),
        Sentinel("wrapped Make trace", "total=46↩ / ↪ 41st-word-exists=yes",
                 r"total=46↩\n[ \t]*↪ 41st-word-exists=yes"),
    ),
}
