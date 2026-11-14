# Haskell

**Teaches you:** that a lazy list and one `takeWhile` are the whole stop rule.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

This is straightforward Haskell.

## Run it

GHC (`runghc`) and `sqlite3`. Only packages that ship with GHC are used (`time`, `process`, `directory`, `unix`).

```bash
cd src/haskell
runghc timecards.hs
./check.sh                  # set RUNGHC=/path/to/runghc if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/Haskell/demo-timecards.db` (default `~/.local/share/Haskell/`).
