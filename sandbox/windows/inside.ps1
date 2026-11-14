# Builds, runs and checks one Windows entry. Two callers:
#
# 1. Windows Sandbox (the default parameters), started by run.ps1 through the .wsb LogonCommand.
#    Read-only:  C:\sbx\in\<entry>, C:\sbx\tools, C:\sbx\dotnet (host SDK), C:\sbx\nuget (host package cache)
#    Writable:   C:\sbx\out (inside.log, screenshot.png, result.json) - the only way anything gets out.
#    Refuses to run anything if the network turns out to be reachable.
#
# 2. The GitHub Actions Windows runner (-OnRunner), from .github/workflows/sandbox-gate.yml. The
#    runner is a disposable VM with no secrets, but it HAS network: the entry is built with the
#    runner's own .NET SDK and restores from nuget.org. The result records the network as reachable.
param(
    [string]$In = 'C:\sbx\in',
    [string]$Out = 'C:\sbx\out',
    [string]$JobFile = 'C:\sbx\tools\job.json',
    [string]$Work = 'C:\work',
    [switch]$OnRunner
)
$ErrorActionPreference = 'Continue'
$out = $Out
New-Item -ItemType Directory -Path $out -Force | Out-Null
Start-Transcript -Path (Join-Path $out 'inside.log') | Out-Null
$job = Get-Content $JobFile -Raw | ConvertFrom-Json
$result = [ordered]@{ Passed = $false; Summary = ''; Network = ''; ExitCode = $null; NewFiles = @() }

function Finish {
    ($result | ConvertTo-Json -Depth 4) | Set-Content (Join-Path $out 'result.json') -Encoding UTF8
    Stop-Transcript | Out-Null
    exit
}

try {
    # Prove the network really is off before running anything.
    try { Invoke-WebRequest 'https://github.com' -UseBasicParsing -TimeoutSec 10 | Out-Null; $result.Network = 'REACHABLE' }
    catch { $result.Network = 'blocked' }
    Write-Host "network: $($result.Network)"
    if ($result.Network -ne 'blocked' -and -not $OnRunner) { $result.Summary = 'network was reachable; refusing to run'; Finish }

    # Prove the host folders mapped into the sandbox really are read-only.
    if (-not $OnRunner) {
        foreach ($ro in 'C:\sbx\in', 'C:\sbx\tools', 'C:\sbx\dotnet', 'C:\sbx\nuget') {
            $probe = Join-Path $ro ('probe-' + [guid]::NewGuid().ToString('N'))
            try { Set-Content $probe 'x' -ErrorAction Stop; Remove-Item $probe -ErrorAction SilentlyContinue; $writable = $true } catch { $writable = $false }
            Write-Host "$ro read-only: $(-not $writable)"
            if ($writable) { $result.Summary = "$ro is writable from inside the sandbox; refusing to run"; Finish }
        }
    }

    # Private, writable copies of the entry and of every tool directory .NET wants to write to.
    $work = $Work; $home2 = Join-Path $Work 'home'
    New-Item -ItemType Directory -Path $work, $home2 -Force | Out-Null
    Copy-Item (Join-Path $In $job.Name) $work -Recurse
    $entry = Join-Path $work $job.Name
    $env:DOTNET_CLI_HOME = $home2
    $env:NUGET_PACKAGES = Join-Path $home2 'nuget'
    $env:DOTNET_NOLOGO = '1'; $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
    if (-not $OnRunner) {
    $env:PATH = "C:\sbx\dotnet;$env:PATH"
    $env:DOTNET_ROOT = 'C:\sbx\dotnet'
    # Offline restore: the host's package cache is the only source.
    @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources><clear /><add key="host-cache" value="C:\sbx\nuget" /></packageSources>
</configuration>
'@ | Set-Content (Join-Path $work 'NuGet.config') -Encoding UTF8
    }

    $started = Get-Date
    Set-Location $entry
    $check = Join-Path $entry 'check.ps1'
    if (Test-Path $check) {
        Write-Host "+ check.ps1"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $check 2>&1 | Out-Host
        $result.ExitCode = $LASTEXITCODE
        $result.Passed = ($LASTEXITCODE -eq 0)
        $result.Summary = "check.ps1 exited $LASTEXITCODE"
    }
    else {
        Write-Host "+ dotnet build -c Release"
        & dotnet build -c Release -v q --nologo 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { $result.ExitCode = $LASTEXITCODE; $result.Summary = 'build failed'; Finish }
        $proj = Get-ChildItem $entry -Filter *.csproj | Select-Object -First 1
        $exe = Get-ChildItem (Join-Path $entry 'bin\Release') -Recurse -Filter "$($proj.BaseName).exe" | Select-Object -First 1
        if (-not $exe) { $exe = Get-ChildItem (Join-Path $entry 'bin\Release') -Recurse -Filter *.exe | Select-Object -First 1 }
        Write-Host "+ $($exe.Name) $($job.RunArgs -join ' ')  (smoke test: $($job.Seconds)s)"
        $startArgs = @{ FilePath = $exe.FullName; WorkingDirectory = $entry; PassThru = $true }
        if ($job.RunArgs) { $startArgs.ArgumentList = $job.RunArgs }
        $p = Start-Process @startArgs
        Start-Sleep -Seconds $job.Seconds

        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
        [System.Drawing.Graphics]::FromImage($bmp).CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
        $bmp.Save((Join-Path $out 'screenshot.png'), [System.Drawing.Imaging.ImageFormat]::Png)

        if ($p.HasExited) {
            $result.ExitCode = $p.ExitCode
            $result.Passed = ($p.ExitCode -eq 0)
            $result.Summary = "exited on its own with code $($p.ExitCode) within $($job.Seconds)s"
        }
        else {
            $hasWindow = (Get-Process -Id $p.Id).MainWindowHandle -ne 0
            Stop-Process -Id $p.Id -Force
            $result.Passed = $hasWindow
            $result.Summary = if ($hasWindow) { "still running with a window after $($job.Seconds)s; closed by the harness" } else { "still running after $($job.Seconds)s but no window" }
        }
    }

    # What did it write? (Inside the sandbox, so harmless; reported for the reviewer.)
    $result.NewFiles = @(Get-ChildItem $env:LOCALAPPDATA, $entry -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $started -and $_.FullName -notmatch '\\(bin|obj|home)\\|\\(Microsoft|Temp|Packages|NuGet|D3DSCache)\\' } |
        ForEach-Object { "$($_.FullName) ($($_.Length) bytes)" })
    $result.NewFiles | ForEach-Object { Write-Host "wrote: $_" }
}
catch {
    $result.Summary = "harness error: $_"
    Write-Host $result.Summary
}
Finish
