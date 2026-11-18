import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { homedir, userInfo } from 'node:os';
import { join } from 'node:path';

// A Node.js port of Jim Lehmer's 2008 C# challenge: one `for` statement whose body is empty.
// Everything the program does happens in the three clauses between the parentheses: the initializer builds the state,
// the condition decides whether to go on (and, when it must stop, shows the result), the iterator adds one card.
// The cards are DEMO ONLY: fictional, local, and never sent anywhere.
for // Still the only statement.
(
  // The object literal is still the iterator-state holder. A `for` initializer takes one declaration, and this is
  // the one declaration that can hold a dozen kinds of state. It plays the part of C#'s anonymous object.
  // C# also lets the initializer be a list of expressions. JavaScript does not mix the two: after `let i = ...` a
  // comma starts the next *declarator*, it is not the comma operator. So the literal goes through an arrow that
  // finishes it, and the arrow's body can use the comma operator.
  let i = (s => (
    // A closure over the seed: Park-Miller. SEED=42 replays a run (Math.random cannot be seeded).
    s.rnd = (r => () => (r = r * 48271 % 2147483647))(s.seed),
    // Local SQLite file, as in the original (there: EF Core under LocalApplicationData). node:sqlite is built in.
    s.db.exec(`
      CREATE TABLE IF NOT EXISTS runs(id INTEGER PRIMARY KEY, seed INTEGER NOT NULL, demo_only INTEGER NOT NULL DEFAULT 1 CHECK (demo_only = 1));
      CREATE TABLE IF NOT EXISTS demo_timecards(run_id INTEGER NOT NULL,
        category TEXT NOT NULL CHECK (category IN ('Meetings','Coding','Debugging','Learning')),
        hours INTEGER NOT NULL CHECK (hours BETWEEN 10 AND 19), running_total INTEGER NOT NULL,
        user_id TEXT NOT NULL, year INTEGER NOT NULL, week INTEGER NOT NULL,
        demo_only INTEGER NOT NULL DEFAULT 1 CHECK (demo_only = 1));`),
    s.run = Number(s.db.prepare('INSERT INTO runs(seed) VALUES (?)').run(s.seed).lastInsertRowid),
    s.insert = s.db.prepare('INSERT INTO demo_timecards(run_id, category, hours, running_total, user_id, year, week) VALUES (?, ?, ?, ?, ?, ?, ?)'),
    s))({
      hours: [],
      user: userInfo().username,
      categories: ['Meetings', 'Coding', 'Debugging', 'Learning'],
      seed: Number(process.env.SEED) || crypto.getRandomValues(new Uint32Array(1))[0] % 2147483646 + 1,
      now: process.env.NOW ? new Date(`${process.env.NOW}T12:00:00Z`) : new Date(),
      // The ISO week of a date, as [ISO year, week]: the Thursday of the same week decides the year.
      iso: d => ((t, y) => [y = (t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7)), t.getUTCFullYear()),
                           Math.ceil(((t - Date.UTC(y, 0, 1)) / 864e5 + 1) / 7)])(new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))),
      db: (dir => (mkdirSync(dir, { recursive: true }), new DatabaseSync(join(dir, 'demo-timecards.db'))))(
        join(process.env.XDG_DATA_HOME ?? join(homedir(), '.local', 'share'), 'JavaScript')),
      tty: process.stdout.isTTY && process.env.TERM !== 'dumb',
      plain: 'NO_COLOR' in process.env,
      frames: 0,
    })
  //   *
  //  *
  ;   // **************** FIRST SEMICOLON ****************
  //  *
  //   *
  // The original sums the hours with LINQ's Sum(); a fold is its closest relative here. While the total is 40 or
  // under, the answer is `true` and the loop goes round again. Otherwise the condition shows the result, inline,
  // and its value is `false`: the loop ends. Where C# opened a WPF window, this prints, and, on a terminal, pulses
  // the DEMO ONLY line with a timer, as the original's storyboard faded its window in and out.
  i.hours.reduce((sum, h) => sum + h, 0) <= 40
    ? true
    : (console.log(`# DEMO ONLY run ${i.run}\n${i.db.prepare('SELECT category, hours, running_total, year, week FROM demo_timecards WHERE run_id = ? ORDER BY rowid').all(i.run)
        .map(r => `${r.category}\t${r.hours}\t${r.running_total}\t${r.year}-W${String(r.week).padStart(2, '0')}\tDEMO ONLY`).join('\n')}\n`
        + `# committed total=${i.hours.reduce((sum, h) => sum + h, 0)} entries=${i.hours.length} DEMO ONLY\n`
        + `\nTotal simulated hours: ${i.hours.reduce((sum, h) => sum + h, 0).toFixed(1)}\nSaved locally for the modernization exercise.`),
       i.tty && setInterval(function () {
         process.stdout.write(`\r\x1b[2K${i.plain ? (i.frames % 2 ? ' ' : '*') : i.frames % 2 ? '\x1b[2m' : '\x1b[1m'}DEMO ONLY - no real time system is involved${i.plain ? '' : '\x1b[0m'}`);
         i.frames++ >= 2 * (Number(process.env.PULSE_CYCLES) || 3) && (clearInterval(this), console.log());
       }, 600),
       false)
  //   *
  //  *
  ;  // **************** LAST SEMICOLON ****************
  //  *
  //   *
  // The iterator draws one random hour count and saves one card, as the original did. There, a background thread
  // and reflection did the saving through a Mutex; here node:sqlite saves synchronously, so none of that is needed.
  i.hours.push(10 + i.rnd() % 10),
  i.insert.run(i.run, i.categories[(i.hours.length - 1) % 4], i.hours.at(-1), i.hours.reduce((sum, h) => sum + h, 0),
               i.user, ...i.iso(i.now))
)
{ /* Intentionally empty. */ }
