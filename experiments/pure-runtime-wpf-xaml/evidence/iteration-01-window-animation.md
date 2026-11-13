# Iteration 1: Window composition and storyboard

## Hypothesis
EventTrigger/BeginStoryboard in runtime-loaded XAML animates a property.

## Grade and allowed types/packages
S: WPF only

## Smallest probe
probes/B1-window-animation.xaml

## Command(s) and environment
`cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800` with host probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host.
Environment: Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
content opacity 0.2 held after the 0.4 s animation; root = System.Windows.Window; STA host.

## Evidence paths and hashes
- `probes/B1-window-animation.xaml` sha256 `fa9f678ea40da3b1`

## Classification: pass | partial | blocked | invalid-by-constraint
pass

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
XAML declares window, trigger, storyboard; WPF runtime executes. Nothing hidden.

## Next action or stop reason
Probe object construction and method invocation.
