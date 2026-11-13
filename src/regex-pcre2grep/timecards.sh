#!/usr/bin/env bash
# DEMO ONLY. Fictional timecards, written to a scratch SQLite file under XDG_DATA_HOME. See README.md.
#
# The program is the pattern below. This script only finds a pcre2grep whose callouts are enabled, moves
# to the scratch directory, and runs ONE pcre2grep command against a one-line "tape". It has no loop,
# does no arithmetic and makes no decisions; the callouts, helper exit codes and backtracking do.
set -euo pipefail

PCRE2GREP=${PCRE2GREP:-pcre2grep}
"$PCRE2GREP" --help 2>&1 | grep -q 'All callout scripts' || {
    echo "$PCRE2GREP was built without callout scripts; see README.md (set PCRE2GREP=/path/to/pcre2grep)" >&2
    exit 2
}

mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/RegexPcre2grep" && cd "${XDG_DATA_HOME:-$HOME/.local/share}/RegexPcre2grep"

rc=0
printf '%s\n' 'MeetingsCodingDebuggingLearning247250253254254253250247243239236233232232233236239243247251253254254253250247243239235233232232233236239243247251253254254253250246243239235233232232233236240244247251253254254253' |
"$PCRE2GREP" "$(cat <<'PATTERN'
^(?C{/usr/bin/sqlite3|-noheader|demo-timecards.db|CREATE TABLE IF NOT EXISTS runs(id INTEGER PRIMARY KEY,started_at TEXT);CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id INTEGER,category TEXT,hours INTEGER CHECK(hours BETWEEN 10 AND 19),running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));CREATE TABLE IF NOT EXISTS stop_rule(ok INTEGER CONSTRAINT "stop rule fired: total exceeds 40" CHECK(ok=1));INSERT INTO runs(started_at) VALUES(datetime('now','localtime'));SELECT printf('# DEMO ONLY run %d',last_insert_rowid())})(?:(?C{/usr/bin/sqlite3|demo-timecards.db|INSERT INTO stop_rule SELECT coalesce((SELECT max(running_total) FROM demo_timecards WHERE run_id=(SELECT max(id) FROM runs)),0)<=40;DELETE FROM stop_rule})(Meetings|Coding|Debugging|Learning)(?C{/usr/bin/sqlite3|-noheader|-separator|$t|demo-timecards.db|INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) SELECT r,'$1',h,t+h,printf('%s-W%02d',strftime('%Y',date('now','localtime','-3 days','weekday 4')),(strftime('%j',date('now','localtime','-3 days','weekday 4'))-1)/7+1),datetime('now','localtime') FROM (SELECT (SELECT max(id) FROM runs) AS r,10+abs(random())%10 AS h,coalesce((SELECT max(running_total) FROM demo_timecards WHERE run_id=(SELECT max(id) FROM runs)),0) AS t);SELECT category,hours,running_total,iso_week,'DEMO ONLY' FROM demo_timecards WHERE id=last_insert_rowid()}))*(*COMMIT)(?C{/usr/bin/sqlite3|-noheader|demo-timecards.db|SELECT printf('# committed total=%d entries=%d DEMO ONLY',coalesce(max(running_total),0),count(*)) FROM demo_timecards WHERE run_id=(SELECT max(id) FROM runs)})[A-Za-z]*(?:(?C{/usr/bin/test|-t|1})(\d{3})(?C{|$r$e[48;5;$2m  DEMO ONLY  $e[0m})(?C{/bin/sleep|0.05}))*(*COMMIT)(?:(?C{/usr/bin/test|-t|1})(?C{|$r$e[0m$e[K}))?+(?C{|# the match now returns false, on purpose$n})(*FAIL)
PATTERN
)" || rc=$?

exit $(( rc == 1 ? 0 : rc ))
