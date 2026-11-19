---
title: "Regex search with side effects and deliberate failure"
order: 60
---
[[entry:regex-perl]], [[entry:regex-pcre2]] and [[entry:regex-pcre2grep]] use one match to drive callbacks or embedded code. The actions build the result outside the matcher. Each pattern eventually forces the match to fail, and completed writes can survive that failure. Perl’s localized variables unwind on backtracking, while PCRE2 callouts keep their state in the C host or in external helpers.
