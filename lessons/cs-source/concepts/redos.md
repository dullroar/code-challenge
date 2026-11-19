---
title: "Regular-expression denial of service"
chapter: 8
order: 70
---
ReDoS (regular-expression denial of service) is an attack that sends an input on which a backtracking regex engine takes exponential, or very long, time. A pattern such as `(a+)+$` is fine on most strings and terrible on a long run of `a` characters followed by `!`. It exists because a backtracking engine tries every way to match before it gives up. Real outages have come from this: a regex in a web firewall rule took down Cloudflare in 2019, and one on whitespace slowed Stack Overflow in 2016. The mitigations are simple: use an engine that matches in linear time (RE2, Rust's `regex`, .NET's `NonBacktracking` option), set a match timeout and limit the input length.

- **Use the knowledge when:** any regex meets data that you do not control.
- **Avoid it when:** an overlapping pattern has nested quantifiers or a user submits an unreviewed pattern.

**Read more:**

- [Regular expression denial of service](https://en.wikipedia.org/wiki/Regular_expression_denial_of_service) (Wikipedia)
- [Algorithmic complexity attack](https://en.wikipedia.org/wiki/Algorithmic_complexity_attack) (Wikipedia)
- [Regular expression Denial of Service: ReDoS](https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS) (OWASP)
