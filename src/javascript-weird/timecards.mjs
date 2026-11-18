import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { homedir, userInfo } from 'node:os';
import { join } from 'node:path';
import { cards, hoursFrom, machine } from './core.mjs';

// The leaf effects. Each one is a closure that does one thing to the outside world, and nothing else is impure.
const seed = Number(process.env.SEED) || crypto.getRandomValues(new Uint32Array(1))[0] % 2147483646 + 1;
const now = process.env.NOW ? new Date(`${process.env.NOW}T12:00:00Z`) : new Date();
const isoWeek = d => ((t, y) => [y = (t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7)), t.getUTCFullYear()),
                                 Math.ceil(((t - Date.UTC(y, 0, 1)) / 864e5 + 1) / 7)])(new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate())));
const db = (dir => (mkdirSync(dir, { recursive: true }), new DatabaseSync(join(dir, 'demo-timecards.db'))))(
  join(process.env.XDG_DATA_HOME ?? join(homedir(), '.local', 'share'), 'JavaScriptWeird'));
db.exec(`
  CREATE TABLE IF NOT EXISTS runs(id INTEGER PRIMARY KEY, seed INTEGER NOT NULL, demo_only INTEGER NOT NULL DEFAULT 1 CHECK (demo_only = 1));
  CREATE TABLE IF NOT EXISTS demo_timecards(run_id INTEGER NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Meetings','Coding','Debugging','Learning')),
    hours INTEGER NOT NULL CHECK (hours BETWEEN 10 AND 19), running_total INTEGER NOT NULL,
    user_id TEXT NOT NULL, year INTEGER NOT NULL, week INTEGER NOT NULL,
    demo_only INTEGER NOT NULL DEFAULT 1 CHECK (demo_only = 1));`);
const run = Number(db.prepare('INSERT INTO runs(seed) VALUES (?)').run(seed).lastInsertRowid);
// save: a closure over the prepared statement and the run. It saves one record and hands it back, so it can sit in a pipeline.
const save = (insert => r => (insert.run(run, r.category, r.hours, r.total, r.user, r.year, r.week), r))(
  db.prepare('INSERT INTO demo_timecards(run_id, category, hours, running_total, user_id, year, week) VALUES (?, ?, ?, ?, ?, ?, ?)'));
// stamp: a closure over the user and the date. It makes a card into a record.
const stamp = (user, [year, week]) => card => ({ ...card, user, year, week });

// THE PROGRAM. Nothing is drawn until `toArray` asks. Each ask pulls one card through the machine, stamps it and saves it,
// and the machine itself says when there are no more (the card that took the total over 40 was the last).
const records = Iterator.from(cards(machine(hoursFrom(seed)))).map(stamp(userInfo().username, isoWeek(now))).map(save).toArray();

// A fold over the finished list. reduce cannot stop early, and here it does not need to: the list is already complete.
const total = records.reduce((sum, r) => sum + r.hours, 0);
console.log(`# DEMO ONLY run ${run}\n${records.map(r => `${r.category}\t${r.hours}\t${r.total}\t${r.year}-W${String(r.week).padStart(2, '0')}\tDEMO ONLY`).join('\n')}\n`
  + `# committed total=${total} entries=${records.length} DEMO ONLY\n\nTotal simulated hours: ${total.toFixed(1)}\nSaved locally for the modernization exercise.`);

// The pulse is a separate effect, after everything is saved. Its two variables are closed over by the timer callback.
process.stdout.isTTY && process.env.TERM !== 'dumb' && ((plain, cycles) => {
  let frame = 0;
  const id = setInterval(() => {
    process.stdout.write(`\r\x1b[2K${plain ? (frame % 2 ? ' ' : '*') : frame % 2 ? '\x1b[2m' : '\x1b[1m'}DEMO ONLY - no real time system is involved${plain ? '' : '\x1b[0m'}`);
    frame++ >= 2 * cycles && (clearInterval(id), console.log());
  }, 600);
})('NO_COLOR' in process.env, Number(process.env.PULSE_CYCLES) || 3);
