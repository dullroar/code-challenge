---
title: "A search that fails on purpose"
order: 60
---
The program is a search that fails on purpose. [[entry:regex-perl]], [[entry:regex-pcre2]] and [[entry:regex-pcre2grep]] do all the work as side effects inside one match, and finish with `(*COMMIT)(*FAIL)` so that the match returns false. What survives the failure differs between the engines, and that is the lesson. [[entry:regex-dotnet]] cannot do this, because a failed .NET match discards its captures. It must succeed, and it uses balancing groups as a counter.
