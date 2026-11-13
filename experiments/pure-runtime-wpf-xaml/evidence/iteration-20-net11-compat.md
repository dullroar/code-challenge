# Iteration 20: .NET 11 compatibility

## Hypothesis
Baseline and compositions run on net11.0-windows with SDK 11.0.100.

## Grade and allowed types/packages
S/P/EF

## Smallest probe
evidence/runs/net11-a-strict/trace.txt, evidence/runs/net11-a-pkg/db-dump.txt, evidence/runs/net11-a-ef/db-dump.txt, tools/collect_evidence.sh

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
Unmodified baseline copy retargeted to net11.0-windows built; EF Core 10.0.14 packages restored and worked. Host + model rebuilt for net11. All three compositions and probes B1, C4, D1, H2, H3 gave identical results to net10: Random(42) sequence 16,11,11,15,11; total 53; strict XML sha256 94ac35b9...; identical DB rows; animation active (g.Opacity ~0.655 at 700 ms).

## Evidence paths and hashes
- `evidence/runs/net11-a-strict/trace.txt` sha256 `d4c7025ed03c4d2c`
- `evidence/runs/net11-a-pkg/db-dump.txt` sha256 `0c8d21a129e87752`
- `evidence/runs/net11-a-ef/db-dump.txt` sha256 `baca08b1c655a13f`
- `tools/collect_evidence.sh` sha256 `abe51c10bae347a4`

## Classification: pass | partial | blocked | invalid-by-constraint
pass

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Platform compatibility only; no semantic change observed.

## Next action or stop reason
Status: compatible (EF Core 10.0.14 on net11 not an officially matched pairing; observed working).
