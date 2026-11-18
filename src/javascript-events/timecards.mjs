import { EventEmitter } from 'node:events';
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { homedir, userInfo } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// The same challenge as ../javascript and ../javascript-weird, with no loop statement and no closure pipeline.
// The program is the set of LISTENERS registered on one EventEmitter. Each listener does one small thing and then
// emits the event that the next listener is waiting for. The visible start-up is one line, at the bottom of the file:
//
//     program(realWorld()).emit('start');
//
// DEMO ONLY: fictional time cards, saved to a scratch SQLite file. Nothing here touches real time reporting.
//
//   start --(setImmediate)--> generate --> card-created --> card-saved --> total-updated --+--> finished
//                                 ^                                                        |
//                                 +-------------------(setImmediate)----------------------+
//   Any listener that throws --> failed
//
// Two kinds of arrows. The plain arrows are emit(): Node calls every listener of that event, in the order they were
// registered, BEFORE emit() returns. The call stack grows by a few frames and unwinds again. The setImmediate arrows
// are different: the next step is put on the event loop's queue and runs only after the stack has unwound. Without
// that boundary, the chain of emits would be a recursion with one more level for every card.

const LIMIT = 40;
export const CATEGORIES = ['Meetings', 'Coding', 'Debugging', 'Learning'];

const SCHEMA = `
  CREATE TABLE IF NOT EXISTS runs(id INTEGER PRIMARY KEY, seed INTEGER NOT NULL, demo_only INTEGER NOT NULL DEFAULT 1 CHECK (demo_only = 1));
  CREATE TABLE IF NOT EXISTS demo_timecards(run_id INTEGER NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Meetings','Coding','Debugging','Learning')),
    hours INTEGER NOT NULL CHECK (hours BETWEEN 10 AND 19), running_total INTEGER NOT NULL,
    user_id TEXT NOT NULL, year INTEGER NOT NULL, week INTEGER NOT NULL,
    demo_only INTEGER NOT NULL DEFAULT 1 CHECK (demo_only = 1));`;

// The ISO year and week of a date: the Thursday of the same week decides the year.
export const isoWeek = d => {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
  const year = t.getUTCFullYear();
  return [year, Math.ceil(((t - Date.UTC(year, 0, 1)) / 864e5 + 1) / 7)];
};

// Everything the program needs from the outside world is one object, so a test can hand in its own. `rng` answers
// a number and the hours are 10 + (that number % 10); `schedule` runs a function on a LATER turn of the event loop;
// `open` makes the database; `every` starts a repeating timer and answers the function that stops it.
export const realWorld = () => {
  const seed = Number(process.env.SEED) || crypto.getRandomValues(new Uint32Array(1))[0] % 2147483646 + 1;
  const now = process.env.NOW ? new Date(`${process.env.NOW}T12:00:00Z`) : new Date();
  return {
    seed, limit: LIMIT, user: userInfo().username, week: isoWeek(now),
    rng: (r => () => (r = r * 48271 % 2147483647))(seed),           // Park-Miller: SEED=42 replays a run
    schedule: setImmediate,
    open: () => {
      const dir = join(process.env.XDG_DATA_HOME ?? join(homedir(), '.local', 'share'), 'JavaScriptEvents');
      mkdirSync(dir, { recursive: true });
      return new DatabaseSync(join(dir, 'demo-timecards.db'));
    },
    out: line => console.log(line), raw: text => process.stdout.write(text), err: line => console.error(line),
    tty: Boolean(process.stdout.isTTY) && process.env.TERM !== 'dumb', plain: 'NO_COLOR' in process.env,
    cycles: Number(process.env.PULSE_CYCLES) || 3,
    every: (fn, ms) => { const id = setInterval(fn, ms); return () => clearInterval(id); },
    exit: code => { process.exitCode = code; },
  };
};

