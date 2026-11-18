---
title: "Reproducibility and deterministic builds"
chapter: 8
order: 80
---
A result is **reproducible** if the same inputs give the same answer, every time and on every machine. A build is **deterministic** if the same sources give the same bytes. Both depend on writing down everything that is an input: the seed, the order of the items, the versions of the tools, the time. What you forget to write down is where the difference comes from.

The book you are reading is built this way: every list is sorted, nothing reads the clock, and the build date is fixed in a metadata file, so the same sources give the same bytes. The entries use the idea in four ways. [[entry:tar-gnu]] writes a tar archive in a fixed format with a fixed order, time and owner, so the same seed makes the same archive, byte for byte, which `cmp` checks. [[entry:tar-gnu-weird]] makes a run a function of a seed and the archive's layout. [[entry:javascript]] and [[entry:javascript-weird]] replay a run with `SEED=42`, because `Math.random` cannot be seeded and a small closure over a number can. Each one says what "the same" means: the bytes, the structure, or the behavior (see [[serialization-deserialization-pickling]]).

- **Use it when:** you must debug, test or audit a result later. Make the inputs explicit, and record the seed.
- **Avoid it when:** you confuse it with determinism of *everything*. A run is reproducible in the ways you named, and not in the ones you did not, such as the date in a week number near New Year.

**Read more:**

- [Reproducible builds](https://en.wikipedia.org/wiki/Reproducible_builds) (Wikipedia)
- [Deterministic algorithm](https://en.wikipedia.org/wiki/Deterministic_algorithm) (Wikipedia)
