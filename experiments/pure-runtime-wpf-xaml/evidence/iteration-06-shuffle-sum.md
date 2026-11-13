# Iteration 6: Arithmetic and generics

## Hypothesis
Built-in static methods give arithmetic and comparison; generic methods are reachable.

## Grade and allowed types/packages
S: System.Linq.Enumerable, Int32

## Smallest probe
probes/E1-shuffle-sum.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
Enumerable.Sum(int[])=60, Int32.CompareTo(40)=1 via receiver unwrapping. Random.Shuffle: MissingMethodException (generic).

## Evidence paths and hashes
- `probes/E1-shuffle-sum.xaml` sha256 `a5b37c61bd9d8b49`

## Classification: pass | partial | blocked | invalid-by-constraint
partial

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Sum/CompareTo executed by BCL; generic methods unreachable through ODP.

## Next action or stop reason
Probe SQLite provenance.
