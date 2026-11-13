# Iteration 13: Animation-driven CLR write

## Hypothesis
An animated Tag with a OneWayToSource binding writes ObjectDataProvider.MethodName.

## Grade and allowed types/packages
S

## Smallest probe
probes/D2-trigger-effect.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
Tag became 'Clear' but the binding did not push the animated value; only the initial null push occurred.

## Evidence paths and hashes
- `probes/D2-trigger-effect.xaml` sha256 `91899314fb9e5e0d`

## Classification: pass | partial | blocked | invalid-by-constraint
blocked

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Conditional effect selection not available via this mechanism.

## Next action or stop reason
Try trigger-setter binding.
