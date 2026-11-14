# APL

**Teaches you:** that five rolls and a take-while can replace a loop.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

This is how APL appears.

## Run it

GNU APL (`apl`, built from [gnu.org/software/apl](https://www.gnu.org/software/apl/)) and `sqlite3`.

```bash
cd src/apl
apl --script -f timecards.apl
./check.sh                  # set APL=/path/to/apl if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/Apl/demo-timecards.db` (default `~/.local/share/Apl/`).
