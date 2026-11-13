# Regex Challenge: One Match, Zero Mercy

**Status:** All three tracks implemented (`src/regex-perl`, `src/regex-pcre2`, `src/regex-dotnet`), plus a `pcre2grep` variant of Track 2 (`src/regex-pcre2grep`) that needs no custom host code. Track 3 got further than this plan predicted but did hit the expected walls; see its README. The plan below is unchanged from when it was written.
**Baseline:** the timecard demo shared by every entry in this repo (see root `README.md`). This plan does not change the baseline.
**Nature:** a gleeful dare, not a production spec. If a rule here is making the result *less* ridiculous, the rule is wrong.
**Where it runs:** WSL/Linux. No WPF this time — Perl and PCRE2 are native there, and `dotnet` is cross-platform, so nothing here depends on Windows.

## Play charter

Somebody asked ChatGPT an orthogonal question about this repo — "has anyone made a regex engine run a program?" — and ChatGPT, bless it, said yes, and then helpfully explained three ways to do it. This plan is that answer, aimed back at the timecard demo.

The usual programmer joke is "now you have two problems." The goal of this entry is to make that joke literally true: the regex should not just *validate* the timecard data, it should **be** the program — the loop, the accumulator, the stop condition, and ideally the thing that commits its own side effects and then lies about whether it succeeded.

Best practices are not merely optional here, they are the enemy. A clean, readable, well-factored regex is a failed attempt. The target artifact is a single regex literal that a reasonable person looks at, recoils from, and closes the laptop.

## The rule (same spirit as "one statement," translated)

- **One top-level regex match/exec call** per track, invoked once from host code.
- The host program may: build/seed the initial data, register whatever callback vocabulary the engine demands, fire that single match, and print/report the final state. It may not contain a `for`, `while`, `foreach`, or recursion standing in for one.
- All control flow that matters — walking through timecard entries, accumulating hours, deciding when 40 is exceeded, picking the next category — must be expressed through the regex engine's own machinery: backtracking, quantifiers, recursion, conditionals, capture/backreference state, or callouts. If the "regex" is secretly just an excuse to call `RunEverything()` once, that's not a pass, it's a confession.
- Demo semantics carry over unchanged: four categories (Meetings, Coding, Debugging, Learning), each entry a random 10–19 hours, stop once the running total exceeds 40, every record clearly marked as demo data, no real persistence target, no network, nothing that could be mistaken for an actual time-reporting system.
- Persistence is whatever's convenient per track (stdout, a flat file, sqlite) as long as it's obviously a toy and isolated to a scratch path.
- The pulsing "DEMO ONLY" WPF window has no Linux equivalent on offer here, and that's fine — an optional ANSI pulse/blink in the terminal is a cute bonus, not a requirement. The regex stunt is the point; the window was always garnish.

## Tracks, in the order I'd actually attempt them

ChatGPT's own proposed order is correct and is kept as-is: prove the concept where it's easiest (Perl), then push further where the tooling is more interesting but gnarlier (PCRE2 callouts), then see how far the no-callout, no-escape-hatch version goes (.NET balancing groups). **Doing all three is not required.** One excellent track beats three mediocre ones; the second and third tracks are explicitly allowed to end in "here's exactly why this one can't quite get there," and that's a fine outcome — the original XAML plan calls a well-evidenced dead end a "negative result," not a failure, and the same attitude applies here.

### Track 1 — Perl: executable regex, the direct route

Perl regexes can run real Perl inside the pattern via `(?{ ... })` (code that runs for its side effect when that point in the match is reached) and `(??{ ... })` (a dynamically generated subpattern — code that returns a *pattern*, spliced into the match on the fly). Combined with recursion and quantifiers, this is close to a genuine, if deranged, execution engine disguised as a pattern.

Shape of the attempt: a single `=~` match against a scaffold string (its literal content barely matters — it exists to give the engine something to walk across and backtrack through) where:
- the match initializer seeds totals/category state via `(?{ ... })` at the start,
- a repeated group advances the category, draws a random 10–19, adds it to a running total, and writes a timecard record, all via `(?{ ... })` blocks chained through quantifiers/alternation,
- a `(??{ ... })` block supplies the *next* subpattern to attempt based on current state — e.g., "keep offering more entries" vs. "stop," computed dynamically rather than written out as a fixed loop,
- the match is allowed, even encouraged, to ultimately fail — see "the signature move" below.

