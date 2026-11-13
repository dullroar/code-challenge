# Iteration 4: Late-bound method parameters

## Hypothesis
A Binding or a provider can be a MethodParameter.

## Grade and allowed types/packages
S

## Smallest probe
probes/C3-dynamic-params.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
`<Binding>` in MethodParameters: parse error (cannot be used within a ParameterCollection). StaticResource of a provider passes the provider object (ArrayList held an ODP).

## Evidence paths and hashes
- `probes/C3-dynamic-params.xaml` sha256 `43dc25d0b05b0462`

## Classification: pass | partial | blocked | invalid-by-constraint
blocked

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Missing primitive at this point: late-bound scalar arguments. Resolved later by carriers (iteration 16).

## Next action or stop reason
Probe ordering and arithmetic.
