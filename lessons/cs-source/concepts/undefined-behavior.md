---
title: "Undefined, unspecified and implementation-defined behavior"
chapter: 8
order: 20
---
Standards use three different words for "the standard does not fully say". **Undefined behavior**: anything may happen, including a crash or a security hole. **Unspecified behavior**: one of several allowed outcomes, and the implementation need not say which. **Implementation-defined behavior**: the implementation must choose and document it. The words come from C and C++, but the idea applies everywhere. It exists to give compilers freedom to optimize and to run on different hardware. This book's three tags (guaranteed, implementation-permitted, accidentally exploited) are the same idea in friendlier words. Examples: COBOL's `ALTER` is kept by GnuCOBOL but removed from the standard, and the meanings of `⊃` and `↑` differ between GNU APL and Dyalog.

- **Use it when:** you read a standard: find out which kind of "not specified" you are leaning on.
- **Avoid relying on it.** Tools such as AddressSanitizer can catch some undefined behavior in C and C++ at run time.

**Read more:**

- [Undefined behavior](https://en.wikipedia.org/wiki/Undefined_behavior) (Wikipedia)
- [Unspecified behavior](https://en.wikipedia.org/wiki/Unspecified_behavior) (Wikipedia)
- [AddressSanitizer](https://en.wikipedia.org/wiki/AddressSanitizer) (Wikipedia)
