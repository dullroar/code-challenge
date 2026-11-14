<#
.SYNOPSIS
  Runs the Windows Sandbox exercises (E1, E2) in lessons/exercises.md and reports PASS or FAIL.

.DESCRIPTION
  Needs Windows Sandbox and the host toolchains described in SANDBOX-SETUP.md (the .NET 10 SDK, with
  each entry built once). Only one Windows Sandbox can run at a time, so the steps run one after the other.
  Mutations are made in a COPY of the entry under $env:TEMP; your checkout is never touched.

    pwsh lessons\tools\verify-windows.ps1        # or: powershell -File lessons\tools\verify-windows.ps1
#>
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$run  = Join-Path $repo 'sandbox\windows\run.ps1'
$pass = 0; $fail = @()

function Check([string]$label, [bool]$ok, [string]$detail = '') {
  if ($ok) { Write-Host "  PASS  $label"; $script:pass++ }
  else     { Write-Host "  FAIL  ${label}: $detail"; $script:fail += $label }
}

function Run-Sandbox([string]$entry, [string[]]$extra = @()) {
  # run.ps1 prints its verdict on the last line (PASS/FAIL/TIMEOUT ...) and exits non-zero on failure.
  $out = & powershell -NoProfile -File $run $entry @extra 2>&1 | Out-String
  [pscustomobject]@{ Output = $out; Passed = ($out -match '(?m)^PASS ') }
}

Write-Host "== E1 run and read the evidence"
$r = Run-Sandbox (Join-Path $repo 'src\LinqChallenge1')
Check 'E1 LinqChallenge1 passes in Windows Sandbox' $r.Passed ($r.Output -split "`n" | Select-Object -Last 3 | Out-String)
Check 'E1 ...network blocked'                      ($r.Output -match 'network: blocked')
Check 'E1 ...exactly 40.0h over 5 fixed rows'      ($r.Output -match 'persisted exactly 40\.0h across 5 fixed rows')

$r = Run-Sandbox (Join-Path $repo 'src\xaml') @('-RunArgs', 'strict.xaml')
Check 'E1 xaml strict.xaml runs and is closed by the harness' $r.Passed ($r.Output -split "`n" | Select-Object -Last 3 | Out-String)
Check 'E1 ...it wrote the XML file'               ($r.Output -match 'wrote: .*xaml-demo-timecards\.xml')
Check 'E1 ...and a screenshot exists'             ($r.Output -match 'screenshot: .*screenshot\.png')

Write-Host "== E2 change the seed (copy of src\xaml)"
$tmp = Join-Path $env:TEMP ("weird-e2-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory $tmp | Out-Null
try {
  $copy = Join-Path $tmp 'xaml'
  Copy-Item (Join-Path $repo 'src\xaml') $copy -Recurse
  Remove-Item (Join-Path $copy 'data') -Recurse -Force -ErrorAction SilentlyContinue
  $f = Join-Path $copy 'strict.xaml'
  $text = [IO.File]::ReadAllText($f)
  $seed = '<x:Arguments><sys:Int32>42</sys:Int32></x:Arguments>'
  Check 'E2 the seed element is where the exercise says' ($text.Contains($seed))
  [IO.File]::WriteAllText($f, $text.Replace($seed, '<x:Arguments><sys:Int32>7</sys:Int32></x:Arguments>'))
  $r = Run-Sandbox $copy @('-RunArgs', 'strict.xaml')
  Check 'E2 strict.xaml with seed 7 runs and is closed by the harness' $r.Passed ($r.Output -split "`n" | Select-Object -Last 3 | Out-String)
} finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ""
Write-Host "== $pass passed, $($fail.Count) failed"
if ($fail.Count) { Write-Host "failed: $($fail -join ', ')"; exit 1 }
