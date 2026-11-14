# Haskell on drugs

**Teaches you:** knot-tying, where a lazy list's stop rule is read off its own elements.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

This is Haskell on drugs.

## Run it

GHC (`runghc`) and `sqlite3`. Only packages that ship with GHC are used (`time`, `process`, `directory`, `unix`).

```bash
cd src/haskell-weird
runghc timecards.hs
./check.sh                  # set RUNGHC=/path/to/runghc if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/HaskellWeird/demo-timecards.db` (default `~/.local/share/HaskellWeird/`).
