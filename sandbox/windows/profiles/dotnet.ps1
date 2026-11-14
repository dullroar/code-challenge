# .NET entries (WPF, console, check.ps1 entries). The host's SDK and NuGet cache are mapped in
# read-only and restore runs offline from that cache.
function Test-Entry($dir) { [bool](Get-ChildItem $dir -Filter *.csproj -ErrorAction SilentlyContinue) }

function Get-HostMaps {
    $dotnet = Join-Path $env:ProgramFiles 'dotnet'
    $nuget = if ($env:NUGET_PACKAGES) { $env:NUGET_PACKAGES } else { Join-Path $env:USERPROFILE '.nuget\packages' }
    foreach ($p in $dotnet, $nuget) { if (-not (Test-Path $p)) { throw "Not found: $p (see SANDBOX-SETUP.md, 'Windows toolchains')" } }
    @(@{ Host = $dotnet; Sandbox = 'C:\sbx\dotnet' }, @{ Host = $nuget; Sandbox = 'C:\sbx\nuget' })
}

function Initialize-Toolchain($work, $home2, $onRunner) {
    $env:DOTNET_CLI_HOME = $home2
    $env:NUGET_PACKAGES = Join-Path $home2 'nuget'
    $env:DOTNET_NOLOGO = '1'; $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
    if (-not $onRunner) {
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
}

function Build-Entry($entry) {
    Write-Host '+ dotnet build -c Release'
    & dotnet build -c Release -v q --nologo 2>&1 | Out-Host
    $LASTEXITCODE -eq 0
}

function Start-Entry($entry, $runArgs, $out) {
    $proj = Get-ChildItem $entry -Filter *.csproj | Select-Object -First 1
    $exe = Get-ChildItem (Join-Path $entry 'bin\Release') -Recurse -Filter "$($proj.BaseName).exe" | Select-Object -First 1
    if (-not $exe) { $exe = Get-ChildItem (Join-Path $entry 'bin\Release') -Recurse -Filter *.exe | Select-Object -First 1 }
    Write-Host "+ $($exe.Name) $($runArgs -join ' ')"
    $a = @{ FilePath = $exe.FullName; WorkingDirectory = $entry; PassThru = $true }
    if ($runArgs) { $a.ArgumentList = $runArgs }
    Start-Process @a
}
