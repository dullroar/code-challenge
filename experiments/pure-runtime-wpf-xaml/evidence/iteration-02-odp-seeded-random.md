# Iteration 2: ObjectDataProvider and seeded Random

## Hypothesis
ODP can construct and call a built-in; a seed is available through x:Arguments.

## Grade and allowed types/packages
S: System.Random, ObjectDataProvider

## Smallest probe
probes/C1-odp-random.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
x:Arguments built Random(42); Next(10,20)=16 at parse time. `{Binding}` on ObjectInstance: XamlParseException (not a DP). `{StaticResource provider}` and `{x:Reference}` as ObjectInstance are unwrapped to the provider Data (MissingMethodException Int32.Refresh).

## Evidence paths and hashes
- `probes/C1-odp-random.xaml` sha256 `9466b6c916cc9794`

## Classification: pass | partial | blocked | invalid-by-constraint
partial

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Construction/invocation: XAML + ODP semantics. Provider-as-receiver for Refresh: blocked (2 mechanisms, closed).

## Next action or stop reason
Retrigger via a smuggled reference.
