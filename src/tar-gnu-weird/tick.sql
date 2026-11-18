-- One checkpoint = one hour = one bounded transition of the machine. Run by tick.sh, with @t = TAR_CHECKPOINT.
-- Nothing in here loops, and nothing decides when tar stops: tar does not stop. After the stop rule has
-- fired (done = 1) a tick changes only the `idle` counter.
BEGIN;
UPDATE fsm SET idle = idle + 1, tick = @t
    WHERE run_id = (SELECT max(run_id) FROM fsm) AND done;
UPDATE fsm SET worked = worked + 1, total = total + 1, tick = @t
    WHERE run_id = (SELECT max(run_id) FROM fsm) AND NOT done;
INSERT INTO demo_timecards(run_id, category, hours, running_total, week, at_tick, demo_only)
    SELECT run_id,
           CASE card WHEN 0 THEN 'Meetings' WHEN 1 THEN 'Coding' WHEN 2 THEN 'Debugging' WHEN 3 THEN 'Learning' ELSE 'Meetings' END,
           worked, total, week, tick, 1
    FROM fsm WHERE run_id = (SELECT max(run_id) FROM fsm) AND NOT done AND worked = target;
UPDATE fsm SET card = card + 1, worked = 0, done = total > 40,
               seed = seed * 48271 % 2147483647, target = 10 + (seed * 48271 % 2147483647) % 10
    WHERE run_id = (SELECT max(run_id) FROM fsm) AND NOT done AND worked = target;
COMMIT;
