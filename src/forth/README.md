# Forth

**Teaches you:** that a stack language needs one `begin ... until` and a pipe to be a whole program.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

This is how Forth appears.

## Run it

Gforth (`gforth`, 0.7.3 or later) and `sqlite3`.

```bash
cd src/forth
gforth timecards.fs
./check.sh                  # set GFORTH=/path/to/gforth if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/Forth/demo-timecards.db` (default `~/.local/share/Forth/`).
