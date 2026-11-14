# DEMO ONLY. Fictional timecards, written to a scratch SQLite file under XDG_DATA_HOME. See README.md.
#
# "One Statement, Two Semicolons", but the build tool is the interpreter. Run `make` in a directory that
# holds only this file. There is no $(shell) anywhere: Make reads its own entropy, clock and arithmetic
# out of /proc with $(file </...) and counts in unary with $(words)/$(wordlist). The recipes only
# exist to (a) make Make notice a file changed, (b) mkdir, (c) talk to sqlite3 and (d) clean up.
#
#   LOOP    Make re-executes itself once per timecard. Each pass includes every .tc-N.mk written so far
#           and, if the running total is still <= 40, a pattern rule writes the next one. A file that
#           appears is "remade", so Make restarts; $(MAKE_RESTARTS) is the loop counter. When the rule
#           declines to write a file (total > 40) nothing is remade, Make stops restarting, and `all` runs.
#   STOP    "total > 40" is "the 41st word of a list of x's exists".
#   HOURS   1 followed by one decimal digit of /proc/sys/kernel/random/uuid.

.DEFAULT_GOAL := all
.PHONY: all clean check
.DELETE_ON_ERROR:

# ---- the ruler: 60000 x's (days since 1970: good to 2134), so numbers are lists and arithmetic is list surgery -----------------------
space := $(subst ,, )
define TAB
	
endef
define NL


endef
ten := x x x x x x x x x x
hun := $(ten) $(ten) $(ten) $(ten) $(ten) $(ten) $(ten) $(ten) $(ten) $(ten)
ths := $(hun) $(hun) $(hun) $(hun) $(hun) $(hun) $(hun) $(hun) $(hun) $(hun)
tt  := $(ths) $(ths) $(ths) $(ths) $(ths) $(ths) $(ths) $(ths) $(ths) $(ths)
U   := $(tt) $(tt) $(tt) $(tt) $(tt) $(tt)

# ---- arithmetic with no arithmetic ---------------------------------------------------------------------
z     = $(if $(filter 0%,$1),$(call z,$(patsubst 0%,%,$1)),$1)
u     = $(if $(call z,$1),$(wordlist 1,$(call z,$1),$(U)))
add   = $(words $(call u,$1) $(call u,$2))
inc   = $(words x $(call u,$1))
sub   = $(words $(wordlist $(call inc,$2),$1,$(U)))
ge    = $(if $(call u,$2),$(if $(word $(call z,$2),$(call u,$1)),T),T)
mod   = $(if $(call ge,$1,$2),$(call mod,$(call sub,$1,$2),$2),$(or $(call z,$1),0))
tot   = $(words $(foreach h,$1,$(call u,$h)))
chars = $(strip $(subst 0,0 ,$(subst 1,1 ,$(subst 2,2 ,$(subst 3,3 ,$(subst 4,4 ,$(subst 5,5 ,$(subst 6,6 ,$(subst 7,7 ,$(subst 8,8 ,$(subst 9,9 ,$1)))))))))))
rev   = $(if $1,$(call rev,$(wordlist 2,$(words $1),$1)) $(firstword $1))
nodig = $(subst a,,$(subst b,,$(subst c,,$(subst d,,$(subst e,,$(subst f,,$(subst -,,$1)))))))

# decimal addition of two digit strings, least significant digit first, carry along: $1+$2
dadd  = $(call da,$(call rev,$(call chars,$1)),$(call rev,$(call chars,$2)),,)
da    = $(if $1$2$3,$(call da2,$(words $(call u,$(firstword $1)) $(call u,$(firstword $2)) $(call u,$3)),$(wordlist 2,$(words $1),$1),$(wordlist 2,$(words $2),$2),$4),$(or $(call z,$4),0))
da2   = $(call da,$2,$3,$(if $(word 10,$(call u,$1)),1),$(if $(word 10,$(call u,$1)),$(call sub,$1,10),$1)$4)

