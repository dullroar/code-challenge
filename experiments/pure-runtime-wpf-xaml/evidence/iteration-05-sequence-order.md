# Iteration 5: Execution order and determinism

## Hypothesis
Providers execute in document order and the seeded sequence is reproducible.

## Grade and allowed types/packages
S

## Smallest probe
probes/C4-sequence-order.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
five providers on one Random(42): 16,11,11,15,11 on every run; execution at parse (EndInit) in document order; dictionary enumeration order varies per process but is irrelevant.

## Evidence paths and hashes
- `probes/C4-sequence-order.xaml` sha256 `6bfe9409632b0d08`

## Classification: pass | partial | blocked | invalid-by-constraint
pass

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Document order = program order (WPF parser semantics); data from Random.

## Next action or stop reason
Arithmetic/comparison primitives.
