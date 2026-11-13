# Iteration 19: EF Core composition (follow-up J1)

## Hypothesis
With an instantiable existing model/context, EF Add/SaveChanges can be driven from XAML with seeded values.

## Grade and allowed types/packages
P: EF Core 10.0.14; existing types DemoTimeCard/DemoTimeCardContext (owner-approved copy: internal->public, DB folder)

## Smallest probe
package-backed-ef/program.xaml, package-backed-ef/model/DemoTimeCard.cs, package-backed-ef/model/DemoTimeCardContext.cs

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
4 cards 16/11/11/15 = 53 h, year 2026 week 46, via TimeCards.Add x4 and SaveChanges; SQL trigger guard live (threshold 30 keeps 3). Runs identical on net10 and net11. Baseline LOCALAPPDATA untouched.

## Evidence paths and hashes
- `package-backed-ef/program.xaml` sha256 `1a336745382d083b`
- `package-backed-ef/model/DemoTimeCard.cs` sha256 `d6b6e3b21e165fd6`
- `package-backed-ef/model/DemoTimeCardContext.cs` sha256 `a026ee6605507ef6`

## Classification: pass | partial | blocked | invalid-by-constraint
pass

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
XAML: orchestration, state, guard text. Package: EF Core/SQLite. Existing types: entity + context only.

## Next action or stop reason
Final report.
