# Come Make Something Beautifully Wrong

**One Statement, Two Semicolons** is an obfuscated-algorithms challenge: take a small, ordinary program, impose an absurd syntactic rule, and make it work anyway. Not merely compile. Work.

What started in C# has escaped into Rust, runtime XAML, Java, Kotlin, Python, Go, and four varieties of executable regex: Perl inline-code regex, PCRE2 callout regex, stock `pcre2grep` callouts, and .NET balancing groups. Bring a language, a constraint, or a feature being used for something its designer would politely discourage.

## The shared challenge

In your language's own flavor of bad judgment:

- generate fictional time-card entries of 10–19 hours for Meetings, Coding, Debugging, or Learning;
- keep adding them until the running total exceeds 40;
- keep all output local, clearly labeled **DEMO ONLY**, and completely separate from real time reporting; and
- display the result through a window, browser, terminal, or whatever else makes sense.

The mechanism is yours. The `for` family uses a bodiless loop. Rust twists iterators and closures into shape. XAML turns parsing into execution. The regex entries make matching, backtracking, callouts, or capture stacks do the heavy lifting. Preserve the behavior, then find the most gloriously inappropriate way your language allows you to express it.

## Do / don't

**Do** let side effects carry real weight when the language permits it. Lean on reflection, interpretation, metaprogramming, parsing, execution machinery, or other native weirdness rather than mere syntax. A tiny host that seeds data, launches one operation, or reports a result is fair game; the interesting work should visibly belong to the stunt.

**Don't** hide a normal solution behind one clever expression that calls `RunEverything()` (or the local equivalent). Moving the loops, conditionals, and orchestration into another method, script, or file is not a port; it's a costume change. And this is not a production pattern: no real data, no networked systems, and no pretending unreadability is a virtue outside the game.

## Extra credit

- Leave `main` nearly empty, or make it the launcher for an even worse idea.
- Put control flow somewhere it doesn't belong: a parser, iterator, regex engine, markup document, type system, or build tool.
- Make backtracking do all the work, then deliberately return “no match.”
- Build or animate a UI at runtime without conventional event-handler plumbing.
- Add a test that proves the ridiculous constraint is actually real.
- If the language hits a genuine wall, document it precisely. A well-demonstrated limitation is more interesting than cheating around it.

Make it work. Make it weird.

And whatever you do, don't tell the boss.
