# Iteration 16: Mutable carriers for dynamic data

## Hypothesis
Parameters evaluated at call time + by-reference arrays can carry dynamic data between calls.

## Grade and allowed types/packages
S and P (see compositions)

## Smallest probe
probes/H1-carrier-to-sqlite.xaml, probes/H2-carrier-datatable-sum.xaml, probes/F3-ef-odp-ctor.xaml, probes/F4-odp-ctor-semantics.xaml, strict-built-in/program.xaml, package-backed-pure/program.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
H1: seeded draw 16 reached SQLite. H2: four draws -> XML carrier -> DataTable.ReadXml -> Compute('Sum(h)')=53. Strict composition: prefix sums, DataView RowFilter guard, WriteXml on a pool thread, byte-identical XML across runs. Package composition: 16,11,11,15 = 53 h in SQLite. Several sub-probes under one hypothesis (budget stretch disclosed).

## Evidence paths and hashes
- `probes/H1-carrier-to-sqlite.xaml` sha256 `5f03f2cc48557d8d`
- `probes/H2-carrier-datatable-sum.xaml` sha256 `5326184584140c9b`
- `probes/F3-ef-odp-ctor.xaml` sha256 `65ff48ccc2b9c6ae`
- `probes/F4-odp-ctor-semantics.xaml` sha256 `b0bcb01696a11b1a`
- `strict-built-in/program.xaml` sha256 `53e24742e1230f1d`
- `package-backed-pure/program.xaml` sha256 `0961b019749271ed`

## Classification: pass | partial | blocked | invalid-by-constraint
pass

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
XAML: sequence, state (carriers), guard (RowFilter / SQL WHERE). Runtime/BCL: Random, Encoding, DataTable, DataView. Package: SQLite.

## Next action or stop reason
Raw typed values; EF.
