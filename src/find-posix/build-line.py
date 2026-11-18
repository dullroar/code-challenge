#!/usr/bin/env python3
"""Prints the one `find` command that timecards.sh runs.

The command is ~6 KB because find has no variables, so every "table" is spelled out as -o branches.
The tables are regular, which is why they are generated here instead of typed. This script is NOT
part of the program: it is the readable source of the program's tables. check.sh regenerates the
line and fails if timecards.sh has drifted from it.

Primaries used, and only these: -path -name -o -exec   (plus the implicit -a and escaped parentheses).
Programs run by -exec, and only these: printf mkdir mktemp date.

The machine, in one paragraph. The walk digs the tree it is walking. One directory = one step:
  <u>   one hour; named by the running total's last digit (1..9,0,1..): a unit counter you read off the name
  b<NN> hours still to go in this card (b18..b00): a countdown you read off the name
  <R>   six random characters from mktemp: the card's dice (the last character picks the hours)
A card is R, then pairs u/bNN down to b00; the next card's R hangs under that b00. The total is the
number of u segments in the path: ten times the count of "0" segments, plus the last u.
"""
S6 = "[!/]" * 6  # exactly six non-slash characters: an R segment
# 60 of the 62 mktemp characters in ten groups of six; Y and Z are re-rolled (see README)
CLASSES = ["abcdef", "ghijkl", "mnopqr", "stuvwx", "yz0123", "456789", "ABCDEF", "GHIJKL", "MNOPQR", "STUVWX"]
DIGITS = "0123456789"
SUCC = {d: DIGITS[(i + 1) % 10] for i, d in enumerate(DIGITS)}


def ex(*words):
    return "-exec " + " ".join(words) + " \\;"


def q(s):  # shell-quote for the line; SQL text has single quotes, so it gets double quotes
    return '"' + s + '"' if "'" in s else "'" + s + "'"


def path(p):
    return "-path " + q(p)


def alt(branches):
    return " -o ".join("\\( " + b + " \\)" for b in branches)


def wraps(n):  # at least n path segments named exactly 0 (each one is a +10)
    return "*" + "/0/*" * n


def cards(n):  # at least n six-character segments (each one is a card)
    return "*" + ("/" + S6 + "*") * n


# One new random directory per card; its path goes to stdout, so it is printed as an SQL comment.
NEXT_CARD = ex("printf", q(" -- ")) + " " + ex("mktemp", "-d", "{}/XXXXXX")

HEAD = ("INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week) "
        "VALUES((SELECT max(id) FROM runs),")

# 1. the start directory: nothing has happened yet, so deal the first card
rule_start = path("t") + " " + NEXT_CARD

# 2. a card's dice (six-character name): open the SQL row, name the category (how many cards are
#    above us), then dig the card's first hour. The hour's digit is the previous card's last digit + 1.
category = alt([
    path(cards(5)) + " " + ex("printf", q("'Meetings',")),
    path(cards(4)) + " " + ex("printf", q("'Learning',")),
    path(cards(3)) + " " + ex("printf", q("'Debugging',")),
    path(cards(2)) + " " + ex("printf", q("'Coding',")),
    ex("printf", q("'Meetings',")),
])
first_hour = alt(
    [path("*/%s/b00/%s" % (d, S6)) + " " + ex("mkdir", "{}/" + SUCC[d]) for d in DIGITS]
    + [ex("mkdir", "{}/1")]
)
rule_dice = "-name '??????' " + ex("printf", q(HEAD)) + " \\( " + category + " \\) \\( " + first_hour + " \\)"

# 3. an hour (one-character name). The first hour of a card reads the dice: it prints the card's
#    hours (10 + group number) and digs the countdown. A later hour digs the countdown one lower.
def dice(d, pattern):
    return (path("*/" + pattern + "/?") + " " + ex("printf", q("%d," % (10 + d)))
            + " " + ex("mkdir", "{}/b%02d" % (9 + d)))


hour = alt(
    [dice(d, "[!/]" * 5 + "[" + CLASSES[d] + "]") for d in range(10)]                # last character
    + [dice(d, "[!/]" * 4 + "[" + CLASSES[d] + "][YZ]") for d in range(10)]          # re-roll on the one before
    + [path("*/" + S6 + "/?") + " " + ex("printf", q("10,")) + " " + ex("mkdir", "{}/b09")]  # re-rolled twice
    + [path("*/b%02d/?" % n) + " " + ex("mkdir", "{}/b%02d" % (n - 1)) for n in range(18, 0, -1)]
)
rule_hour = "-name '?' \\( " + hour + " \\)"

# 4. a countdown. b00 ends the card: print the running total (tens, then units, then the ISO week
#    from date), stop if it exceeds 40, otherwise deal the next card. Any other bNN digs the next hour.
tens = alt([path(wraps(n)) + " " + ex("printf", q(str(n))) for n in range(5, 0, -1)])
units = alt([path("*/%s/b00" % d) + " " + ex("printf", q("%s," % d)) for d in DIGITS])
week = ex("date", '"+\'%G-W%V\');"')
over_40 = "\\( " + path(wraps(5)) + " -o \\( " + path(wraps(4)) + " " + path("*/[1-9]/b00") + " \\) \\)"
end_of_card = ("\\( -name b00 \\( " + tens + " \\) \\( " + units + " \\) " + week
               + " \\( " + over_40 + " -o \\( " + NEXT_CARD + " \\) \\) \\)")
next_hour = alt([path("*/%s/b??" % d) + " " + ex("mkdir", "{}/" + SUCC[d]) for d in DIGITS])
rule_countdown = end_of_card + " -o \\( -name 'b??' \\( " + next_hour + " \\) \\)"

print("find t \\( " + rule_start + " \\) -o \\( " + rule_dice + " \\) -o \\( " + rule_hour
      + " \\) -o \\( " + rule_countdown + " \\)")
