# Iteration 14: Trigger-setter CLR write

## Hypothesis
A DataTrigger setter with an OWTS binding pushes a default value.

## Grade and allowed types/packages
S

## Smallest probe
probes/D3-trigger-binding-effect.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
binding pushed its own empty value, not the style default.

## Evidence paths and hashes
- `probes/D3-trigger-binding-effect.xaml` sha256 `ed53b4522208fa53`

## Classification: pass | partial | blocked | invalid-by-constraint
blocked

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Second mechanism failed: conditional effect selection by triggers closed.

## Next action or stop reason
EF probe.
