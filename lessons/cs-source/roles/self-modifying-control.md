---
title: "Control flow that rewrites itself"
order: 50
---
The program changes where it goes next. [[entry:cobol-weird]] uses `ALTER` to rewire a `GO TO`. [[entry:forth-weird]] moves `>in`, the text interpreter's parse position, backward to run the same words again. [[entry:apl-weird]] reads its own source with `⎕CR`, rewrites it, and defines the new function with `⎕FX`: each step makes its own successor. This is the most dangerous role in the book. It is also the clearest picture of what a program counter really is.
