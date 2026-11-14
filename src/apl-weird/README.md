# APL, weirder

**Teaches you:** that `⎕FX` plus compress makes "if" and "loop" optional.

> **DEMO ONLY.** Fictional timecards in a scratch SQLite file. No connection to any real time-reporting system.

This is weird, even for APL folk.

## Run it

GNU APL (`apl`, from [gnu.org/software/apl](https://www.gnu.org/software/apl/)) and `sqlite3`.

```bash
cd src/apl-weird
apl --script -f timecards.apl
./check.sh                  # set APL=/path/to/apl if it is not on your PATH
```

Records go to `$XDG_DATA_HOME/AplWeird/demo-timecards.db` (default `~/.local/share/AplWeird/`).
