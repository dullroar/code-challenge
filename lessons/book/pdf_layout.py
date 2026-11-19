"""CSS page geometry and layout rules in unrotated, crop-relative PDF points."""
from dataclasses import dataclass
import re

LETTER = (612, 792)
EDGE_TOLERANCE = 1.0
MARGIN_TOLERANCE = 1.5
BOX_TOLERANCE = 0.1


@dataclass(frozen=True)
class Geometry:
    size: tuple
    margins: tuple

    @property
    def content(self):
        width, height = self.size
        top, right, bottom, left = self.margins
        return left, top, width - right, height - bottom


def read_geometry(css):
    """Accept the stylesheet's base Letter @page and footer-only :first override."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    pages = []
    for match in re.finditer(r"@page\b([^{}]*)\{", css):
        body = re.match(r"((?:[^{}]|@bottom-center\s*\{[^{}]*\})*)}", css[match.end():])
        if not body:
            raise ValueError("unsupported block in book.css @page")
        body, footer_boxes = re.subn(r"@bottom-center\s*\{[^{}]*\}", "", body[1])
        if footer_boxes > 1:
            raise ValueError("duplicate @bottom-center in book.css @page")
        pages.append((match[1].strip(), body.strip()))
    if [selector for selector, _ in pages] not in ([""], ["", ":first"]):
        raise ValueError("book.css requires one base @page and at most a footer-only :first override")
    if len(pages) == 2 and pages[1][1]:
        raise ValueError("unsupported geometry override in book.css @page :first")
    declarations = {}
    for declaration in pages[0][1].split(";"):
        if not declaration.strip():
            continue
        key, colon, value = declaration.partition(":")
        key = key.strip()
        if not colon or key not in {"size", "margin"} or key in declarations:
            raise ValueError("unsupported or duplicate declaration in book.css @page")
        declarations[key] = value.strip()
    if declarations.get("size", "").lower() != "letter":
        raise ValueError("book.css @page size must be Letter")
    units = {"pt": 1, "in": 72, "cm": 72 / 2.54, "mm": 72 / 25.4, "px": 72 / 96}
    margins = []
    for token in declarations.get("margin", "").split():
        match = re.fullmatch(r"(\d+(?:\.\d+)?|\.\d+)(pt|in|cm|mm|px)", token, re.I)
        if not match and token != "0":
            raise ValueError("book.css @page margin needs physical lengths or zero")
        margins.append(float(match[1]) * units[match[2].lower()] if match else 0)
    if len(margins) not in range(1, 5):
        raise ValueError("book.css @page needs one to four margin lengths")
    if len(margins) == 1:
        margins *= 4
    elif len(margins) == 2:
        margins *= 2
    elif len(margins) == 3:
        margins.append(margins[1])
    geometry = Geometry(LETTER, tuple(margins))
    x0, y0, x1, y1 = geometry.content
    if x0 >= x1 or y0 >= y1:
        raise ValueError("book.css @page margins leave no content region")
    return geometry


def union(boxes):
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def overflow(box, allowed, tolerance):
    x0, y0, x1, y1 = box
    left, top, right, bottom = allowed
    return {edge: amount for edge, amount in (
        ("left", left - x0), ("top", top - y0), ("right", x1 - right), ("bottom", y1 - bottom)
    ) if amount > tolerance}


def excerpt(text):
    return text[:77] + "…" if len(text) > 78 else text


def finding(rule, page, message, *, severity="error", item=None, box=None, allowed=None,
            displacement=None):
    return {
        "rule": rule, "page": page, "severity": severity, "message": message,
        "excerpt": excerpt(item) if item is not None else None,
        "box": rounded(box), "allowed_box": rounded(allowed),
        "overflow_pt": {edge: round(value, 3) for edge, value in (displacement or {}).items()},
    }


def rounded(box):
    return [round(value, 3) for value in box] if box is not None else None


def placement(rule, number, label, box, allowed, displacement, **kwargs):
    edges = ", ".join(f"+{amount:.2f} pt past {edge}" for edge, amount in displacement.items())
    return finding(rule, number, f"{label} {edges}", box=box, allowed=allowed,
                   displacement=displacement, **kwargs)


def footer(line, number, geometry, physical):
    """The CSS bottom-centered 9 pt DejaVu Sans counter for this physical page."""
    x0, y0, x1, y1 = line["box"]
    cx = physical[2] / 2
    cy = (geometry.content[3] + physical[3]) / 2
    return (line["text"].strip() == str(number) and abs((x0 + x1) / 2 - cx) <= 2
            and abs((y0 + y1) / 2 - cy) <= 3
            and all(size == 9 and font == "DejaVu-Sans" for size, font in line["fonts"]))


def text_placements(lines, number, geometry, physical):
    for line in lines:
        is_footer = footer(line, number, geometry, physical)
        for rule, allowed, tolerance, label in (
            ("PDF-003", physical, EDGE_TOLERANCE, "text beyond physical page"),
            ("PDF-004", geometry.content, MARGIN_TOLERANCE, "text beyond content margin"),
        ):
            if is_footer and rule == "PDF-004":
                continue
            group = []
            for _, box in (*line["chars"], (" ", None)):
                outside = box and overflow(box, allowed, tolerance)
                if outside:
                    group.append(box)
                    continue
                if group:
                    measured = union(group)
                    yield placement(rule, number, label, measured, allowed,
                                    overflow(measured, allowed, tolerance), item=line["text"])
                    group.clear()
