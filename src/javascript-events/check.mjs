// The event lab: every claim in README.md about events, ordering, the event loop and failure, run against the real program.
// Usage: node --test check.mjs        (PROGRAM=/path/to/mutant.mjs node --test check.mjs runs the same tests on another file)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { DatabaseSync } from 'node:sqlite';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const { program, realWorld, isoWeek, CATEGORIES } = await import(pathToFileURL(resolve(process.env.PROGRAM ?? './timecards.mjs')));
const scratch = mkdtempSync(join(tmpdir(), 'javascript-events-'));
process.on('exit', () => rmSync(scratch, { recursive: true, force: true }));

let counter = 0;
// A world with no randomness and no clock: `hours` is the list of hours the cards will have (10 to 19), in order.
// The scheduler only queues; `drain()` is "the event loop", and runs one queued turn at a time.
const lab = (hours, extra = {}) => {
  const path = join(scratch, `db-${++counter}.sqlite`);
  const w = { lines: [], errs: [], exits: [], raws: [], queue: [], path };
  w.finished = new Promise(resolve => { w.finish = resolve; });                      // settles when the program says it has ended
  const next = (i => () => hours[i++] - 10)(0);
  w.world = {
    seed: 7, limit: 40, user: 'tester', week: [2026, 7], rng: next,
    schedule: fn => w.queue.push(fn), open: () => new DatabaseSync(path),
    out: l => w.lines.push(l), raw: t => w.raws.push(t), err: l => w.errs.push(l),
    tty: false, plain: false, cycles: 1, every: () => () => {}, exit: c => { w.exits.push(c); w.finish(c); }, ...extra,
  };
  w.events = program(w.world);
  w.drain = () => { let turns = 0; while (w.queue.length) { w.queue.shift()(); turns++; } return turns; };
  w.rows = () => { const db = new DatabaseSync(path); try { return db.prepare('SELECT category, hours, running_total, demo_only, user_id FROM demo_timecards ORDER BY rowid').all(); } finally { db.close(); } };
  // Log every emit as >name when it starts and <name when it returns, so nesting shows what runs inside what.
  w.trace = [];
  const raw = w.events.emit.bind(w.events);
  w.events.emit = (name, ...a) => { w.trace.push('>' + name); try { return raw(name, ...a); } finally { w.trace.push('<' + name); } };
  return w;
};

test('one run saves only demo records, and what it reports is what it saved', () => {
  const w = lab([14, 17, 15]);
  w.events.emit('start'); w.drain();
  const rows = w.rows();
  assert.deepEqual(rows.map(r => [r.category, r.hours, r.running_total]), [['Meetings', 14, 14], ['Coding', 17, 31], ['Debugging', 15, 46]]);
  assert.ok(rows.every(r => r.demo_only === 1 && r.user_id === 'tester'));
  assert.ok(w.lines.some(l => l.startsWith('# committed total=46 entries=3 DEMO ONLY\n')));
  assert.equal(w.lines[0].startsWith('# DEMO ONLY run '), true);
  assert.deepEqual(w.lines.filter(l => l.endsWith('\tDEMO ONLY')), ['Meetings\t14\t14\t2026-W07\tDEMO ONLY', 'Coding\t17\t31\t2026-W07\tDEMO ONLY', 'Debugging\t15\t46\t2026-W07\tDEMO ONLY']);
  assert.deepEqual(w.exits, [0]);
});

test('it stops at the exact card where the total first passes 40: exactly 40 goes on', () => {
  for (const [hours, cards] of [[[19, 19, 19], 3], [[10, 10, 10, 11], 4], [[10, 10, 10, 10, 10], 5], [[15, 15, 10, 10], 4], [[13, 14, 14], 3], [[10, 10, 10, 10, 19], 5]]) {
    const w = lab(hours);
    w.events.emit('start'); w.drain();
    assert.equal(w.rows().length, cards, `${hours} should make ${cards} cards`);
    assert.equal(w.rows().at(-1).running_total > 40, true);
    assert.equal(w.rows().slice(0, -1).every(r => r.running_total <= 40), true, `${hours}: only the last card may be over 40`);
  }
});

