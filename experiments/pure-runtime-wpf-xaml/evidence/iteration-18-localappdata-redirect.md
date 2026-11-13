# Iteration 18: Isolating the baseline context (follow-up I1)

## Hypothesis
LOCALAPPDATA can redirect Environment.GetFolderPath.

## Grade and allowed types/packages
S

## Smallest probe
probes/I1-localappdata.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
GetFolderPath(LocalApplicationData) returned the real path with and without the env override. Enum parameters need x:Static Member="sys:Environment+SpecialFolder.X".

## Evidence paths and hashes
- `probes/I1-localappdata.xaml` sha256 `b885f6c60182c006`

## Classification: pass | partial | blocked | invalid-by-constraint
blocked

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Owner approved a copy with changed DB folder.

## Next action or stop reason
Build EF composition.
