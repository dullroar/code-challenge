---
title: "Declarative programming"
chapter: 5
order: 60
---
Declarative programming says *what* you want, not *how* to get it. SQL, HTML, CSS, Make, regular expressions and AWK's pattern column are all declarative. It exists because a tool that knows the goal can choose the method: a database picks the query plan, and `make` picks the build order. The trap is the belief that "declarative" means "harmless". When a declarative notation can name a function and give it arguments, it is one step from being a program. XAML's `ObjectDataProvider` and Make's `include` are examples, and [[entry:xaml]] and [[entry:make-gnu]] show where that step leads.

- **Use it when:** the task is a query, a configuration or a build. Let the tool optimize.
- **Avoid:** assuming a declarative file is safe to load from anyone. Check what it is allowed to call.

**Read more:**

- [Declarative programming](https://en.wikipedia.org/wiki/Declarative_programming) (Wikipedia)
- [Rule of least power](https://en.wikipedia.org/wiki/Rule_of_least_power) (Wikipedia)