test('emit("start") returns before any card exists: the first card is made on a later turn', () => {
  const w = lab([19, 19, 19]);
  w.events.emit('start');
  assert.equal(w.queue.length, 1, 'start asked for exactly one later turn');
  assert.equal(w.rows().length, 0, 'no card exists yet');
  assert.deepEqual(w.trace, ['>start', '<start']);
});

test('inside one turn the events nest like a call stack; between turns the stack is empty', () => {
  const w = lab([19, 19, 19]);
  w.events.emit('start'); w.drain();
  const turn = ['>generate', '>card-created', '>card-saved', '>total-updated', '<total-updated', '<card-saved', '<card-created', '<generate'];
  const last = ['>generate', '>card-created', '>card-saved', '>total-updated', '>finished', '>done', '<done', '<finished', '<total-updated', '<card-saved', '<card-created', '<generate'];
  assert.deepEqual(w.trace, ['>start', '<start', ...turn, ...turn, ...last]);
  assert.equal(w.trace.indexOf('<start') < w.trace.indexOf('>generate'), true);
});

test('emit() calls its listeners synchronously; a setImmediate callback runs on a later turn of the event loop', async () => {
  const log = [];
  const e = new EventEmitter();
  e.on('x', () => log.push('listener 1'));
  e.on('x', () => log.push('listener 2'));
  setImmediate(() => log.push('immediate'));
  e.emit('x');
  log.push('emit returned');
  assert.deepEqual(log, ['listener 1', 'listener 2', 'emit returned'], 'both listeners ran, in registration order, before emit returned');
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(log, ['listener 1', 'listener 2', 'emit returned', 'immediate']);
});

test('the setImmediate boundary is what keeps the stack flat: a long run never gets deeper', async () => {
  Error.stackTraceLimit = 1000;
  const depths = [];
  const w = lab(Array.from({ length: 3000 }, () => 10), { limit: 19999, schedule: setImmediate });   // 2000 cards of 10 hours (the 2000th makes 20000), on the real event loop
  w.events.on('generate', () => depths.push(new Error().stack.split('\n').length));   // runs after the program's own listener
  w.events.emit('start');
  await w.finished;
  assert.equal(depths.length, 2000);
  assert.equal(depths.at(-1), depths[0], 'the 2000th card starts at the same depth as the first');
  assert.equal(Math.max(...depths) - Math.min(...depths), 0);
});

test('without the boundary, emitting from a listener recurses until the stack overflows (bounded demonstration)', () => {
  const e = new EventEmitter();
  let depth = 0;
  e.on('again', () => { depth++; e.emit('again'); });
  assert.throws(() => e.emit('again'), RangeError);
  assert.ok(depth > 1000, `it got ${depth} levels deep before it overflowed: one level for every emit`);
});

test('a failing database stops the run, rolls back, and is reported exactly once', () => {
  const w = lab([14, 17, 15]), statements = [];
  w.world.open = () => {
    const real = new DatabaseSync(w.path);
    return { exec: sql => { statements.push(sql); return real.exec(sql); }, close: () => real.close(),
             prepare: sql => { const st = real.prepare(sql); let k = 0; return /demo_timecards/.test(sql) ? { run: (...a) => { if (++k === 2) throw new Error('disk full'); return st.run(...a); } } : st; } };
  };
  w.events = program(w.world);
  w.events.emit('start'); w.drain();
  assert.deepEqual(w.errs, ['timecards: disk full']);
  assert.deepEqual(w.exits, [1]);
  assert.deepEqual(w.rows(), [], 'the transaction was rolled back: no half a run');
  assert.equal(statements.includes('ROLLBACK') && !statements.includes('COMMIT'), true, 'it said ROLLBACK, and never COMMIT');
  assert.deepEqual(w.events.eventNames(), [], 'no listener is left');
  assert.equal(w.lines.some(l => l.startsWith('# committed')), false, 'it never claimed success');
  assert.equal(w.lines.filter(l => l.endsWith('\tDEMO ONLY')).length, 1, 'only the card that was really saved was shown');
});

