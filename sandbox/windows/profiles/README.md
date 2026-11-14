# Windows Sandbox language profiles

Each file here teaches `run.ps1` and `inside.ps1` how to build and start one kind of entry. Like everything in `sandbox/`, they are maintainer-owned: an entry never ships one, it only ships its code, a README and optionally a `check.ps1`.

A profile defines these functions (the first two run on the host, the rest inside the sandbox):

| Function | Does |
| --- | --- |
| `Test-Entry $dir` | Host. Is this folder an entry of this kind? Used to pick the profile when `-Profile` isn't given. |
| `Get-HostMaps` | Host. The host toolchain folders to map in **read-only**, as `@{ Host; Sandbox }`. Throws, pointing at `SANDBOX-SETUP.md`, if the toolchain isn't installed. |
| `Initialize-Toolchain $work $home2 $onRunner` | Inside. Puts the mapped toolchain on PATH, points caches at writable scratch folders, forces offline operation. |
| `Build-Entry $entry` | Inside. Builds the entry. Returns `$true` on success. |
| `Start-Entry $entry $runArgs $out` | Inside. Starts the entry and returns its process. |
| `Show-Outcome $entry $out` | Inside, optional. After the window has been shown and closed: prints or saves what the entry produced (database rows, the served page). |

| Profile | Picks entries with | Maps in read-only |
| --- | --- | --- |
| `dotnet` | a `*.csproj` | the host .NET SDK and NuGet cache |
| `python` | a `*.py` (Tk) | the host Python install |
| `go` | a `go.mod` | the host Go toolchain and module cache |
| `gradle` | a `build.gradle` (Java, Kotlin) | the host JDK and Gradle home |

To add a language, add a file here and nothing else. The host needs the matching toolchain installed; see [`SANDBOX-SETUP.md`](../../../SANDBOX-SETUP.md).