export const program = world => {
  const { seed, limit, user, week, rng, schedule, open, out, raw, err, tty, plain, cycles, every, exit } = world;
  const events = new EventEmitter();
  const s = { db: null, insert: null, run: 0, n: 0, total: 0, frame: 0, stop: null };

  // A throw inside a listener travels UP through emit() to whoever called it. Here that is a scheduled callback
  // that nobody is waiting for, so the throw would end the process. Each listener catches it and reports it as an event.
  const on = (name, listener) => events.on(name, (...args) => {
    try { listener(...args); } catch (e) { events.emit('failed', e); }
  });
  const attempt = undo => { try { undo(); } catch { /* it is already broken: say nothing more */ } };
  const later = name => schedule(() => events.emit(name));       // the one place where a step waits for a new turn

  // 1. start: open the database and begin the transaction, then ask for the first card ON A LATER TURN.
  on('start', () => {
    s.db = open();
    s.db.exec(SCHEMA);
    s.db.exec('BEGIN');
    s.run = Number(s.db.prepare('INSERT INTO runs(seed) VALUES (?)').run(seed).lastInsertRowid);
    s.insert = s.db.prepare('INSERT INTO demo_timecards(run_id, category, hours, running_total, user_id, year, week) VALUES (?, ?, ?, ?, ?, ?, ?)');
    out(`# DEMO ONLY run ${s.run}`);
    later('generate');
  });

  // 2. generate: make one card. Emitting runs the listeners of card-created RIGHT NOW, inside this call.
  on('generate', () => {
    s.n += 1;
    events.emit('card-created', { category: CATEGORIES[(s.n - 1) % 4], hours: 10 + rng() % 10 });
  });

  // 3. card-created: save it. node:sqlite is synchronous, so the row is written when run() returns, before the
  //    next line, and nothing downstream can see a card that is not saved.
  on('card-created', card => {
    const total = s.total + card.hours;
    s.insert.run(s.run, card.category, card.hours, total, user, ...week);
    events.emit('card-saved', { ...card, total });
  });

  // 4. card-saved: only now does the running total change. Print the row.
  on('card-saved', card => {
    s.total = card.total;
    out(`${card.category}\t${card.hours}\t${card.total}\t${week[0]}-W${String(week[1]).padStart(2, '0')}\tDEMO ONLY`);
    events.emit('total-updated', s.total);
  });

  // 5. total-updated: the stop rule, and the only fork. Over the limit: announce the end now. Otherwise: the next card
  //    waits for a new turn, so the stack unwinds first.
  on('total-updated', total => (total > limit ? events.emit('finished') : later('generate')));

  // 6. finished: commit, report, close, and either end or hand over to the pulse timer.
  on('finished', () => {
    s.db.exec('COMMIT');
    out(`# committed total=${s.total} entries=${s.n} DEMO ONLY\n\nTotal simulated hours: ${s.total.toFixed(1)}\nSaved locally for the modernization exercise.`);
    s.db.close();
    s.db = null;
    if (!tty) return events.emit('done');
    s.stop = every(() => events.emit('frame'), 600);
  });

  // 7. frame: one tick of the pulse, from a timer. The timer is the only thing that keeps the process alive after the
  //    last card. Each tick is a separate turn of the event loop.
  on('frame', () => {
    raw(`\r\x1b[2K${plain ? (s.frame % 2 ? ' ' : '*') : s.frame % 2 ? '\x1b[2m' : '\x1b[1m'}DEMO ONLY - no real time system is involved${plain ? '' : '\x1b[0m'}`);
    if (s.frame++ >= 2 * cycles) { s.stop(); s.stop = null; raw('\n'); events.emit('done'); }
  });

  // 8. done: no listener is left behind, so nothing can keep the process alive and nothing can be called again.
  events.on('done', () => { events.removeAllListeners(); exit(0); });

  // 9. failed: runs once. Undo what was not committed, release everything, tell the user. The last step removes every
  //    listener, this one too, so a second failure finds nobody to tell. That is what makes it exactly once.
  events.on('failed', e => {
    attempt(() => s.db?.exec('ROLLBACK'));
    attempt(() => s.db?.close());
    attempt(() => s.stop?.());
    err(`timecards: ${e?.message ?? e}`);
    events.removeAllListeners();
    exit(1);
  });

  // The name 'error' is special in Node: emit('error', e) with NO listener THROWS e. This listener turns a stray
  // 'error' into our own 'failed', so the program has one way to fail.
  events.on('error', e => events.emit('failed', e));
  return events;
};

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) program(realWorld()).emit('start');
