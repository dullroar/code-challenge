// Proves the constraints of this entry from the source text alone: no loop statement, no eval or dynamic code, no network,
// process or vm module, the start-up is ONE emit, every event of the contract has a listener, and the only way to the next
// card is through the scheduler (never an emit that calls itself).
// Usage: node check-static.mjs timecards.mjs
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
const path = process.argv[2];
const raw = readFileSync(path, 'utf8'), code = strip(raw);
const count = (text, re) => (text.match(re) ?? []).length;

for (const w of ['for', 'while', 'do', 'eval', 'Function', 'child_process', 'async', 'await', 'queueMicrotask', 'setTimeout'])
  if (count(code, new RegExp(`(?<![\\w.$])${w}(?![\\w$])`, 'g'))) fail(`${path} must not contain \`${w}\``);
if (/\.forEach\s*\(/.test(code)) fail('forEach is a loop by callback');
if (/process\s*\.\s*nextTick/.test(code)) fail('nextTick is another scheduler; this entry uses setImmediate only');
if (/\bimport\s*\(/.test(code) || /\brequire\s*\(/.test(code)) fail('code is loaded dynamically');
const imports = [...raw.matchAll(/^import .* from ['"]([^'"]+)['"];$/gm)].map(m => m[1]).sort();
const allowed = ['node:events', 'node:fs', 'node:os', 'node:path', 'node:sqlite', 'node:url'];
if (JSON.stringify(imports) !== JSON.stringify(allowed)) fail(`imports must be exactly ${allowed.join(', ')}; found ${imports.join(', ')}`);

// The start-up is one statement, and it is one emit.
const starts = raw.split('\n').filter(l => /^if \(.*\) program\(realWorld\(\)\)\.emit\('start'\);$/.test(l));
if (starts.length !== 1) fail("the file must end with exactly one line: if (<is this the main file>) program(realWorld()).emit('start');");
if (count(raw.replace(/\/\/.*$/gm, ''), /emit\('start'\)/g) !== 1) fail("emit('start') must appear exactly once");

// Every event of the contract has a listener, and nothing else is listened to.
const names = [...raw.replace(/\/\/.*$/gm, '').matchAll(/\bon\('([a-z-]+)'/g)].map(m => m[1]).sort();
const want = ['card-created', 'card-saved', 'done', 'error', 'failed', 'finished', 'frame', 'generate', 'start', 'total-updated'];
if (JSON.stringify(names) !== JSON.stringify(want)) fail(`the listeners must be exactly ${want.join(', ')}; found ${names.join(', ')}`);

// The next card is only ever asked for through `later`, which goes through the scheduler. An emit of 'generate' would be a recursion.
const body = raw.replace(/\/\/.*$/gm, '');
if (/emit\('generate'/.test(body)) fail("'generate' must be reached through later('generate'), never emitted directly");
if (count(body, /later\('generate'\)/g) !== 2) fail("expected exactly two later('generate') calls: one from start and one from total-updated");
if (count(code, /\bsetImmediate\b/g) !== 1) fail('setImmediate should appear once, in realWorld');
console.log(`ok: no loop statement, no eval, no async, no timer but the pulse's; imports are only ${allowed.join(', ')}; one emit('start') starts it; ${names.length} listeners; 'generate' is only reached through the scheduler`);
