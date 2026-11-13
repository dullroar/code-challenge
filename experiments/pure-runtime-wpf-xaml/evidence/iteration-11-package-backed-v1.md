# Iteration 11: First package-backed composition

## Hypothesis
SQLite persistence in document order with SQL guard.

## Grade and allowed types/packages
P

## Smallest probe
package-backed-pure/program.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
Superseded by iteration 16 (v2): v1 used an SQL formula instead of the seeded Random.

## Evidence paths and hashes
- `package-backed-pure/program.xaml` sha256 `0961b019749271ed`

## Classification: pass | partial | blocked | invalid-by-constraint
partial

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Superseded.

## Next action or stop reason
Seeded values into the DB.
