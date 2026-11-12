# Iteration 0 – baseline characterization

- Baseline commit at start: `8c14a8e369d16dddb9aa8c54ae22971b4d713971` (branch `experiment/pure-runtime-wpf-xaml`; the plan commit sits on top of the original code).
- OS: Windows 11 Pro 10.0.26300, x64. SDK: 10.0.404 (only SDK). Runtime: Microsoft.NETCore.App / WindowsDesktop.App 10.0.15.
- Project: `src/ModernChallenge1`, WinExe, `net10.0-windows`, UseWPF, one package: Microsoft.EntityFrameworkCore.Sqlite 10.0.14.
- Build: `dotnet build -c Release -o experiments/pure-runtime-wpf-xaml/artifacts/baseline-build` → Build succeeded, 0 warnings, 0 errors.
- Source inspection confirms: one empty-body `for`; `XamlReader.Load` of a Viewbox with EventTrigger/BeginStoryboard DoubleAnimation; `Random.Shared` 10..19; ≤40 h threshold; EF Core/SQLite; named Mutex; background Thread with reflection calls.
- DB location (by source): `%LOCALAPPDATA%\ModernChallenge1\demo-timecards.db`, hard-coded, no override.
- **The baseline was NOT executed.** Running it would write to the real LocalAppData path, which the plan forbids. Its behaviors are source-observed, not run-verified. Baseline project files are untouched (`git status` shows only `experiments/`).
