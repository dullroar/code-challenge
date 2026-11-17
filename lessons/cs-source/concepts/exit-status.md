---
title: "Exit status"
chapter: 7
order: 40
---
An exit status is the number that a finished process hands back to whoever started it. On Unix, `0` means success and anything else means failure, in the range 0 to 255. It exists so that programs can be glued together: `if`, `&&` and `||` in a shell all read it. It is also a control signal in this repository. In [[entry:regex-pcre2grep]] the exit code of a small program steers the regex match. In [[entry:regex-sed]] the script exits `1` on purpose, and the wrapper maps that back to success. Every `check.sh` exits non-zero on any failure, so the sandbox gate can judge a run without reading it.

- **Use it when:** scripts and tools that other tools call. Document what each code means.
- **Avoid:** using it for rich data (it is one small number), and assuming every platform uses the same range.

**Read more:**

- [Exit status](https://en.wikipedia.org/wiki/Exit_status) (Wikipedia)