# long division of a decimal string by 864, digit by digit (864 * 100 = 86400 seconds in a day)
M1:=864
M2:=1728
M3:=2592
M4:=3456
M5:=4320
M6:=5184
M7:=6048
M8:=6912
M9:=7776
M0:=0
dstep  = $(call dstep2,$(words $(foreach i,$(ten),$(call u,$1)) $(call u,$2)))
dstep2 = $(call dstep3,$(words $(foreach m,1 2 3 4 5 6 7 8 9,$(if $(word $(M$m),$(call u,$1)),x))),$1)
dstep3 = $1:$(call sub,$2,$(M$1))
ldiv   = $(if $1,$(call ldiv2,$(wordlist 2,$(words $1),$1),$(call dstep,$2,$(firstword $1)),$3),$(or $(call z,$3),0))
ldiv2  = $(call ldiv,$1,$(word 2,$(subst :, ,$2)),$3$(word 1,$(subst :, ,$2)))
days   = $(call ldiv,$(wordlist 1,$(call sub,$(words $(call chars,$1)),2),$(call chars,$1)),0,)

# civil calendar: walk years from 1970, then ISO week from the Thursday of the date's week
last2   = $(wordlist $(call sub,$(words $(call chars,$1)),1),$(words $(call chars,$1)),$(call chars,$1))
isleap  = $(call isleap2,$(subst $(space),,$(call last2,$1)),$(subst $(space),,$(wordlist 1,2,$(call chars,$1))))
isleap2 = $(if $(filter 00,$1),$(if $(filter 0,$(call mod,$2,4)),T),$(if $(filter 0,$(call mod,$1,4)),T))
yearlen = $(if $(call isleap,$1),366,365)
yr      = $(if $(call ge,$2,$(call yearlen,$1)),$(call yr,$(call inc,$1),$(call sub,$2,$(call yearlen,$1))),$1:$2)
n53    := 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53
div7    = $(words $(foreach k,$(n53),$(if $(call ge,$1,$(words $(foreach i,1 2 3 4 5 6 7,$(call u,$k)))),x)))
pad2    = $(if $(word 10,$(call u,$1)),$1,0$1)
mod7s   = $(call mod7r,$(call chars,$1),0)
mod7r   = $(if $1,$(call mod7r,$(wordlist 2,$(words $1),$1),$(call mod,$(words $(foreach i,$(ten),$(call u,$2)) $(call u,$(firstword $1))),7)),$(or $(call z,$2),0))
isoweek = $(call isow,$(call days,$1))
isow    = $(call isow2,$1,$(call mod7s,$(call add,$1,3)))
isow2   = $(call isow3,$(call sub,$(call add,$1,3),$2))
isow3   = $(call isow4,$(call yr,1970,$1))
isow4   = $(word 1,$(subst :, ,$1))-W$(call pad2,$(call inc,$(call div7,$(word 2,$(subst :, ,$1)))))

# ---- the world, read without a shell ---------------------------------------------------------------------
proc_stat   := $(subst btime ,btime@,$(file </proc/stat))
btime       := $(patsubst btime@%,%,$(filter btime@%,$(proc_stat)))
uptime      := $(firstword $(subst ., ,$(firstword $(file </proc/uptime))))
NOW         ?= $(call dadd,$(btime),$(uptime))
cat_names   := Meetings Coding Debugging Learning
DB          := $(or $(XDG_DATA_HOME),$(HOME)/.local/share)/MakeChallenge/demo-timecards.db

# ---- the loop ------------------------------------------------------------------------------------------------
K := $(or $(MAKE_RESTARTS),0)
# only a real run loops: `make pop`, `make clean` and `make check` never write (or read) cards
runs := $(filter-out pop clean check,$(or $(MAKECMDGOALS),all))
$(if $(and $(runs),$(filter 0,$(K)),$(wildcard .tc-*.mk)),$(error leftover .tc-*.mk from an interrupted run: `make clean`))
include $(if $(runs),$(wildcard .tc-*.mk))
-include $(if $(runs),.tc-$(K).mk)

slots  := 0 1 2 3 4 5 6 7 8 9
cards  := $(foreach k,$(slots),$(if $(H$k),$k))
HOURS  := $(foreach k,$(cards),$(H$k))
TOTAL  := $(call tot,$(HOURS))
digits := $(call chars,$(call nodig,$(file </proc/sys/kernel/random/uuid)))

# one new card per Make process, but only while the running total is still <= 40
.tc-%.mk:
	$(if $(word 41,$(foreach h,$(HOURS),$(call u,$h))),,$(file >$@,C$*:=$(or $(word $(call inc,$*),$(cat_names)),$(firstword $(cat_names)))$(NL)H$*:=1$(or $(firstword $(digits)),0))@:)

