#!/usr/bin/env python3
"""Read-only layout checks for finished Weird Way PDFs."""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import tempfile

from pdf_layout import (
    BOX_TOLERANCE, EDGE_TOLERANCE, MARGIN_TOLERANCE, finding, overflow, placement,
    read_geometry, text_placements, union,
)

HERE = Path(__file__).resolve().parent
PUBLICATIONS = {
    "learn-programming-the-weird-way": "book",
    "learn-programming-the-weird-way-study-guides": "study-guides",
}
INSTALL = "install lessons/book/requirements-pdf-lint.txt in the Python environment running this command"
PREVIEW_DPI = 144
PREVIEW_LIMIT = 12


def text_lines(page, pdf):
    flags = pdf.TEXTFLAGS_TEXT | pdf.TEXT_ACCURATE_BBOXES
    flags &= ~pdf.TEXT_MEDIABOX_CLIP
    raw = page.get_text("rawdict", flags=flags, clip=pdf.INFINITE_RECT())
    for block in raw["blocks"]:
        for line in block.get("lines", ()):
            spans = [span for span in line["spans"] if span["alpha"] and span["char_flags"] & 24]
            chars = [(c["c"], tuple(c["bbox"]) if c["c"].strip() else None)
                     for span in spans for c in span["chars"]]
            boxes = [box for _, box in chars if box]
            if boxes:
                yield {"text": "".join(char for char, _ in chars), "chars": chars,
                       "box": union(boxes),
                       "fonts": [(round(s["size"], 2), s["font"]) for s in spans]}


def page_geometry(page, number, geometry):
    media, crop = page.mediabox, page.cropbox
    expected = (0, 0, *geometry.size)
    # CropBox is top-origin relative to MediaBox's top, with absolute x.
    full_crop = (media.x0, 0, media.x1, media.height)
    for label, actual, allowed in (
        ("MediaBox dimensions", (0, 0, media.width, media.height), expected),
        ("CropBox extent", tuple(crop), full_crop),
    ):
        if any(abs(a - b) > BOX_TOLERANCE for a, b in zip(actual, allowed)):
            yield finding("PDF-002", number, f"unexpected {label}", box=actual, allowed=allowed)
    if page.rotation:
        yield finding("PDF-002", number, f"unexpected {page.rotation}° page rotation",
                      box=tuple(page.rect), allowed=expected)


def scan_page(page, pdf, geometry):
    number = page.number + 1
    physical = (0, 0, page.cropbox.width, page.cropbox.height)
    yield from page_geometry(page, number, geometry)
    yield from text_placements(text_lines(page, pdf), number, geometry, physical)
    for image in page.get_image_info():
        box = tuple(image["bbox"])
        for region, allowed, tolerance in (
            ("physical page", physical, EDGE_TOLERANCE),
            ("content margin", geometry.content, MARGIN_TOLERANCE),
        ):
            delta = overflow(box, allowed, tolerance)
            if delta:
                yield placement("PDF-005", number, f"image placement beyond {region}",
                                box, allowed, delta, item=f'{image["width"]} × {image["height"]} px')


def same_file(a, b):
    return a.resolve() == b.resolve() or (a.exists() and b.exists() and a.samefile(b))


def write_output(path, data, inputs):
    if any(same_file(path, source) for source in inputs):
        raise ValueError("diagnostic output would overwrite an input PDF")
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        temp = Path(stream.name)
        try:
            stream.write(data)
            stream.close()
            temp.replace(path)
        finally:
            temp.unlink(missing_ok=True)


def pixel_box(box, page, pixmap, pdf):
    rotated = pdf.Rect(box) * page.rotation_matrix
    scale = PREVIEW_DPI / 72
    return [round(x * scale - shift) for x, shift in zip(rotated, (pixmap.x, pixmap.y) * 2)]


def preview(page, findings, geometry, pdf):
    from io import BytesIO
    from PIL import Image, ImageDraw, ImageFont

    pix = page.get_pixmap(dpi=PREVIEW_DPI, alpha=False)
    image = Image.new("RGB", (pix.width + 390, pix.height), "#fafafa")
    image.paste(Image.frombytes("RGB", (pix.width, pix.height), pix.samples), (0, 0))
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default(size=15)
    draw.rectangle(pixel_box(geometry.content, page, pix, pdf), outline="#008078", width=2)
    draw.text((pix.width + 14, 14), "Teal outline: content region", fill="#008078", font=font)
    for i, item in enumerate(findings[:PREVIEW_LIMIT], 1):
        color = "#b91c1c" if item["severity"] == "error" else "#9a5800"
        if item["box"] and item["rule"] != "PDF-002":
            box = pixel_box(item["box"], page, pix, pdf)
            draw.rectangle(box, outline=color, width=3)
            x, y = box[:2]
            draw.text((max(0, min(x, pix.width - 24)), max(0, min(y - 16, pix.height - 18))),
                      str(i), fill=color, font=font)
        overflow_text = ", ".join(f"+{v:.2f} pt {k}" for k, v in item["overflow_pt"].items())
        draw.text((pix.width + 14, 40 + 23 * i), f'{i}. {item["rule"]}  {overflow_text}',
                  fill=color, font=font)
    stream = BytesIO()
    image.save(stream, format="PNG", dpi=(PREVIEW_DPI, PREVIEW_DPI))
    return stream.getvalue()


def finding_order(item):
    return (item["page"] or 0, item["severity"], item["rule"], item["box"] or [], item["message"])


def failure(number, message):
    return finding("PDF-001", number, message)


