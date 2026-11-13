/* DEMO ONLY. Fictional timecards, written to a scratch file under XDG_DATA_HOME. See README.md.
 *
 * The host has no for/while/goto/recursion. It compiles one pattern, registers one callout
 * dispatcher, calls pcre2_match once, and reports. Walking the entries, drawing hours, deciding
 * to stop, and committing are all callout opcodes in the pattern; PCRE2 supplies the iteration. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>

typedef struct { FILE *out; long start; int total, entries, committed; const char *path; } Demo;

/* A callout's negative return becomes pcre2_match's return value, and -1 is PCRE2_ERROR_NOMATCH,
 * so failures must use something else or a broken run would masquerade as the expected outcome. */
#define FAILED PCRE2_ERROR_CALLOUT

static const char SUBJECT[] = "MeetingsCodingDebuggingLearning";
static const char PATTERN[] =
    "^(?C\"init\")(?:(?C\"gate\")(Meetings|Coding|Debugging|Learning)(?C\"book\"))*"
    "(*COMMIT)(?C\"commit\")(*FAIL)";

static int op_init(Demo *d) {
    return (d->out = fopen(d->path, "a")) == NULL ? (perror(d->path), FAILED)
         : (setvbuf(d->out, NULL, _IONBF, 0), d->start = ftell(d->out),
            fprintf(d->out, "# DEMO ONLY %ld\n", (long)time(NULL)), 0);
}

static int op_book(Demo *d, const pcre2_callout_block *b) {
    int hours = 10 + rand() % 10;
    d->total += hours;
    d->entries += 1;
    return fprintf(d->out, "%.*s\t%d\t%d\tDEMO ONLY\n", (int)(b->offset_vector[3] - b->offset_vector[2]),
                   (const char *)b->subject + b->offset_vector[2], hours, d->total) < 0 ? FAILED : 0;
}

static int op_commit(Demo *d) {
    return fprintf(d->out, "# committed total=%d entries=%d DEMO ONLY\n", d->total, d->entries) < 0
           || fclose(d->out) != 0 ? FAILED : (d->committed = 1, 0);
}

/* Callout return values: 0 = carry on, positive = fail this branch (backtrack), negative = abort. */
static int dispatch(pcre2_callout_block *b, void *p) {
    Demo *d = p;
    const char *s = (const char *)b->callout_string;
    size_t n = b->callout_string_length;
#define IS(name) (n == sizeof(name) - 1 && memcmp(s, name, n) == 0)
    return IS("init")   ? op_init(d)
         : IS("gate")   ? d->total > 40
         : IS("book")   ? op_book(d, b)
         : IS("commit") ? op_commit(d)
         : FAILED;
}

int main(void) {
    const char *xdg = getenv("XDG_DATA_HOME"), *home = getenv("HOME");
    char root[512], dir[560], path[640];
    snprintf(root, sizeof root, xdg ? "%s" : "%s/.local/share", xdg ? xdg : home ? home : ".");
    snprintf(dir, sizeof dir, "%s/RegexPCRE2", root);
    snprintf(path, sizeof path, "%s/demo-timecards.tsv", dir);
    (mkdir(root, 0700), mkdir(dir, 0700)); /* EEXIST is fine; open fails loudly if either is truly broken */

    Demo demo = { .path = path };
    srand((unsigned)time(NULL));
    int err; PCRE2_SIZE erroff;
    /* Callouts are only honest if the optimizer cannot skip them, so switch the optimizer off.
     * (No JIT: PCRE2's JIT does not support callouts.) */
    pcre2_code *re = pcre2_compile((PCRE2_SPTR)PATTERN, PCRE2_ZERO_TERMINATED,
                                   PCRE2_NO_AUTO_POSSESS | PCRE2_NO_START_OPTIMIZE | PCRE2_NO_DOTSTAR_ANCHOR,
                                   &err, &erroff, NULL);
    pcre2_match_context *mc = pcre2_match_context_create(NULL);
    pcre2_set_callout(mc, dispatch, &demo);
    pcre2_match_data *md = pcre2_match_data_create_from_pattern(re, NULL);
    int rc = pcre2_match(re, (PCRE2_SPTR)SUBJECT, sizeof SUBJECT - 1, 0, 0, md, mc);

    char report[4096] = "";
    FILE *in = fopen(path, "r");
    (in && fseek(in, demo.start, SEEK_SET) == 0) ? fread(report, 1, sizeof report - 1, in) : 0;
    int ok = rc == PCRE2_ERROR_NOMATCH && demo.committed;
    printf("pcre2_match returned %d (%s)\nrecords at %s (latest run below)\n%s", rc,
           ok ? "no match" : "FAILED: the run did not complete and commit", path, report);
    return ok ? 0 : 1;
}