# ---- the report ---------------------------------------------------------------------------------------------------
SCHEMA := CREATE TABLE IF NOT EXISTS runs(id INTEGER PRIMARY KEY,started_at TEXT); \
 CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id INTEGER,category TEXT,hours INTEGER CHECK(hours BETWEEN 10 AND 19),running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1)); \
 CREATE TABLE IF NOT EXISTS stop_rule(ok INTEGER CONSTRAINT "stop rule fired: total exceeds 40" CHECK(ok=1)); \
 INSERT INTO runs(started_at) VALUES(datetime('now','localtime')); \
 SELECT printf('\# DEMO ONLY run %d',last_insert_rowid());

row    = $(C$1)$(TAB)$(H$1)$(TAB)$(call tot,$(wordlist 1,$(call inc,$1),$(HOURS)))$(TAB)$(WEEK)$(TAB)DEMO ONLY
insert = INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES((SELECT max(id) FROM runs),'$(C$1)',$(H$1),$(call tot,$(wordlist 1,$(call inc,$1),$(HOURS))),'$(WEEK)',datetime('now','localtime'));
STOP   := INSERT INTO stop_rule SELECT coalesce((SELECT max(running_total) FROM demo_timecards WHERE run_id=(SELECT max(id) FROM runs)),0)<=40; DELETE FROM stop_rule;

# the report is a chain of phony targets: Make expands every line of a recipe before running any of them,
# but expands a *target's* recipe only when that target runs, so the chain keeps the SQLite header, the rows,
# the footer and the glow in order
.PHONY: init rows footer
init:
	@mkdir -p $(dir $(DB))
	$(file >.init.sql,$(SCHEMA))@sqlite3 -noheader $(DB) <.init.sql

rows: init
	$(eval WEEK := $(call isoweek,$(NOW)))$(foreach k,$(cards),$(info $(call row,$k)))$(file >.rows.sql,$(foreach k,$(cards),$(call insert,$k)) $(STOP))@:
	@sqlite3 $(DB) <.rows.sql || :

footer: rows
	$(info # committed total=$(TOTAL) entries=$(words $(cards)) DEMO ONLY)$(info # make re-executed itself $(K) times, once per card)@:

# ---- the glow: one phony target per animation frame --------------------------------------------------------------
# Only on a real terminal. Make can tell without a shell: realpath of its own stdout is /dev/pts/N for a tty and
# nothing for a pipe or a file. A grey ramp up and back down (256-colour background), then the banner is erased.
define ESC

endef
istty  := $(filter /dev/pts/% /dev/tty%,$(realpath /proc/self/fd/1))
ramp   := 232 234 236 238 240 242 244 246 248 250 252 254 254 252 250 248 246 244 242 240 238 236 234 232 0
frames := $(if $(istty),$(foreach i,$(wordlist 1,$(words $(ramp)),$(n53)),glow-$i-$(word $i,$(ramp))))

glow-%: footer
	$(call frame,$(word 1,$(subst -, ,$*)),$(word 2,$(subst -, ,$*)))@sleep 0.06

# ESC[1A: back up onto the banner line; ESC[2K: wipe it; then the new shade (dark text on the bright half)
frame = $(info $(if $(filter-out 1,$1),$(ESC)[1A)$(ESC)[2K$(if $(filter 0,$2),,$(ESC)[48;5;$2m$(ESC)[$(if $(filter 244 246 248 250 252 254,$2),30,97)m  DEMO ONLY  $(ESC)[0m))

all: footer $(frames)
	@rm -f .tc-*.mk .init.sql .rows.sql

# ---- pop a window -----------------------------------------------------------------------------------------------------
# `make pop` opens a Windows Terminal window (from WSL), runs the demo in it, and lets the window go when make exits.
.PHONY: pop
pop:
	wt.exe -w new new-tab --title "DEMO ONLY" wsl.exe -d $(WSL_DISTRO_NAME) --cd $(CURDIR) -e make -f $(firstword $(MAKEFILE_LIST))

clean:
	rm -f .tc-*.mk .init.sql .rows.sql

check:
	./check.sh
