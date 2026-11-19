---
title: "Document order is the program"
order: 90
---
The order of the document is the order of the program. [[entry:xaml]] has no code behind it. The XAML parser builds objects in the order it reads them, and several of those objects call methods as they are made. Four unrolled passes replace the loop, "carrier" arrays are the variables and SQL or `DataTable` expressions make the decisions. The program is the markup file, and it runs while the file is parsed. [[entry:tar-gnu]] is the same idea with a tape instead of a markup file: the members of a tar archive are the instructions, and the order of the archive is the order of the program.
