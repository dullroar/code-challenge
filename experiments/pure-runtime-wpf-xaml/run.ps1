# Repro recipe: builds the generic probe host and runs a runtime-XAML program in an isolated artifact dir.
# usage: ./run.ps1 <strict-built-in|package-backed-pure> [runId]
param([string]$Grade='package-backed-pure',[string]$RunId=(Get-Date -Format 'yyyyMMddTHHmmssZ'))
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
dotnet build "$root/probes/host/Host.csproj" -c Release -o "$root/artifacts/host" | Out-Null
$run="$root/artifacts/run-$RunId"; if (Test-Path $run) { throw "run dir exists: $run (use a fresh id)" }
New-Item -ItemType Directory -Force "$run/artifacts/pkg-run","$run/artifacts/strict-run","$run/artifacts/ef-run" | Out-Null
Copy-Item "$root/$Grade/program.xaml" "$run/program.xaml"
Push-Location $run   # relative DB path 'artifacts/pkg-run/...' resolves inside the run dir
& "$root/artifacts/host/Host.exe" program.xaml 800 | Out-File trace.txt -Encoding utf8; Get-Content trace.txt
(Get-FileHash program.xaml -Algorithm SHA256).Hash | Out-File program.sha256
Pop-Location
Write-Host "run dir: $run"
