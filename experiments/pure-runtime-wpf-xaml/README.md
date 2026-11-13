# Pure runtime-WPF-XAML experiment

Bounded research experiment per `plans/pure-xaml.md`. Start with `evidence/final-report.md` (16 of 16 iterations used).

- `strict-built-in/program.xaml` — built-in types only.
- `package-backed-pure/program.xaml` — adds Microsoft.Data.Sqlite (unmodified, from the baseline's EF Core Sqlite package).
- `package-backed-ef/` - EF Core variant: `program.xaml` plus `model/` (owner-approved copy of the baseline model types).
- `constrained/` — not built.
- `tools/` - authoring aids that expand repetitive provider pipelines into plain XAML (not part of any graded source).
- `probes/` — one XAML file per probe, plus `host/`, a generic loader (no demo logic).
- `run.ps1` — build host and run a program in an isolated `artifacts/run-<id>/`.
- `evidence/` — baseline, toolchain, capability matrix, iteration log, constraint audit, hashes, final report.
