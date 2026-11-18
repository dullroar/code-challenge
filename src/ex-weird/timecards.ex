" The whole program, as Ex commands. Ex reads it on standard input; the buffer holds five dice, one digit per line.
" Run:  printf '7\n3\n9\n0\n5\n' > dice.txt; ex -s dice.txt < timecards.ex      (nvi; for Vim: ex -s -u NONE)
" There is no global command, no regular-expression test and no loop statement in this file.
"
" 1. Categories are ADDRESSES, as in the ed entry. Several commands can share a line, separated by a bar.
1s/^/Meetings /|2s/^/Coding /|3s/^/Debugging /|4s/^/Learning /|5s/^/Meetings /
"
" 2. The TAPE: sixty lines under the cards. Each line is  "total instruction".  A line's position is a number, and
"    a MARK is a register: mark t says where we are on the tape. Up to a total of 40 the instruction is "@a" (go on).
"    Above 40 it is a quote mark, which Ex reads as a comment (do nothing). The limit of 40 is where @a ends.
5a
0 @a
1 @a
2 @a
3 @a
4 @a
5 @a
6 @a
7 @a
8 @a
9 @a
10 @a
11 @a
12 @a
13 @a
14 @a
15 @a
16 @a
17 @a
18 @a
19 @a
20 @a
21 @a
22 @a
23 @a
24 @a
25 @a
26 @a
27 @a
28 @a
29 @a
30 @a
31 @a
32 @a
33 @a
34 @a
35 @a
36 @a
37 @a
38 @a
39 @a
40 @a
41 "
42 "
43 "
44 "
45 "
46 "
47 "
48 "
49 "
50 "
51 "
52 "
53 "
54 "
55 "
56 "
57 "
58 "
59 "
.
/^0 /k t
"
" 3. The PROGRAM is the line after the next "a" command. It is text. It is added to the buffer, copied into register a,
"    and removed again. Register a is what "@a" runs. Read the bars as line breaks; each step is explained here:
"      1t$                          copy the first card ("Meetings 7") to the end of the buffer
"      $s/^.* \([0-9]\)$/'t+1\1k t/   rewrite that copy into a COMMAND:  'tmark plus 17 lines, stored as the mark t
"      $ya d  and  $d                copy the command into register d, and remove it from the buffer
"      1s/ \([0-9]\)$/ 1\1/          turn the card's digit into hours:  "Meetings 17"
"      @d                           run register d: the mark t moves 17 lines down the tape. THAT IS THE ADDITION
"      1t$ , 'tt$ , $s/ .*$// , $-1,$j , $p
"                                   copy the card, copy the tape line under mark t, keep only its total,
"                                   join them into "Meetings 17 17", and print it
"      'tt$ , $s/^[0-9]* // , $ya n , $d
"                                   copy the tape line again, keep only its instruction, copy it into register n
"      1d                           the card is used up
"      @n                           run register n: "@a" runs the program again, a comment ends it. THAT IS THE LOOP
$k s
$a
1t$|$s/^.* \([0-9]\)$/'t+1\1k t/|$ya d|$d|1s/ \([0-9]\)$/ 1\1/|@d|1t$|'tt$|$s/ .*$//|$-1,$j|$p|'tt$|$s/^[0-9]* //|$ya n|$d|1d|@n
.
's+1ya a
's+1d
"
" 4. Start it.
@a
q!
