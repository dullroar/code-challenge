CFLAGS ?= -Wall -Wextra -O1
PCRE2  := $(shell pkg-config --cflags --libs libpcre2-8) -lm

timecards: timecards.c
	$(CC) $(CFLAGS) -o $@ $< $(PCRE2)

run: timecards
	./timecards

check: timecards
	./check.sh ./timecards

clean:
	rm -f timecards

.PHONY: run check clean
