// Every claim the README makes about closures, laziness and reduce, as a test. Run:  node --expose-gc --test check.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { cards, hoursFrom, machine } from './core.mjs';

// A closure over a list, for forced dice: forced(10, 12) answers 10, then 12, then undefined.
const forced = (...hours) => () => hours.shift();
// A closure that counts how often it was called. The count is a property on the function, so it is visible from outside.
const counting = f => { const g = () => (g.calls++, f()); g.calls = 0; return g; };
const run = (nextHours) => [...cards(machine(nextHours))];

test('a closure keeps its environment between calls, and nothing outside can reach it', () => {
  const m = machine(forced(10, 11, 12, 13, 14));
  assert.deepEqual([m().total, m().total, m().total], [10, 21, 33]);       // the total lives on between calls
  assert.deepEqual(Object.getOwnPropertyNames(m).sort(), ['length', 'name']); // no field, no getter: only the function itself
  assert.equal(m.total, undefined);
  assert.equal(typeof m.toString(), 'string');                              // the text of a function shows code, not captured values
  assert.ok(!m.toString().includes('33'));
});

test('every call to the factory makes a new environment: two machines do not share state', () => {
  const a = machine(forced(10, 10, 10)), b = machine(forced(19, 19, 19));
  assert.deepEqual([a().total, b().total, a().total, b().total], [10, 19, 20, 38]);
});

test('the same seed replays the same cards, another seed does not, and a machine cannot be rewound', () => {
  const first = run(hoursFrom(42)), again = run(hoursFrom(42)), other = run(hoursFrom(43));
  assert.deepEqual(first, again);
  assert.notDeepEqual(first, other);
  assert.deepEqual(first.map(c => c.hours), [12, 17, 17]);                  // the same cards as the conventional entry, seed 42
  const m = machine(hoursFrom(42)); m(); m();
  assert.equal(m.rewind, undefined);                                        // there is no way back, only a new machine
});

test('the crossing card is kept, a total of exactly 40 goes on, and nothing comes after the stop', () => {
  const tens = run(forced(10, 10, 10, 10, 10));
  assert.deepEqual(tens.map(c => c.total), [10, 20, 30, 40, 50]);           // 40 is not over 40
  assert.deepEqual(tens.map(c => c.category), ['Meetings', 'Coding', 'Debugging', 'Learning', 'Meetings']);
  assert.deepEqual(run(forced(10, 10, 10, 11)).map(c => c.total), [10, 20, 30, 41]);   // 41 is over: stop, and keep the card
  assert.deepEqual(run(forced(19, 19, 19, 19)).map(c => c.total), [19, 38, 57]);
  const source = counting(forced(19, 19, 19, 19, 19)), m = machine(source);
  m(); m(); m();
  assert.equal(m(), undefined); assert.equal(m(), undefined); assert.equal(m(), undefined);
  assert.equal(source.calls, 3);                                            // the stopped machine never asks for more hours
});

test('iteration is demand-driven: nothing is drawn until something asks, and the consumer decides how many', () => {
  const source = counting(hoursFrom(7)), m = machine(source);
  const pipeline = Iterator.from(cards(m)).map(c => ({ ...c, stamped: true })).map(c => c);
  assert.equal(source.calls, 0);                                            // building the pipeline draws nothing
  assert.equal(pipeline.take(1).toArray().length, 1);
  assert.equal(source.calls, 1);                                            // one card asked for, one card drawn
  const rest = Iterator.from(cards(m)).toArray();                           // the same machine goes on from where it was
  assert.equal(source.calls, 1 + rest.length);
  assert.ok(rest.length >= 2 && rest.length <= 4);
});

test('lazy map interleaves the two stages; the eager array map does not (the functor law holds only for pure functions)', () => {
  const log = [];
  const a = x => (log.push(`a${x}`), x), b = x => (log.push(`b${x}`), x);
  Iterator.from([1, 2, 3]).map(a).map(b).toArray();
  assert.deepEqual(log, ['a1', 'b1', 'a2', 'b2', 'a3', 'b3']);              // one value goes all the way through before the next starts
  log.length = 0;
  [1, 2, 3].map(a).map(b);
  assert.deepEqual(log, ['a1', 'a2', 'a3', 'b1', 'b2', 'b3']);              // each stage finishes before the next begins
});

