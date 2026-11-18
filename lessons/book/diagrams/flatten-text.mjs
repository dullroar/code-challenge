// Remove what makes WeasyPrint put transparency groups in the PDF: centered text and single shapes with opacity.
//
// Why: WeasyPrint wraps every <text text-anchor="middle"> in a PDF transparency group (a Form XObject with its
// own resources). Mermaid centers every label, so the book had thousands of them, and PDF viewers that are built on PDFium (Edge,
// Chrome) draw each group into an off-screen bitmap. The pages with figures then take a long time to appear.
//
// How: Chrome (the same one that drew the figure) measures each text chunk. A chunk is one <tspan> that has its own x
// position, or the whole <text> if it has none. The script moves the chunk's x left by half its width (or by its whole
// width for text-anchor="end") and sets text-anchor to start. Then it checks that every chunk's box on the screen
// moved by less than TOLERANCE px, and it fails if one did.
//
// Usage: node flatten-text.mjs <puppeteer-config.json> <figure.svg>      (the file is rewritten in place)
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import puppeteer from "puppeteer";

const TOLERANCE = 0.5;
const [, , configPath, svgPath] = process.argv;
if (!configPath || !svgPath) {
  console.error("usage: node flatten-text.mjs <puppeteer-config.json> <figure.svg>");
  process.exit(2);
}
const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
const browser = await puppeteer.launch({ headless: "shell", executablePath: cfg.executablePath, args: cfg.args || [] });
try {
  const page = await browser.newPage();
  await page.goto(pathToFileURL(path.resolve(svgPath)).href);
  const result = await page.evaluate((TOLERANCE) => {
    const svgNS = "http://www.w3.org/2000/svg";
    const root = document.documentElement;
    const texts = [...root.querySelectorAll("text")];
    // A chunk is the unit that text-anchor applies to: an absolutely positioned <tspan>, or a <text> with no such <tspan>.
    const chunksOf = (t) => {
      const abs = [...t.querySelectorAll("tspan")].filter((s) => s.hasAttribute("x") && !s.parentElement.closest("tspan[x]"));
      return abs.length ? abs : [t];
    };
    const anchorOf = (el) => getComputedStyle(el).textAnchor;
    const boxes = () => texts.flatMap((t) => chunksOf(t).map((c) => c.getBoundingClientRect()));
    const before = boxes();
    let changed = 0;
    for (const t of texts) {
      for (const c of chunksOf(t)) {
        const a = anchorOf(c);
        if (a === "start") continue;
        const w = c.getComputedTextLength();
        const x0 = parseFloat(c.getAttribute("x") || (c === t ? t.getAttribute("x") : "0") || "0");
        const x = a === "middle" ? x0 - w / 2 : x0 - w;
        c.setAttribute("x", String(Math.round(x * 1000) / 1000));
        changed++;
      }
      // Every element in the text must now say start, in the style attribute so that it beats any CSS rule.
      for (const el of [t, ...t.querySelectorAll("tspan")]) {
        el.removeAttribute("text-anchor");
        el.style.setProperty("text-anchor", "start");
      }
    }
    // A single shape with opacity below 1 (Mermaid's half-transparent label backgrounds) also becomes a group in the PDF.
    // fill-opacity and stroke-opacity look the same on one shape and need no group.
    for (const el of root.querySelectorAll("rect, circle, ellipse, path, polygon")) {
      const op = parseFloat(getComputedStyle(el).opacity);
      if (op < 1) {
        el.style.setProperty("fill-opacity", String(op));
        el.style.setProperty("stroke-opacity", String(op));
        el.style.setProperty("opacity", "1");
      }
    }
    const after = boxes();
    let worst = 0;
    before.forEach((b, i) => {
      const a = after[i];
      worst = Math.max(worst, Math.abs(a.left - b.left), Math.abs(a.right - b.right), Math.abs(a.top - b.top), Math.abs(a.bottom - b.bottom));
    });
    return { changed, worst, svg: new XMLSerializer().serializeToString(root), ok: worst <= TOLERANCE };
  }, TOLERANCE);
  if (!result.ok) {
    console.error(`${svgPath}: a label moved by ${result.worst.toFixed(2)} px after centering was removed (limit ${TOLERANCE})`);
    process.exit(1);
  }
  fs.writeFileSync(svgPath, result.svg.endsWith("\n") ? result.svg : result.svg + "\n");
} finally {
  await browser.close();
}
