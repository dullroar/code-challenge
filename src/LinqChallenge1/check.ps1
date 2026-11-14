#!/usr/bin/env pwsh
# Checks the rules of the LINQ challenge, Variant A (fluent method chain).
# Uses a throwaway data directory so it never touches %LOCALAPPDATA%.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# 1. No orchestration helper may hide the workflow behind a method call.
$code = Get-Content Program.cs -Raw
foreach ($forbidden in 'RunEverything', 'BuildAndPersistCards', 'ShowTerminal', 'DoChallenge', 'Orchestrate') {
    if ($code -match "\b$forbidden\b") {
        Write-Error "FAIL: forbidden orchestration helper '$forbidden' found in Program.cs"
        exit 1
    }
}

# 2. Build.
dotnet build -c Release -v q --nologo
if ($LASTEXITCODE -ne 0) { Write-Error "FAIL: build failed"; exit 1 }

# 3. Run against a throwaway data directory, with a hard timeout so a stuck dispatcher
#    cannot hang the check.
$data = Join-Path ([System.IO.Path]::GetTempPath()) ("LinqChallenge1Check-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $data | Out-Null
try {
    $exe = Join-Path $PSScriptRoot 'bin\Release\net10.0-windows\LinqChallenge1.exe'
    $outFile = Join-Path $data 'out.txt'
    $errFile = Join-Path $data 'err.txt'
    $exitFile = Join-Path $data 'exitcode.txt'
    # Start-Process's own -RedirectStandardOutput/-Error combined with -PassThru loses
    # ExitCode for this WPF exe under Windows PowerShell 5.1. Run it in a background job
    # via a cmd.exe wrapper instead, enforce the timeout with Wait-Job, and read the real
    # exit code back from a file.
    $job = Start-Job -ScriptBlock {
        param($exe, $outFile, $errFile, $exitFile, $dataDir)
        $env:LINQ_CHALLENGE_DATA_DIR = $dataDir
        & cmd /c "`"$exe`" > `"$outFile`" 2> `"$errFile`" & echo %ERRORLEVEL% > `"$exitFile`""
    } -ArgumentList $exe, $outFile, $errFile, $exitFile, $data
    $completed = Wait-Job $job -Timeout 15
    Receive-Job $job | Out-Null
    Remove-Job $job -Force
    if (-not $completed) {
        Get-Process -Name 'LinqChallenge1' -ErrorAction SilentlyContinue | Stop-Process -Force
        Write-Error "FAIL: process did not exit within 15s (dispatcher likely stuck)"
        exit 1
    }
    $exitCode = [int](Get-Content $exitFile -Raw).Trim()
    if ($exitCode -ne 0) {
        Write-Error "FAIL: process exited with code $exitCode"
        Get-Content $errFile | Write-Host
        exit 1
    }

    $out = Get-Content $outFile -Raw
    if ($out -notmatch 'PERSISTED 5 rows, total=40\.0h') {
        Write-Error "FAIL: expected a 5-row, 40.0h report; got:`n$out"
        exit 1
    }
    $rows = @(
        @{ Date = '2024-01-01'; Desc = 'Planning' }
        @{ Date = '2024-01-02'; Desc = 'Implementation' }
        @{ Date = '2024-01-03'; Desc = 'Review' }
        @{ Date = '2024-01-04'; Desc = 'Testing' }
        @{ Date = '2024-01-05'; Desc = 'Documentation' }
    )
    foreach ($row in $rows) {
        if ($out -notmatch "$($row.Date)\s+8\.0h\s+$($row.Desc)") {
            Write-Error "FAIL: expected row not found: $($row.Date) 8.0h $($row.Desc)`nGot:`n$out"
            exit 1
        }
    }

    if (-not (Test-Path (Join-Path $data 'timecards.db'))) {
        Write-Error "FAIL: timecards.db was not created"
        exit 1
    }
}
finally {
    Remove-Item -Recurse -Force $data -ErrorAction SilentlyContinue
}

Write-Host "OK: no orchestration helper, build clean, one run persisted exactly 40.0h across 5 fixed rows, and the process exited on its own"