test('eager versus lazy: a bound drawn up front draws more than the program needs; a demand-driven pipeline draws only what it uses', () => {
  const eager = counting(forced(19, 19, 19, 19, 19)), me = machine(eager);
  const five = Array.from({ length: 5 }, me);
  assert.deepEqual(five.map(c => c?.total), [19, 38, 57, undefined, undefined]); // five slots asked for, two of them empty
  const lazy = counting(forced(19, 19, 19, 19, 19));
  Iterator.from(cards(machine(lazy))).toArray();
  assert.equal(lazy.calls, 3);
});

test('reduce cannot stop by itself: its callback runs for every element, whatever the accumulator says', () => {
  const seen = [];
  const out = [19, 19, 19, 19, 19].reduce((acc, h) => (seen.push(h), acc.done ? acc : { total: acc.total + h, done: acc.total + h > 40 }), { total: 0, done: false });
  assert.equal(out.total, 57);                                               // the answer is right (the callback ignored the later values)...
  assert.equal(seen.length, 5);                                              // ...but it was called five times, not three
  // some() does stop: it asks for a value only while the answer so far is "no"
  const source = counting(hoursFrom(42));
  let t = 0;
  assert.equal(Iterator.from(cards(machine(source))).some(c => (t = c.total) > 40), true);
  assert.equal(source.calls, 3);
  // an exception ends a reduce too. It works, and it is the wrong tool: control flow by error.
  const stop = Symbol('stop'), calls = [];
  assert.throws(() => [19, 19, 19, 19, 19].reduce((acc, h) => { calls.push(h); if (acc + h > 40) throw stop; return acc + h; }, 0), e => e === stop);
  assert.equal(calls.length, 3);
});

test('repeating an iteration: an array can be walked again, this iterable cannot, and a replay needs a new machine', () => {
  const it = cards(machine(forced(19, 19, 19)));
  assert.equal([...it].length, 3);
  assert.equal([...it].length, 0);                                           // the same machine, already over
  assert.equal([...cards(machine(hoursFrom(5)))].length, [...cards(machine(hoursFrom(5)))].length);  // a fresh one repeats
});

test('closure lifetime: the environment lives while the function can be reached, and is collectable after', async () => {
  assert.equal(typeof globalThis.gc, 'function', 'run with node --expose-gc');
  const tick = () => new Promise(r => setImmediate(r));
  const keep = machine(hoursFrom(1)); const ref = new WeakRef(keep);
  await tick(); gc(); await tick(); gc();
  assert.ok(ref.deref(), 'a function that is still referenced is kept, with its environment');
  assert.equal(keep().total > 0, true);                                       // and it still works
  let weak;
  (() => { const m = machine(hoursFrom(2)); m(); weak = new WeakRef(m); })();
  for (let k = 0; k < 10 && weak.deref(); k++) { await tick(); gc(); }
  assert.equal(weak.deref(), undefined, 'a function nothing refers to is collected, and its environment with it');
});

test('a closure captures variables; `this` is not one of them', () => {
  const make = () => { let n = 0; return { n: 100, viaClosure: () => ++n, viaThis() { return ++this.n; } }; };
  const { viaClosure, viaThis } = make();
  assert.equal(viaClosure(), 1); assert.equal(viaClosure(), 2);              // detached from its object, it still has its variable
  assert.throws(() => viaThis(), TypeError);                                 // detached, `this` is gone
});

test('a closure is not a continuation: it can be called again, but it cannot resume in the middle of something', () => {
  const m = machine(hoursFrom(3));
  const first = m();
  assert.notDeepEqual(m(), first);                                           // calling again gives the NEXT card; the first call's moment is gone
  // there is no way to hand m a "return point": its only input is nextHours, fixed at creation
  assert.equal(m.length, 0);
});
