# Iteration 12: Data-dependent branch

## Hypothesis
A DataTrigger can branch on a computed value.

## Grade and allowed types/packages
S: DataTrigger, Sum, CompareTo

## Smallest probe
probes/D1-datatrigger-branch.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
text switched to 'OVER-40: terminal'. Typed Int32 Value required (string '1' never matched); local property beats style trigger setter. Correction: a provider used as Binding Source is unwrapped; `Path=Data` finds nothing (window texts in iterations 10/11 had been blank).

## Evidence paths and hashes
- `probes/D1-datatrigger-branch.xaml` sha256 `fd8f267ae27d434d`

## Classification: pass | partial | blocked | invalid-by-constraint
pass

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Branch declared in XAML; WPF trigger engine evaluates.

## Next action or stop reason
Probe trigger-driven effects.
