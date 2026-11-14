<#
.SYNOPSIS
  Builds and runs a Windows entry inside Windows Sandbox: a throwaway Hyper-V VM with
  networking off, wiped when it closes.

.DESCRIPTION
  The entry is copied to a scratch folder and mapped into the sandbox read-only, along with
  this machine's toolchain for that kind of entry (see profiles\README.md: .NET SDK and NuGet
  cache, Python, Go, or JDK and Gradle home; also read-only, and restore is offline, so an entry
  can only use packages already in your caches). The only writable mapping is an output folder
  that receives the log, a screenshot, a result file and whatever the profile saves (the
  database, the page a Go entry served).

  Inside the sandbox, if the entry has check.ps1 it is run (it builds and checks the entry
  itself). Otherwise the entry is built and started, left running for -Seconds, screenshotted
  and asked to close (then closed by force if it won't): a smoke test that it builds, starts,
  shows a window and does not crash. The profile then shows what the entry produced.

  Prerequisites: see SANDBOX-SETUP.md at the root of the repository.

  Needs Windows 11 Pro/Enterprise with Windows Sandbox enabled. Only one sandbox can run at a
  time, so close any open Windows Sandbox window first.

.EXAMPLE
  sandbox\windows\run.ps1 src\PythonChallenge1
.EXAMPLE
  sandbox\windows\run.ps1 src\LinqChallenge1
.EXAMPLE
  sandbox\windows\run.ps1 src\xaml -RunArgs strict.xaml
.EXAMPLE
  sandbox\windows\run.ps1 src\ModernChallenge1 -Seconds 30 -Keep
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Entry,
    [string[]]$RunArgs = @(),
    [int]$Seconds = 20,
    [int]$TimeoutMinutes = 15,
    [string]$Profile,   # dotnet, python, go or gradle; chosen from the entry's files if omitted
    [switch]$Keep   # keep the scratch folder (log, screenshot) instead of deleting it
)
$ErrorActionPreference = 'Stop'

