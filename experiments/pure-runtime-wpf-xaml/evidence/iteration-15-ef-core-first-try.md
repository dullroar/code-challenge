# Iteration 15: EF Core from XAML (no model)

## Hypothesis
DbContext can be constructed from XAML.

## Grade and allowed types/packages
P: Microsoft.EntityFrameworkCore 10.0.14

## Smallest probe
probes/F2-ef-core.xaml, probes/F2-ef-core-ctx-fail.xaml.txt

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
UseSqlite and get_Options worked; new DbContext(options) failed because x:Arguments received the provider. (F3/F4 in iteration 16 showed ODP ConstructorParameters do not unwrap either.)

## Evidence paths and hashes
- `probes/F2-ef-core.xaml` sha256 `f559d1d4717ab1a9`
- `probes/F2-ef-core-ctx-fail.xaml.txt` sha256 `7b4afc58e4e2ef49`

## Classification: pass | partial | blocked | invalid-by-constraint
blocked

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Superseded by the EF composition (follow-up J1).

## Next action or stop reason
Carrier experiment.
