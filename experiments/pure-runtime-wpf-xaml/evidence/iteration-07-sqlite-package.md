# Iteration 7: SQLite from XAML

## Hypothesis
Microsoft.Data.Sqlite can be driven through x:Arguments and ODP.

## Grade and allowed types/packages
P: Microsoft.Data.Sqlite via Microsoft.EntityFrameworkCore.Sqlite 10.0.14

## Smallest probe
probes/F1-sqlite-package.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
SqliteConnection/SqliteCommand constructed; Open, ExecuteNonQuery run; row (1,'Coding',12.0,1) verified with the sqlite3 CLI / Python. Provenance: NuGet package, not built-in.

## Evidence paths and hashes
- `probes/F1-sqlite-package.xaml` sha256 `a7317501f2088ecf`

## Classification: pass | partial | blocked | invalid-by-constraint
pass

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Orchestration in XAML; SQLite engine is a package effect target.

## Next action or stop reason
Threading.
