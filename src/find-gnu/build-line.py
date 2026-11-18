#!/usr/bin/env python3
"""Prints the one `find` command that timecards.sh runs (the GNU version).

Same stunt as src/find-posix, with every GNU extra switched on, so the machine is much smaller:
  -printf directives   %d (depth) IS the running total; %TG-W%TV (the new directory's mtime) IS the ISO week
  -fprintf /dev/fd/3   the SQL goes to fd 3, so mktemp's stdout noise needs no comment trick
  -regex               "at least n cards" and "at least 41 levels" are regular expressions
  -O3                  the cost-based optimizer is on; check.sh proves it never changes the answer
This script is the readable source of the long tables; check.sh fails if timecards.sh drifts from it.

The machine. One directory per hour, so the depth of a directory is the hours so far. A card is:
  <R>     six random characters (mktemp): the card's FIRST hour, and its dice
  b<NN>   a countdown, b17 ... b00: one directory per remaining hour
The next card's <R> hangs under the previous card's b00.
"""
DIGITS = "0123456789"
# 60 of the 62 mktemp characters in ten groups of six; Y and Z are re-rolled (see the portable README)
CLASSES = ["abcdef", "ghijkl", "mnopqr", "stuvwx", "yz0123", "456789", "ABCDEF", "GHIJKL", "MNOPQR", "STUVWX"]
SQL = "/dev/fd/3"


def ex(*words):
    return "-exec " + " ".join(words) + " \\;"


def out(fmt):  # one piece of SQL, to fd 3
    return "-fprintf " + SQL + ' "' + fmt + '"'


def alt(branches):
    return " -o ".join("\\( " + b + " \\)" for b in branches)


def cards(n):  # at least n six-character names in the path: the card count
    return "'(.*/[^/]{6}){%d}.*'" % n


MK = ex("mktemp", "-d", "{}/XXXXXX")
HEAD = ("INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week) "
        "VALUES((SELECT max(id) FROM runs),")

# 1. the start directory: deal the first card
rule_start = "-path t " + MK

# 2. a card's dice: open the row, name the category, print the hours, dig the countdown.
#    The dice directory is hour 1, so a card of H hours digs b(H-2) ... b00.
category = alt([
    "-regex " + cards(5) + " " + out("'Meetings',"),
    "-regex " + cards(4) + " " + out("'Learning',"),
    "-regex " + cards(3) + " " + out("'Debugging',"),
    "-regex " + cards(2) + " " + out("'Coding',"),
    out("'Meetings',"),
])


def dice(d, glob):
    return "-name '" + glob + "' " + out("%d," % (10 + d)) + " " + ex("mkdir", "{}/b%02d" % (8 + d))


hours = alt(
    [dice(d, "?" * 5 + "[" + CLASSES[d] + "]") for d in range(10)]              # last character
    + [dice(d, "?" * 4 + "[" + CLASSES[d] + "][YZ]") for d in range(10)]        # re-roll on the one before
    + [out("10,") + " " + ex("mkdir", "{}/b08")]                                 # re-rolled twice
)
rule_dice = "-name '??????' " + out(HEAD) + " \\( " + category + " \\) \\( " + hours + " \\)"

# 3. the end of a card: the depth is the total and the directory's mtime is the week. Stop once the depth
#    is 41 or more (nothing more is dug, so find runs out of tree); otherwise deal the next card.
#    -quit would end find sooner, but find then skips its -D rates profile, so it is not used.
over_40 = "-regex '([^/]*/){41}.*'"
rule_end = ("-name b00 " + out("%d,'%TG-W%TV');\\n") + " \\( " + over_40 + " -o \\( " + MK + " \\) \\)")

# 4. a countdown: b17 digs b16, and so on
rule_count = "-name 'b??' \\( " + alt(["-name b%02d " % n + ex("mkdir", "{}/b%02d" % (n - 1)) for n in range(17, 0, -1)]) + " \\)"

print("find -O${FIND_O:-3} ${FIND_D:+-D $FIND_D} t -regextype posix-extended \\( " + rule_start + " \\) -o \\( " + rule_dice
      + " \\) -o \\( " + rule_end + " \\) -o \\( " + rule_count + " \\)")
