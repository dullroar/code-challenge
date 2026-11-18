---
title: "Text that is rewritten and read again"
order: 40
---
The program is text, and repetition is rewriting it. [[entry:regex-sed]] keeps one line of text and applies substitutions until none match. [[entry:m4]] defines a macro whose replacement text contains the macro itself, so the output is scanned again, and again. [[entry:make-gnu]] remakes a makefile that it includes, and then *starts over* with the new one. In all three the repeated thing is a read of rewritten input, and the state is whatever the text (or the set of files) says now. [[entry:ed-weird]] rewrites lines with guarded substitutions, and joins lines so that marks are added side by side. It has no `sed`-style branch: its only repeat is one global command.
