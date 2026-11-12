# Pure runtime-WPF-XAML experiment

Bounded research experiment per `plans/pure-xaml.md`. Start with `evidence/final-report.md` (15 of 16 iterations used).

- `strict-built-in/program.xaml` — built-in types only.
- `package-backed-pure/program.xaml` — adds Microsoft.Data.Sqlite (unmodified, from the baseline's EF Core Sqlite package).
- `constrained/` — not built.
- `probes/` — one XAML file per probe, plus `host/`, a generic loader (no demo logic).
- `run.ps1` — build host and run a program in an isolated `artifacts/run-<id>/`.
- `evidence/` — baseline, toolchain, capability matrix, iteration log, constraint audit, hashes, final report.
