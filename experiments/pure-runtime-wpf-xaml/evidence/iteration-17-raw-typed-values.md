# Iteration 17: Carriers to raw typed values (follow-up H3)

## Hypothesis
A raw node declared after the carrier writers sees the filled carrier.

## Grade and allowed types/packages
S

## Smallest probe
probes/H3-carrier-to-raw-typed.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
String(char[]) + Double.Parse produced a raw System.Double equal to the draw (CompareTo(15.5)=1 for 16).

## Evidence paths and hashes
- `probes/H3-carrier-to-raw-typed.xaml` sha256 `f800f9655cca7921`

## Classification: pass | partial | blocked | invalid-by-constraint
pass

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Document-order construction semantics; BCL parsing.

## Next action or stop reason
EF composition.
