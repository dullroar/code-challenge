# Iteration 8: Background work

## Hypothesis
XAML can build, start and join a Thread and run provider work off the UI thread.

## Grade and allowed types/packages
S: System.Threading.Thread, Delegate.CreateDelegate, ODP IsAsynchronous

## Smallest probe
probes/G1-thread-delegate.xaml, probes/G2-thread-async-odp.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
ThreadStart from x:FactoryMethod CreateDelegate over ArrayList.Clear; Thread(IsBackground) started/joined; thread id 7 vs host 2; count 2->0. IsAsynchronous ODP ran on pool thread 4. A provider-produced delegate in x:Arguments failed (not unwrapped).

## Evidence paths and hashes
- `probes/G1-thread-delegate.xaml` sha256 `d8a8682b92850009`
- `probes/G2-thread-async-odp.xaml` sha256 `24effe666ee2a502`

## Classification: pass | partial | blocked | invalid-by-constraint
pass

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
XAML owns construction and sequencing; BCL executes.

## Next action or stop reason
Probe deferred execution of providers.
