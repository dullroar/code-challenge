# Forth, weirder

**Teaches you:** that the text interpreter's parse position is a program counter, if you let it be.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

This is weird, even for Forth folk.

## Run it

Gforth (`gforth`, 0.7.3 or later) and `sqlite3`.

```bash
cd src/forth-weird
gforth timecards.fs
./check.sh                  # set GFORTH=/path/to/gforth if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/ForthWeird/demo-timecards.db` (default `~/.local/share/ForthWeird/`).
