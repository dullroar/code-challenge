# Code Challenge

A series of responses to a code challenge that has morphed into a set of educational exercises about programming languages and how to think about programming languages.

## Why this exists

The first version was a [2008 classroom exercise](/docs/My%20Code%20Challenge.pdf), built to put new C# 3.0 and .NET 3.x features on display. Keeping the one-statement rule and porting it to new languages turned out to be a great way to learn what those languages actually let you do, once you push past the part the tutorials cover. Each entry answers the same question in its own accent: *how far can this language's own machinery - its iterators, its regex engine, its markup parser, its build tool - be pushed before it starts acting like a general-purpose program?*

It is a joke with a serious job inside it. Underneath every entry is a real lesson in a real language construct - LINQ, XAML, GNU Make, regular expressions, iterators, callouts - taught by pushing that construct until it does something its own documentation would not think to show you. That is why every folder's README has a **How the stunt works** section: read it, and you have learned the construct, not just watched a trick. The entertainment gets you in the door; the "oh, THAT'S how that actually works" is what you leave with.

The deeper point, the one worth keeping after the jokes wear off: **THERE ARE NO BLOCKERS, JUST NOT ENOUGH IMAGINATION.**

It has turned into a small, friendly contagion. [**Ken caught it too.**](https://github.com/kastl/one-statement-challenge) What started as one C# program is now **sixteen** programs in **ten** languages, written by more than one person, and still growing.

## Psst, hey kid

**Try this at home!** **Don't tell the boss!**

You've spent years writing clean code: small functions, meaningful names, tests. *Boring.* Over here, there's a `for` loop with an empty body that opens a database, starts a thread, draws a window, and fades it in and out - all before the first semicolon is done being weird.

You know you want to write beautifully wrong code. **You know you do.**

## Ready to play?

The rules, the shared demo, and the do's and don'ts live in **[`CHALLENGE.md`](CHALLENGE.md)**. Pick a language. Pick a constraint. Make something terrible that works.

## The results so far

Every entry builds the same small demo: make up some *Meetings / Coding / Debugging / Learning* time-card hours, save them to a local **DEMO ONLY** SQLite file, stop once the total passes 40, and show the result. Nothing here touches a real time-reporting system - see the [disclaimer](#disclaimer).

**ALL OF THESE ARE TESTED AND WORK AS ADVERTISED.** Remember that while reading the code.

## Disclaimer

**DEMO ONLY.** Every record any of these programs writes is flagged as demo data in a throwaway local file/SQLite database. None of it connects to, or should ever be used for, a real time-reporting system. And please do **not** try any of this at work. Waste your own tokens. :)

| Version | By | The stunt | Teaches you | Folder |
| --- | --- | --- | --- | --- |
| **C# (the original)** | Jim | Empty-body `for`; everything else lives in its three clauses | Runtime XAML, LINQ, EF Core, WPF animation | [`src/ModernChallenge1`](src/ModernChallenge1/README.md) |
| **Rust** | Jim | No `;`, `let`, or `return` in `main` - a test enforces it | Iterators and closures as control flow | [`src/RustChallenge1`](src/RustChallenge1/README.md) |
| **XAML** | Jim | The program *is* a `.xaml` file, run by the parser that loads it | XAML as a runtime interpreter, not just markup | [`src/xaml`](src/xaml/README.md) |
| **Perl regex** | Jim | One `=~` match does everything, then deliberately returns false | Executable code inside a live regex match | [`src/regex-perl`](src/regex-perl/README.md) |
| **PCRE2 regex** | Jim | Callout strings become opcodes for a bodiless C dispatcher | Regex callouts as a tiny instruction set | [`src/regex-pcre2`](src/regex-pcre2/README.md) |
| **pcre2grep regex** | Jim | No custom code at all: a stock `pcre2grep`, one command line | Program exit codes as control flow | [`src/regex-pcre2grep`](src/regex-pcre2grep/README.md) |
| **.NET regex** | Jim | Balancing groups only - no callouts, no code in the pattern | A regex as a stack-based counter | [`src/regex-dotnet`](src/regex-dotnet/README.md) |
| **LINQ, fluent chain** | Jim | One LINQ method chain is the entire program | LINQ method chains, end to end | [`src/LinqChallenge1`](src/LinqChallenge1/README.md) |
| **LINQ, query expression** | Jim | Nearly every line is `from`/`where`/`let`/`select` | C# query syntax, pushed as far as it goes | [`src/LinqChallenge2`](src/LinqChallenge2/README.md) |
| **GNU Make** | Jim | No `$(shell)`; Make re-executes itself as the loop | Arithmetic and looping in plain Make syntax | [`src/make-gnu`](src/make-gnu/README.md) |
| **CMake** | Jim | One bodiless `while()`; its condition is a regex machine | `while()` + regex as a tiny register machine | [`src/cmake`](src/cmake/README.md) |
| **GNU sed regex** | Ken | The program is one line of text, rewritten until it's done | sed substitutions as a Markov algorithm | [`src/regex-sed`](src/regex-sed/README.md) |
| **Java** | Ken | One bodiless `for`; an anonymous class holds the loop state | The same bodiless-loop trick, Java style | [Ken's repo](https://github.com/kastl/one-statement-challenge) |
| **Kotlin** | Ken | The same challenge, built as a sequence | The same trick, with Kotlin's sequence builders | [Ken's repo](https://github.com/kastl/one-statement-challenge) |
| **Python** | Ken | The same challenge, Python style | The same trick, in a language with no `;` loops | [Ken's repo](https://github.com/kastl/one-statement-challenge) |
| **Go** | Ken | The same challenge, serving a pulsing page in your browser | The same trick, as a one-request web server | [Ken's repo](https://github.com/kastl/one-statement-challenge) |

Every "Teaches you" cell above is a promise, not just a label: open the folder's README and that is genuinely what you will walk away understanding.

## Repository layout

```text
CHALLENGE.md                  # the rules - start here if you want to play
docs/
  My Code Challenge.pdf       # anonymized source presentation
  images/                     # screenshots used in the subfolder READMEs
src/
  ModernChallenge1/           # C#: the original, modernized for .NET 10
  RustChallenge1/             # Rust + GTK 4 companion for WSL
  xaml/                       # XAML: the program is a .xaml file, run at run time
  regex-perl/                 # Perl: one executable-regex match is the program
  regex-pcre2/                # PCRE2: callout strings as opcodes, a C dispatcher
  regex-pcre2grep/            # pcre2grep: callouts run sqlite3, exit codes steer the match
  regex-dotnet/               # .NET: balancing groups only, and the walls it hits
  regex-sed/                  # GNU sed (Ken): the program is one line of text, rewritten by substitutions
  LinqChallenge1/             # LINQ: one fluent method-chain expression statement
  LinqChallenge2/             # LINQ: one SQL-like query-expression statement
  make-gnu/                   # GNU Make: no $(shell); Make re-executes itself as the loop
  cmake/                      # CMake: one bodiless while(), a regex machine in its condition
LICENSE
```

Ken's Java, Kotlin, Python, and Go versions live in [his repository](https://github.com/kastl/one-statement-challenge).