def scan(source, profile, geometry, pdf, args):
    result = {"document": source.name, "profile": profile, "page_count": None, "pages_scanned": 0,
              "complete": False, "page_failures": [], "findings": []}
    findings = result["findings"]
    if not source.is_file():
        findings.append(failure(None, "input PDF is missing or is not a file"))
        return result
    try:
        doc = pdf.open(source)
    except (RuntimeError, ValueError, OSError) as exc:
        findings.append(failure(None, f"cannot open PDF ({type(exc).__name__})"))
        return result
    with doc:
        if not doc.is_pdf or doc.is_encrypted or doc.is_repaired or doc.page_count == 0:
            findings.append(failure(None, "input must be a readable, unencrypted PDF with pages and no parser repairs"))
            return result
        result["page_count"] = doc.page_count
        for index in range(doc.page_count):
            try:
                items = list(scan_page(doc[index], pdf, geometry))
            except (RuntimeError, ValueError, OSError) as exc:
                result["page_failures"].append(index + 1)
                findings.append(failure(index + 1, f"page scan failed ({type(exc).__name__})"))
                continue
            findings.extend(items)
            result["pages_scanned"] += 1
        result["complete"] = result["pages_scanned"] == result["page_count"]
        if args.annotate_dir:
            annotate(result, doc, geometry, pdf, args)
    findings.sort(key=finding_order)
    return result


def annotate(result, doc, geometry, pdf, args):
    pages = {}
    for item in sorted(result["findings"], key=finding_order):
        if item["page"] and item["rule"] != "PDF-001":
            pages.setdefault(item["page"], []).append(item)
    ordered = sorted(pages, key=lambda n: (all(item["severity"] == "warning" for item in pages[n]), n))
    stem = Path(result["document"]).stem
    stem = PUBLICATIONS.get(stem, re.sub(r"[^\w.-]", "_", stem))
    for number in ordered[:None if args.verbose else PREVIEW_LIMIT]:
        output = args.annotate_dir / f"{stem}-p{number:04d}.png"
        try:
            data = preview(doc[number - 1], pages[number], geometry, pdf)
            write_output(output, data, args.pdfs)
        except (RuntimeError, ValueError, OSError) as exc:
            result["findings"].append(finding("PDF-011", number, f"preview failed ({type(exc).__name__})"))
            result["complete"] = False
            result["page_failures"].append(number)
        else:
            for item in pages[number]:
                item["preview"] = output.name


def print_report(report, verbose):
    for global_error in report["diagnostics"]:
        print(f"ERROR PDF-001 {global_error}")
    for result in report["documents"]:
        pages = result["page_count"]
        print(f'{result["document"]}: scanned {result["pages_scanned"]}/{pages if pages is not None else "?"} pages')
        items = result["findings"]
        shown = sorted(items, key=lambda item: (item["severity"], *finding_order(item)))
        if not verbose:
            shown = shown[:20]
        for item in shown:
            where = f' page {item["page"]}' if item["page"] else ""
            print(f'  {item["severity"].upper()} {item["rule"]}{where}: {item["message"]}')
            if item["excerpt"]:
                print("    " + json.dumps(item["excerpt"], ensure_ascii=True))
            if item["box"]:
                print(f'    box {item["box"]} pt, allowed {item["allowed_box"]} pt')
            if "preview" in item:
                print(f'    preview {item["preview"]}')
        if len(shown) < len(items):
            print(f"  {len(items) - len(shown)} more findings (use --json or --verbose)")
    print(f'{report["errors"]} errors, {report["warnings"]} warnings; exit {report["exit_status"]}')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdfs", nargs="+", type=Path, metavar="PDF")
    parser.add_argument("--profile", choices=("auto", "book", "study-guides", "letter"), default="auto")
    parser.add_argument("--json", type=Path, dest="report_path", metavar="FILE")
    parser.add_argument("--annotate-dir", type=Path, metavar="DIR")
    parser.add_argument("--release", action="store_true", help="run the release gate (warnings remain advisory)")
    parser.add_argument("--verbose", action="store_true", help="show all findings and preview all affected pages")
    args = parser.parse_args(argv)
    if len({path.name for path in args.pdfs}) != len(args.pdfs):
        parser.error("input basenames must be distinct within a report")
    if args.report_path and args.report_path.suffix.lower() != ".json":
        parser.error("--json requires a .json output file")
    report = {"schema_version": 1, "documents": [], "diagnostics": []}
    try:
        import pymupdf as pdf
        if args.annotate_dir:
            import PIL
    except ImportError:
        report["diagnostics"].append(f"missing PDF lint dependency; {INSTALL}")
    else:
        try:
            geometry = read_geometry((HERE / "book.css").read_text(encoding="utf-8"))
        except (ValueError, OSError) as exc:
            message = "cannot read book.css" if isinstance(exc, OSError) else str(exc)
            report["diagnostics"].append(message)
        else:
            for source in sorted(args.pdfs, key=lambda path: path.name):
                profile = PUBLICATIONS.get(source.stem, "letter") if args.profile == "auto" else args.profile
                report["documents"].append(scan(source, profile, geometry, pdf, args))

    items = [f for d in report["documents"] for f in d["findings"]]
    report["errors"] = sum(f["severity"] == "error" for f in items) + len(report["diagnostics"])
    report["warnings"] = sum(f["severity"] == "warning" for f in items)
    complete = not report["diagnostics"] and all(d["complete"] for d in report["documents"])
    report["exit_status"] = 2 if not complete else int(bool(report["errors"]))
    if args.report_path:
        try:
            data = json.dumps(report, ensure_ascii=True, sort_keys=True, indent=2) + "\n"
            write_output(args.report_path, data.encode("utf-8"), args.pdfs)
        except (OSError, ValueError):
            report["diagnostics"].append("cannot write JSON report")
            report["errors"] += 1
            report["exit_status"] = 2
    print_report(report, args.verbose)
    return report["exit_status"]


if __name__ == "__main__":
    sys.exit(main())
