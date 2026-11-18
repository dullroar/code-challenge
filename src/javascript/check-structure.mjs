// Proves the constraint: after its imports, the file is ONE `for` statement with two semicolons in its header and an
// empty body. No function, no second statement, no other loop, no eval. Usage: node check-structure.mjs timecards.mjs
import { readFileSync } from 'node:fs';

// Blank out comments and string contents, keep the code. Template literals are scanned properly, so code inside a
// `${ ... }` (even one that holds another template) still counts as code.
const strip = src => {
  let out = '', i = 0;
  const stack = [];                                   // 'tpl', or a number: the brace depth inside a ${ ... }
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
const code = strip(readFileSync(process.argv[2], 'utf8')).replace(/^import [^;]*;\s*$/gm, '').trim();
if (!/^for\b/.test(code)) fail(`the file must start (after its imports) with the for statement; it starts with: ${code.slice(0, 40)}`);
const open = code.indexOf('(');
let depth = 0, braces = 0, close = -1; const clauses = [open + 1];
for (let k = open; k < code.length; k++) {
  const c = code[k];
  if (c === '(' || c === '[') depth++;
  else if (c === ')' || c === ']') { depth--; if (depth === 0) { close = k; break; } }
  else if (c === '{') braces++;
  else if (c === '}') braces--;
  else if (c === ';' && depth === 1 && braces === 0) clauses.push(k + 1);
}
if (close < 0) fail('the for header never closes');
if (clauses.length !== 3) fail(`the header must have exactly two semicolons (three clauses); it has ${clauses.length - 1}`);
const rest = code.slice(close + 1).trim();
if (rest !== '{}' && !/^\{\s*\}$/.test(rest) && rest !== ';') fail(`the body must be empty ({} or ;); after the header comes: ${rest.slice(0, 50)}`);
const words = w => (code.match(new RegExp(`\\b${w}\\b`, 'g')) ?? []).length;
if (words('for') !== 1) fail(`there must be exactly one for; found ${words('for')}`);
for (const w of ['while', 'do', 'eval', 'Function', 'forEach', 'child_process', 'import']) if (words(w)) fail(`${w} must not appear`);
const [a, b, c] = [clauses[0], clauses[1], clauses[2]].map((s, n, all) => code.slice(s, n < 2 ? all[n + 1] - 1 : close).trim().length);
console.log(`ok: one for statement, empty body; clauses: initializer ${a} chars, condition ${b} chars, iterator ${c} chars`);
