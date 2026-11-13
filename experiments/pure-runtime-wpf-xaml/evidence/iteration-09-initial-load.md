# Iteration 9: Deferring a provider

## Hypothesis
IsInitialLoadEnabled=False arms a provider to run later by Refresh.

## Grade and allowed types/packages
P

## Smallest probe
see iteration-log.md

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
Provider with the flag still executed at parse once MethodName was set (attribute order irrelevant; IsAsynchronous also ran once). A first thread-over-Refresh design double-inserted rows and was discarded. Probe code was inline in the session (scratch dirs); result recorded in iteration-log.md.

## Evidence paths and hashes
- (none)

## Classification: pass | partial | blocked | invalid-by-constraint
blocked

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
No arm-now/fire-later mechanism found; document order used instead.

## Next action or stop reason
Integrate.
