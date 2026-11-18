#!/bin/sh
# The whole interpreter that tar calls: once per regular member, with the member's bytes on stdin.
# It owns NO loop, NO category order, NO dice and NO "when to stop" arithmetic. Those live in the archive:
# member order, the cards' contents, and a `stop-over` member that carries the limit.
# What it owns is the meaning of five words (begin, card, stop-over, show, and "anything else is an error").
# Everything arrives from the archive, so everything is checked with a strict pattern before it is used.
set -u
db=${TARPROG_DB:?TARPROG_DB must name the demo database}
name=${TAR_FILENAME-}
size=${TAR_SIZE:-0}

q() { sqlite3 "$db" "$@"; }   # persistence plumbing: one sqlite3 per member
# A bad record fails closed. tar does NOT stop when this exits non-zero (it reports the status and goes on
# with the next member), so the fault is also written to the database and every later member is refused.
refuse() {
    echo "tarprog: refused '$name': $1" >&2
    [ -f "$db" ] && q "insert into trace(name, outcome) values ('$(printf %s "$name" | tr -cd 'A-Za-z0-9._-')', 'refused: $1');
                       update runs set faulted = 1 where id = (select max(id) from runs);" 2>/dev/null
    exit 1
}

[ "$size" -le 256 ] 2>/dev/null || refuse "member bigger than 256 bytes"
body=$(cat)   # tiny, by the check above

case $name in
    [0-9][0-9][0-9].begin|[0-9][0-9][0-9].card|[0-9][0-9][0-9].stop-over|[0-9][0-9][0-9].show) op=${name#???.} ;;
    *) refuse "unknown record type" ;;
esac

if [ "$op" != begin ]; then
    [ -f "$db" ] || refuse "no begin record yet"
    [ "$(q 'select faulted from runs order by id desc limit 1')" = 0 ] || refuse "an earlier record was refused"
fi

line() { printf '%s\n' "$body" | sed -n "$1p"; }
case $op in
begin)   # format=tarprog/1 / seed=N / label=DEMO ONLY
    [ "$(line 1)" = "format=tarprog/1" ] && [ "$(line 3)" = "label=DEMO ONLY" ] && [ -z "$(line 4)" ] || refuse "bad begin record"
    seed=$(line 2); case $seed in seed=[0-9]|seed=[0-9][0-9]*) seed=${seed#seed=} ;; *) refuse "bad seed" ;; esac
    case $seed in *[!0-9]*) refuse "bad seed" ;; esac
    q "create table if not exists runs(id integer primary key, seed integer not null, halted integer not null default 0,
         faulted integer not null default 0, demo_only integer not null default 1 check (demo_only = 1));
       create table if not exists demo_timecards(run_id integer not null, category text not null
         check (category in ('Meetings','Coding','Debugging','Learning')),
         hours integer not null check (hours between 10 and 19), running_total integer not null,
         week text not null, demo_only integer not null check (demo_only = 1));
       create table if not exists trace(n integer primary key, name text, outcome text);
       insert into runs(seed) values ($seed);"
    echo "# DEMO ONLY run $(q 'select max(id) from runs')"
    ;;
card)    # category=Name / hours=NN
    cat_=$(line 1); hrs=$(line 2)
    case $cat_ in category=Meetings|category=Coding|category=Debugging|category=Learning) cat_=${cat_#category=} ;; *) refuse "bad category" ;; esac
    case $hrs in hours=1[0-9]) hrs=${hrs#hours=} ;; *) refuse "bad hours" ;; esac
    [ -z "$(line 3)" ] || refuse "extra lines in card"
    week=$(date +%G-W%V)
    if [ "$(q 'select halted from runs order by id desc limit 1')" = 1 ]; then outcome="ignored: halted"
    else
        q "insert into demo_timecards select r.id, '$cat_', $hrs,
             $hrs + coalesce((select max(running_total) from demo_timecards where run_id = r.id), 0), '$week', 1
           from (select max(id) as id from runs) r;"
        outcome=ok
    fi
    ;;
stop-over)   # limit=N : halt the machine if the running total is above N
    lim=$(line 1); case $lim in limit=[0-9]|limit=[0-9][0-9]*) lim=${lim#limit=} ;; *) refuse "bad limit" ;; esac
    case $lim in *[!0-9]*) refuse "bad limit" ;; esac
    q "update runs set halted = 1 where id = (select max(id) from runs)
         and (select coalesce(max(running_total), 0) from demo_timecards where run_id = runs.id) > $lim;"
    outcome=ok
    ;;
show)
    run=$(q 'select max(id) from runs')
    q -separator '	' "select category, hours, running_total, week, 'DEMO ONLY' from demo_timecards where run_id = $run order by rowid;"
    echo "# committed total=$(q "select coalesce(max(running_total),0) from demo_timecards where run_id = $run") entries=$(q "select count(*) from demo_timecards where run_id = $run") DEMO ONLY"
    ;;
esac
q "insert into trace(name, outcome) values ('$name', '${outcome:-ok}');"
