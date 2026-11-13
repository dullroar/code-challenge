# Iteration 3: Re-trigger a call

## Hypothesis
A provider can invoke Refresh on another provider if hidden inside a collection.

## Grade and allowed types/packages
S: x:Array, ObjectDataProvider, DataSourceProvider.Refresh

## Smallest probe
probes/C2-refresh-retrigger.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
provider stored in x:Array, fetched by GetValue(0), Refresh invoked: Next advanced 16 -> 11.

## Evidence paths and hashes
- `probes/C2-refresh-retrigger.xaml` sha256 `dbe9b4f44569dc7e`

## Classification: pass | partial | blocked | invalid-by-constraint
pass

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
XAML wires the retrigger; ODP/DataSourceProvider runtime semantics execute it.

## Next action or stop reason
Probe dynamic parameters.
