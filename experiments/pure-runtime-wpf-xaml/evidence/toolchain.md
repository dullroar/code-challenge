# Toolchain / Phase A

- Initial state: SDK 10.0.404 only. Baseline built at `net10.0-windows` (0 warnings, 0 errors).
- Owner approved installing .NET 11: `winget install Microsoft.DotNet.SDK.11` -> SDK 11.0.100, runtimes Microsoft.NETCore.App 11.0.0 and Microsoft.WindowsDesktop.App 11.0.0 (`evidence/baseline-env.txt`).
- **.NET 11 status: compatible.**
  - Unmodified baseline copy (`artifacts/net11/baseline-copy`, only `TargetFramework` changed to `net11.0-windows`) built with 0 errors; `runtimeconfig` tfm `net11.0`.
  - EF Core packages stay at the baseline's 10.0.14 (no package changes); they restored and ran on net11.
  - Probe host and EfModel retargeted to net11 (copies under `artifacts/net11/hostsrc`); all three compositions and probes B1, C4, D1, H2, H3 gave results identical to net10 (see `iteration-20-net11-compat.md`, `runs/`).
  - The net10 baseline still builds with SDK 11 installed.
- Not tested: any net11-specific EF Core 11 packages (not requested; plan forbids changing packages).
