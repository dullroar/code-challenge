-- The machine's memory, created once per database. .parameter @seed and @week are set by run-clock.sh.
-- fsm is the whole state of one run: one row. Only a tick changes it (see tick.sql).
CREATE TABLE IF NOT EXISTS fsm(
    run_id  INTEGER PRIMARY KEY,
    seed    INTEGER NOT NULL,                    -- Park-Miller generator state
    card    INTEGER NOT NULL DEFAULT 0,          -- cards closed so far; picks the category
    worked  INTEGER NOT NULL DEFAULT 0,          -- hours worked on the open card
    target  INTEGER NOT NULL CHECK (target BETWEEN 10 AND 19),  -- hours this card will take
    total   INTEGER NOT NULL DEFAULT 0,          -- running total, in hours
    done    INTEGER NOT NULL DEFAULT 0,          -- 1 once a card has pushed the total over 40
    tick    INTEGER NOT NULL DEFAULT 0,          -- the last TAR_CHECKPOINT seen
    idle    INTEGER NOT NULL DEFAULT 0,          -- ticks that arrived after done, and changed nothing
    week    TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS demo_timecards(
    run_id INTEGER NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Meetings','Coding','Debugging','Learning')),
    hours INTEGER NOT NULL CHECK (hours BETWEEN 10 AND 19),
    running_total INTEGER NOT NULL,
    week TEXT NOT NULL,
    at_tick INTEGER NOT NULL,                    -- the checkpoint at which this card closed
    demo_only INTEGER NOT NULL CHECK (demo_only = 1));
-- The first card's length is drawn here, by the same formula tick.sql uses for every later card.
INSERT INTO fsm(seed, target, week)
    SELECT s, 10 + s % 10, @week FROM (SELECT @seed * 48271 % 2147483647 AS s);
SELECT last_insert_rowid();
