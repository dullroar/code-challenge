// Proves the constraints of this entry from the source text alone: no loop statement anywhere, no eval, no dynamic code,
// no process or network module, a core with no I/O at all, and the pieces the README talks about are really there.
// Usage: node check-static.mjs core.mjs timecards.mjs
import { readFileSync } from 'node:fs';

// Blank comments and string contents; keep code, including the code inside `${ ... }` of template literals.
const strip = src => {
  let out = '', i = 0;
  const stack = [];
  while (i < src.length) {
    const c = src[i], two = src.slice(i, i + 2), top = stack.at(-1);
    if (top === 'tpl') {
      if (c === '\\') { i += 2; continue; }
      if (c === '`') { stack.pop(); out += '`'; i++; continue; }
      if (two === '${') { stack.push(0); out += '${'; i += 2; continue; }
      i++; continue;
    }
    if (two === '//') { while (i < src.length && src[i] !== '\n') i++; continue; }
    if (two === '/*') { i = src.indexOf('*/', i + 2) + 2; if (i < 2) throw new Error('unterminated comment'); continue; }
    if (c === '"' || c === "'") { const q = c; i++; while (src[i] !== q) i += src[i] === '\\' ? 2 : 1; i++; out += q + q; continue; }
    if (c === '`') { stack.push('tpl'); out += '`'; i++; continue; }
    if (c === '{' && typeof top === 'number') stack[stack.length - 1]++;
    if (c === '}' && typeof top === 'number') { if (top === 0) { stack.pop(); out += '}'; i++; continue; } stack[stack.length - 1]--; }
    out += c; i++;
  }
  return out;
};
const fail = msg => { console.error(`FAIL: ${msg}`); process.exit(1); };
const [corePath, mainPath] = process.argv.slice(2);
const rawCore = readFileSync(corePath, 'utf8'), rawMain = readFileSync(mainPath, 'utf8');
const core = strip(rawCore), main = strip(rawMain);
const count = (code, re) => (code.match(re) ?? []).length;
for (const [name, code, raw] of [[corePath, core, rawCore], [mainPath, main, rawMain]]) {
  for (const w of ['for', 'while', 'do', 'eval', 'Function', 'this', 'child_process', 'new Function'])
    if (count(code, new RegExp(`(?<![\\w.$])${w.replace(' ', '\\s+')}(?![\\w$])`, 'g'))) fail(`${name} must not contain \`${w}\``);
  if (/\.forEach\s*\(/.test(code)) fail(`${name} must not use forEach (a loop by callback)`);
  for (const [, spec] of raw.matchAll(/(?:from|import)\s+['"]([^'"]+)['"]/g))        // the module names are in strings, so read the raw text
    if (/^(node:)?(net|http|https|http2|dns|tls|dgram|child_process|worker_threads|vm|cluster|inspector|repl|readline)(\/.*)?$/.test(spec)) fail(`${name} imports ${spec}`);
  if (/\bimport\s*\(/.test(code) || /\brequire\s*\(/.test(code)) fail(`${name} loads code dynamically`);
}
for (const w of ['process', 'console', 'import', 'Date', 'Math', 'crypto', 'globalThis', 'require', 'setInterval', 'setTimeout', 'async', 'await'])
  if (count(core, new RegExp(`(?<![\\w.$])${w}(?![\\w$])`, 'g'))) fail(`${corePath} must be pure: it uses ${w}`);
for (const [what, re, where] of [['Symbol.iterator', /Symbol\.iterator/, core], ['Iterator.from', /Iterator\.from\(/, main], ['.map(', /\.map\(/, main],
                                  ['.reduce(', /\.reduce\(/, main], ['.toArray(', /\.toArray\(/, main], ['a closure factory', /=> \(?\w*\s*=>|=> \{[^}]*return \(\) =>/, core]])
  if (!re.test(where)) fail(`expected to find ${what}`);
const arrows = count(core, /=>/g) + count(main, /=>/g);
console.log(`ok: no for, while, do, eval, Function, this or forEach in either file; no network, process or vm module; the core is pure (no I/O, no clock, no timer); ${arrows} arrow functions; Symbol.iterator, Iterator.from, map, reduce and toArray are all used`);