This is the track most likely to fully succeed, and should be attempted first to prove the whole family is viable before sinking time into PCRE2/.NET.

### Track 2 — PCRE2: callouts as a tiny DSL

PCRE2 supports `(?C1)`, `(?C2)`, or named `(?C"instruction")` callouts: markers in the pattern that invoke an application-registered callback (`pcre2_set_callout()`) during matching, with the power to tell the engine to continue, fail the current branch, or (with some versions/settings) influence backtracking. That makes the pattern a literal **control-flow graph** where the callout strings are opcodes interpreted by a tiny host-side dispatcher, and PCRE2 supplies the iteration/branching/backtracking around them.

```text
(?C"init")
(?:
    (?C"next-entry")
    .
)*
(?C"finalize")
```

Needs a thin PCRE2 binding: Python's `pcre2`/`ctypes`, Perl's own PCRE2 bindings, or a tiny C shim — whichever is least fuss on WSL. Caveat to respect (ChatGPT flagged it correctly): PCRE2's optimizer can skip callouts it decides are unreachable/unnecessary for the match result, so if callouts are standing in for statements, matching has to be run with optimizations that preserve callout visitation (e.g. disabling auto-possessification/start-optimization where the binding allows it), and that choice needs to be called out explicitly in whatever write-up follows this plan — don't let a "working" demo secretly be one where half the callouts silently never ran.

The reward here is the closest match to the original ask: an honest custom domain language, written as callout strings, executed by backtracking.

### Track 3 — .NET balancing groups: the purist's dead end (maybe)

No callouts, no inline code — just `(?<name>...)`, `(?<-name>...)` balancing groups as a capture stack, lookarounds, backreferences, and conditional `(?(name)yes|no)` expressions. This is the "purer" variant because nothing escapes the regex syntax itself; it's also the one most likely to top out well short of the full demo, because there's no way to do arithmetic like "accumulate hours until > 40" without some substitute for counting — unary/tally encoding (matching `a` repeated for each hour, balancing-group style) is the classic trick and should be tried, but 10–19-per-entry random draws accumulating toward 40 in unary is exactly the kind of thing worth timeboxing.

Treat this track as explicitly optional and expect a documented "here's the wall we hit" outcome rather than a full implementation. If `Regex.Replace`'s `MatchEvaluator` ends up doing anything beyond reading out a final captured state, that's cheating — it runs per completed match, not mid-process, and smuggling control flow through it would defeat the point of this track.

## The signature move (attempt in at least one track)

The best idea in Chat's reply, and the one worth protecting above all else: have the engine's backtracking perform the real side effects (writing timecard entries) in a branch that later gets abandoned, then let the **top-level match deliberately return false** having already done all the useful work. A regex that finishes the whole program and then reports "no match." That single behavior is the entry's reason for existing; everything else is scaffolding to make it possible. If time runs short, protect this over completeness in any given track.

## Proposed file layout (not created by this plan — for whichever track(s) get built later)

```text
src/
  regex-perl/        # Track 1 — perl script(s), minimal README on the trick used
  regex-pcre2/        # Track 2 — host language + PCRE2 binding, callout dispatcher, README
  regex-dotnet/        # Track 3, if attempted — dotnet console app, README on where it tops out
```

Naming/structure follows the existing convention (`src/RustChallenge1` has its own README explaining its gimmick; do likewise per track). Exact folder names can be adjusted when a track actually gets built.

## Non-goals / guardrails

- No network access, no real persistence target, no credentials — same as every other entry.
- Callouts/executable-regex blocks may shell out only to do demo-scoped file/sqlite writes under a scratch path — never anything destructive, never a generic "eval arbitrary shell" backdoor dressed up as a callout.
- Don't reach for a host-language loop "just to glue things together" and call the regex decorative. If the control flow isn't legible from the pattern/callback vocabulary, the attempt doesn't count, however clever the surrounding code is.
- Don't polish this into tasteful, readable regex. Ugly and incomprehensible is the acceptance criterion, not a side effect to tolerate.

## Attribution

Premise and the three-track structure (Perl executable regex / PCRE2 callouts / .NET balancing groups), the "signature move," and the "transaction engine without rollback" framing all originate from a ChatGPT (GPT-5.1, desktop app) reply to a question Jim posed about this repo on 2026-11-13; reproduced and adapted here with light edits.