test('a failure while committing is reported once and nothing is left open', () => {
  const w = lab([19, 19, 19]);
  w.world.open = () => { const real = new DatabaseSync(w.path); return { exec: sql => { if (sql === 'COMMIT') throw new Error('commit refused'); return real.exec(sql); }, prepare: sql => real.prepare(sql), close: () => real.close() }; };
  w.events = program(w.world);
  w.events.emit('start'); w.drain();
  assert.deepEqual(w.errs, ['timecards: commit refused']);
  assert.deepEqual(w.exits, [1]);
  assert.deepEqual(w.rows(), []);
});

test('the special event name "error" is routed to the one failure path, and throws when nobody listens', () => {
  const w = lab([19, 19, 19]);
  w.events.emit('error', new Error('stray'));
  assert.deepEqual(w.errs, ['timecards: stray']);
  assert.deepEqual(w.exits, [1]);
  assert.deepEqual(w.events.eventNames(), []);
  assert.throws(() => w.events.emit('error', new Error('boom')), /boom/, 'Node throws an unheard "error" event');
  w.events.emit('failed', new Error('again'));
  assert.deepEqual(w.errs, ['timecards: stray'], 'a second failure is not reported again');
});

test('a run leaves no listener, timer, immediate or open resource behind', async () => {
  const before = process.getActiveResourcesInfo().sort();
  const w = lab([10, 10, 10, 10, 11], { schedule: setImmediate });
  w.events.emit('start');
  await w.finished;
  assert.deepEqual(w.events.eventNames(), []);
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(process.getActiveResourcesInfo().sort(), before, 'same active resources as before the run');
});

test('on a terminal the pulse is a timer: it ticks 2*cycles+1 times, stops itself, then the run ends', () => {
  let tick = null, stops = 0;
  const w = lab([19, 19, 19], { tty: true, cycles: 2, every: (fn, ms) => { tick = fn; assert.equal(ms, 600); return () => { stops++; }; } });
  w.events.emit('start'); w.drain();
  assert.equal(typeof tick, 'function', 'finished started the timer');
  assert.deepEqual(w.exits, [], 'the run is not over while the timer lives');
  for (let i = 0; i < 5; i++) tick();
  assert.equal(stops, 1);
  assert.deepEqual(w.exits, [0]);
  assert.equal(w.raws[0].includes('\x1b[1m') && w.raws[1].includes('\x1b[2m'), true, 'bold, then dim');
  assert.equal(w.raws.at(-1), '\n');
  assert.equal(w.raws.length, 6, 'five frames and the final newline');
});

test('the same seed replays the same cards, the same as the other two Node entries', () => {
  process.env.SEED = '42';
  const a = realWorld(), b = realWorld();
  const draw = w => Array.from({ length: 3 }, () => 10 + w.rng() % 10);
  assert.deepEqual(draw(a), [12, 17, 17]);
  assert.deepEqual(draw(b), [12, 17, 17]);
  delete process.env.SEED;
});

test('the ISO week agrees on the awkward days around New Year', () => {
  for (const [date, want] of [['2021-01-03', [2020, 53]], ['2024-12-30', [2025, 1]], ['2026-01-01', [2026, 1]], ['2016-01-03', [2015, 53]], ['2020-12-31', [2020, 53]]])
    assert.deepEqual(isoWeek(new Date(`${date}T12:00:00`)), want, date);
  assert.deepEqual(CATEGORIES, ['Meetings', 'Coding', 'Debugging', 'Learning']);
});