# Prefer the wsb CLI (Windows 11 24H2 and later): it starts, connects to and fully stops the VM.
# Without it, fall back to WindowsSandbox.exe; closing its window is then the only way to stop it.
$wsbExe = @((Get-Command wsb.exe -ErrorAction SilentlyContinue).Source,
            (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wsb.exe')) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$sandboxExe = Join-Path $env:windir 'System32\WindowsSandbox.exe'
if (-not $wsbExe -and -not (Test-Path $sandboxExe)) { throw 'Windows Sandbox is not enabled (Containers-DisposableClientVM).' }
if ($wsbExe) {
    if ((& $wsbExe list --raw | ConvertFrom-Json).WindowsSandboxEnvironments.Count -gt 0) { throw "A Windows Sandbox is already running; stop it first (wsb list / wsb stop --id <id>)." }
}
elseif (Get-Process -Name 'WindowsSandbox', 'WindowsSandboxClient', 'WindowsSandboxRemoteSession' -ErrorAction SilentlyContinue) {
    throw 'A Windows Sandbox is already running; close it first.'
}

$entryDir = (Resolve-Path $Entry).Path
$name = Split-Path $entryDir -Leaf

# Which kind of entry is this? Each profile (profiles\*.ps1) recognises its own; see profiles\README.md.
$profilesDir = Join-Path $PSScriptRoot 'profiles'
if (-not $Profile) {
    $Profile = Get-ChildItem $profilesDir -Filter *.ps1 | ForEach-Object { . $_.FullName; if (Test-Entry $entryDir) { $_.BaseName } } | Select-Object -First 1
    if (-not $Profile) { throw "No profile recognises $entryDir; pass -Profile (one of: $((Get-ChildItem $profilesDir -Filter *.ps1).BaseName -join ', '))" }
}
if ($Profile -notmatch '^[a-z]+$' -or -not (Test-Path (Join-Path $profilesDir "$Profile.ps1"))) { throw "Unknown profile '$Profile'" }
. (Join-Path $profilesDir "$Profile.ps1")
$hostMaps = @(Get-HostMaps)
Write-Host "profile: $Profile"

# Scratch layout: in\<entry> (read-only copy), tools (read-only), out (writable).
$work = Join-Path ([IO.Path]::GetTempPath()) ("cc-wsb-$name-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
$in = Join-Path $work 'in'; $tools = Join-Path $work 'tools'; $out = Join-Path $work 'out'
New-Item -ItemType Directory -Path $in, $tools, $out | Out-Null
robocopy $entryDir (Join-Path $in $name) /E /XD bin obj .vs /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
Copy-Item (Join-Path $PSScriptRoot 'inside.ps1') $tools
Copy-Item $profilesDir (Join-Path $tools 'profiles') -Recurse
@{ Name = $name; Profile = $Profile; RunArgs = $RunArgs; Seconds = $Seconds } | ConvertTo-Json | Set-Content (Join-Path $tools 'job.json') -Encoding UTF8

function Map([string]$hostPath, [string]$sandboxPath, [bool]$readOnly) {
    "    <MappedFolder><HostFolder>$([Security.SecurityElement]::Escape($hostPath))</HostFolder><SandboxFolder>$sandboxPath</SandboxFolder><ReadOnly>$($readOnly.ToString().ToLower())</ReadOnly></MappedFolder>"
}
$wsb = Join-Path $work 'entry.wsb'
@"
<Configuration>
  <Networking>Disable</Networking>
  <vGPU>Disable</vGPU>
  <ClipboardRedirection>Disable</ClipboardRedirection>
  <PrinterRedirection>Disable</PrinterRedirection>
  <AudioInput>Disable</AudioInput>
  <VideoInput>Disable</VideoInput>
  <MemoryInMB>4096</MemoryInMB>
  <MappedFolders>
$(Map $in 'C:\sbx\in' $true)
$(Map $tools 'C:\sbx\tools' $true)
$(($hostMaps | ForEach-Object { Map $_.Host $_.Sandbox $true }) -join "`n")
$(Map $out 'C:\sbx\out' $false)
  </MappedFolders>
  <LogonCommand>
    <Command>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\sbx\tools\inside.ps1</Command>
  </LogonCommand>
</Configuration>
"@ | Set-Content $wsb -Encoding UTF8

Write-Host "=== $name in Windows Sandbox (scratch: $work)"
$id = $null
if ($wsbExe) {
    # start creates the VM; connect opens its window and logs in, which runs the LogonCommand
    # in a real desktop session (needed for WPF windows and the screenshot).
    $started = (& $wsbExe start --raw --config (Get-Content $wsb -Raw)) -join "`n"
    if ($started -match '[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}') { $id = $Matches[0] } else { throw "wsb start failed: $started" }
    Write-Host "sandbox id $id"
    # Start-Process, not &: the session window inherits connect's output handle and holds it
    # open, so piping or capturing connect's output would block until the sandbox closes.
    Start-Process -FilePath $wsbExe -ArgumentList 'connect', '--id', $id -WindowStyle Hidden
}
else {
    Start-Process $sandboxExe -ArgumentList "`"$wsb`""
}

$done = Join-Path $out 'result.json'
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
try {
    while (-not (Test-Path $done) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 5 }
    Start-Sleep -Seconds 2
}
finally {
    # Always tear the VM down, even on Ctrl+C or a timeout.
    if ($id) { & $wsbExe stop --id $id 2>&1 | Out-Null }
    else { Get-Process -Name 'WindowsSandbox', 'WindowsSandboxClient', 'WindowsSandboxRemoteSession' -ErrorAction SilentlyContinue | Stop-Process -Force }
}

$log = Join-Path $out 'inside.log'
if (Test-Path $log) { Get-Content $log | Where-Object { $_ -notmatch '^\*{10,}|^(Start|End) time:|^(Username|RunAs User|Configuration Name|Machine|Host Application|Process ID|PSVersion|PSEdition|PSCompatibleVersions|BuildVersion|CLRVersion|WSManStackVersion|PSRemotingProtocolVersion|SerializationVersion):' } | Write-Host }

if (-not (Test-Path $done)) {
    Write-Host "TIMEOUT $name after $TimeoutMinutes minute(s); scratch kept at $work"
    exit 124
}
$result = Get-Content $done -Raw | ConvertFrom-Json
$shot = Join-Path $out 'screenshot.png'
if (Test-Path $shot) { Write-Host "screenshot: $shot" }
if ($result.Passed) { Write-Host "PASS $name ($($result.Summary))" } else { Write-Host "FAIL $name ($($result.Summary))" }
if (-not $Keep -and $result.Passed) { Remove-Item $work -Recurse -Force } else { Write-Host "scratch kept at $work" }
if ($result.Passed) { exit 0 } else { exit 1 }
