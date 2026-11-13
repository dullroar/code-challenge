# Iteration 10: First strict composition

## Hypothesis
Compose passed strict capabilities.

## Grade and allowed types/packages
S

## Smallest probe
strict-built-in/program.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
Superseded by iteration 16 (v2). v1 had hand-copied constants and wrong window bindings (Path=Data).

## Evidence paths and hashes
- `strict-built-in/program.xaml` sha256 `53e24742e1230f1d`

## Classification: pass | partial | blocked | invalid-by-constraint
partial

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Superseded.

## Next action or stop reason
Fix bindings (iteration 12).
