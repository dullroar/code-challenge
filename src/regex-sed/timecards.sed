# DEMO ONLY. Fictional timecards. GNU sed, run as: sed -nEu -f timecards.sed 3>(sql sink). See README.md.
# The whole program state is ONE line of text. No variables, no numbers, no arithmetic: hours are tally
# marks, the random draws are a 16-bit shift register made of 0s and 1s, every decision is "did this
# regex match?", the SQL goes out on fd 3 for sqlite3 to run, and the script ends by exiting 1 (failure).
s/^run:([^ ]+) wk:([^ ]+) rng:([01]{16}) tty:([0-9]+) trace:([01])$/run:\1 wk:\2 tty:\4 trace:\5 rng:\3 cats:Meetings,Coding,Debugging,Learning, tot: n:/
T bad
s/ rng:0{16} / rng:0000000000000001 /
h
s/^run:([^ ]+) .*/# DEMO ONLY run \1/p
s/.*/CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER CHECK(hours BETWEEN 10 AND 19),running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));\nBEGIN;/w /dev/fd/3
g
:entry
/ trace:1 /w /dev/stderr
/ tot:#{41}/b done
/ cats: /b done
s/ cats:([A-Za-z]+),(.*)$/ cats:\2 c:\1/
:draw
s/ rng:/ k:#### rng:/
:step
s/ rng:([01]{10})([01])([01])([01])([01])([01])([01]) / rng:\1\2\3\4\5\6\7 x:\2\4\5\7 /
s/ x:0*(1?)0*(1?)0*(1?)0*(1?)0* / x:\1\2\3\4 /
s/ x:(11)*1 / x:1 /
s/ x:(11)* / x:0 /
s/ rng:([01]{15})[01] x:([01]) / rng:\2\1 /
s/ k:#/ k:/
/ trace:1 /w /dev/stderr
/ k:#/b step
s/ k: / /
/ rng:1(01|1)/b draw
s/ rng:([01]{4})(.*)$/ rng:\1\2 d:\1/
s/ d:0000$/ d:0/
s/ d:0001$/ d:1/
s/ d:0010$/ d:2/
s/ d:0011$/ d:3/
s/ d:0100$/ d:4/
s/ d:0101$/ d:5/
s/ d:0110$/ d:6/
s/ d:0111$/ d:7/
s/ d:1000$/ d:8/
s/ d:1001$/ d:9/
s/ d:([0-9])$/ d:\1 D:##########\1/
s/ D:(#*)9$/ D:\1#########/
s/ D:(#*)8$/ D:\1########/
s/ D:(#*)7$/ D:\1#######/
s/ D:(#*)6$/ D:\1######/
s/ D:(#*)5$/ D:\1#####/
s/ D:(#*)4$/ D:\1####/
s/ D:(#*)3$/ D:\1###/
s/ D:(#*)2$/ D:\1##/
s/ D:(#*)1$/ D:\1#/
s/ D:(#*)0$/ D:\1/
s/ tot:(#*) (.*) D:(#*)$/ tot:\1\3 \2/
s/ n:(%*) / n:\1% /
h
s/^run:([^ ]+) wk:([^ ]+) .* tot:(#+) .* c:([A-Za-z]+) d:([0-9])$/ret:row \4\t1\5\t\3\t\2\tDEMO ONLY\n\1/
b dec
:row
s/^ret:row //
P
s/^([A-Za-z]+)\t([0-9]+)\t([0-9]+)\t([^\t]+)\tDEMO ONLY\n(.*)$/INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES('\5','\1',\2,\3,'\4',datetime('now','localtime'));/w /dev/fd/3
g
s/ c:[A-Za-z]+ d:[0-9]$//
b entry
:dec
s/#{10}/@/g
s/@([^#@])/@0\1/
s/#########/9/
s/########/8/
s/#######/7/
s/######/6/
s/#####/5/
s/####/4/
s/###/3/
s/##/2/
s/#/1/
s/@@@@@/5/
s/@@@@/4/
s/@@@/3/
s/@@/2/
s/@/1/
/^ret:row /b row
/^ret:sum /b sum
b bad
:done
h
s/^run:([^ ]+) .* tot:(#*) n:(%*).*$/ret:sum committed total=\2 entries=\3 DEMO ONLY/
b dec
:sum
s/^ret:sum /# /
s/ entries=%%%% / entries=4 /
s/ entries=%%% / entries=3 /
s/ entries=%% / entries=2 /
s/ entries=% / entries=1 /
s/ entries= / entries=0 /
p
s/.*/COMMIT;/w /dev/fd/3
g
/ tty:0 /!b fin
s/$/ shades:247,250,253,254,254,253,250,247,243,239,236,233,232,232,233,236,239,243,247,251,253,254,254,253,250,247,243,239,235,233,232,232,233,236,239,243,247,251,253,254,254,253,250,246,243,239,235,233,232,232,233,236,240,244,247,251,253,254,254,253,/
h
s/.*//p
g
:pulse
/ shades:$/b settle
h
s/.*/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaacb/
/^(a+)\1*(a+)\2*b/b settle
g
s/.* shades:([0-9]+),.*/\x1b[A\r\x1b[48;5;\1m  DEMO ONLY  \x1b[0m/p
g
s/ shades:[0-9]+,/ shades:/
b pulse
:settle
s/.*/\x1b[A\r\x1b[K# sed now exits with status 1 (failure), on purpose/p
Q1
:fin
s/.*/# sed now exits with status 1 (failure), on purpose/p
Q1
:bad
s/.*/timecards.sed: malformed tape or internal error/w /dev/stderr
Q2
