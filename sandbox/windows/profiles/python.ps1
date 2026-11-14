# Python entries with a window (Tk). The host's Python install is mapped in read-only; the
# standard library (tkinter, sqlite3) is all they need, so there is nothing to restore.
function Test-Entry($dir) {
    [bool](Get-ChildItem $dir -Filter *.py -ErrorAction SilentlyContinue) -and -not (Test-Path (Join-Path $dir 'go.mod'))
}

function Get-HostMaps {
    $py = Get-Command python.exe -ErrorAction SilentlyContinue | Where-Object { $_.Source -notmatch 'WindowsApps' } | Select-Object -First 1
    if (-not $py) { throw "Python not found on this machine (see SANDBOX-SETUP.md, 'Windows toolchains')" }
    $prefix = (& $py.Source -I -c 'import sys; print(sys.base_prefix)').Trim()
    if (-not (Test-Path (Join-Path $prefix 'tcl'))) { throw "$prefix has no tcl folder, so no tkinter; reinstall Python with 'tcl/tk and IDLE' (see SANDBOX-SETUP.md)" }
    @(@{ Host = $prefix; Sandbox = 'C:\sbx\python' })
}

function Initialize-Toolchain($work, $home2, $onRunner) {
    if (-not $onRunner) { $env:PATH = "C:\sbx\python;$env:PATH" }
    $env:PYTHONDONTWRITEBYTECODE = '1'   # the mapped install is read-only
    $env:PYTHONUTF8 = '1'
}

function Build-Entry($entry) { $true }   # nothing to build

function Start-Entry($entry, $runArgs, $out) {
    $script = @('program.py', 'main.py') | Where-Object { Test-Path (Join-Path $entry $_) } | Select-Object -First 1
    if (-not $script) { $script = (Get-ChildItem $entry -Filter *.py | Select-Object -First 1).Name }
    Write-Host "+ python $script"
    Start-Process python.exe -ArgumentList (@($script) + $runArgs) -WorkingDirectory $entry -PassThru
}

function Show-Outcome($entry, $out) {
    $db = Get-ChildItem $entry -Recurse -Filter *.db -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $db) { Write-Host 'no database was written'; return }
    Copy-Item $db.FullName $out -Force
    Write-Host "--- $($db.Name) (opened read-only; a copy is in the out folder)"
    $code = @'
import sqlite3, sys
con = sqlite3.connect("file:" + sys.argv[1] + "?mode=ro", uri=True)
for (t,) in con.execute("select name from sqlite_master where type='table' and name not like 'sqlite_%'").fetchall():
    n = con.execute('select count(*) from "%s"' % t).fetchone()[0]
    cur = con.execute('select * from "%s" order by rowid desc limit 25' % t)
    print("table %s: %d row(s)" % (t, n))
    print("  " + " | ".join(d[0] for d in cur.description))
    for r in cur.fetchall(): print("  " + " | ".join(str(v) for v in r))
'@
    # A script file, not -c: Windows PowerShell 5.1 mangles double quotes in native-command arguments.
    $show = Join-Path $env:TEMP 'show-db.py'
    Set-Content $show $code -Encoding UTF8
    & python.exe -I $show $db.FullName 2>&1 | Out-String
}
