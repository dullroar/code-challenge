# Go entries. The host's Go toolchain and module cache are mapped in read-only and the build is
# offline (GOPROXY=off, modules from the cache). The entry serves a page on loopback and opens it
# in Edge; the harness also fetches that page over loopback, saves it, then "closes" it so the
# program finishes and commits its rows.
#
# NOT YET RUN ON REAL HARDWARE: written against the Go entry's behaviour (it prints its loopback
# URL and exits after /closed) and tested in the container version of the same idea, but there was
# no Go on the machine this was written on. Run `sandbox\windows\run.ps1 src\GoChallenge1` and fix
# whatever the first run turns up (most likely the read-only module cache).
function Test-Entry($dir) { Test-Path (Join-Path $dir 'go.mod') }

function Get-HostMaps {
    $go = Get-Command go.exe -ErrorAction SilentlyContinue
    if (-not $go) { throw "Go not found on this machine (see SANDBOX-SETUP.md, 'Windows toolchains')" }
    $goroot = (& go env GOROOT).Trim(); $modcache = (& go env GOMODCACHE).Trim()
    foreach ($p in $goroot, $modcache) { if (-not (Test-Path $p)) { throw "Not found: $p. Run 'go mod download' once in the entry, on the host." } }
    @(@{ Host = $goroot; Sandbox = 'C:\sbx\go' }, @{ Host = $modcache; Sandbox = 'C:\sbx\gomod' })
}

function Initialize-Toolchain($work, $home2, $onRunner) {
    if ($onRunner) { return }
    $env:PATH = "C:\sbx\go\bin;$env:PATH"
    $env:GOROOT = 'C:\sbx\go'
    $env:GOMODCACHE = 'C:\sbx\gomod'
    $env:GOCACHE = Join-Path $home2 'gocache'
    $env:GOPATH = Join-Path $home2 'gopath'
    $env:GOPROXY = 'off'; $env:GOFLAGS = '-mod=mod'; $env:GOTOOLCHAIN = 'local'
}

function Build-Entry($entry) {
    Write-Host '+ go build'
    & go build -o entry.exe . 2>&1 | Out-Host
    $LASTEXITCODE -eq 0
}

function Start-Entry($entry, $runArgs, $out) {
    $log = Join-Path $out 'entry-stdout.txt'
    Write-Host '+ entry.exe'
    $p = Start-Process (Join-Path $entry 'entry.exe') -WorkingDirectory $entry -RedirectStandardOutput $log -PassThru
    # Fetch the page over loopback while the program is waiting for its "window" to close.
    $url = $null
    for ($i = 0; $i -lt 100 -and -not $url; $i++) {
        Start-Sleep -Milliseconds 200
        $m = Select-String -Path $log -Pattern 'http://127\.0\.0\.1:\d+/' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($m) { $url = $m.Matches[0].Value }
    }
    if ($url) {
        Invoke-WebRequest $url -UseBasicParsing -OutFile (Join-Path $out 'page.html')
        Write-Host "fetched $url over loopback -> page.html in the out folder"
        $script:GoClosedUrl = $url + 'closed'
    }
    $p
}

function Show-Outcome($entry, $out) {
    $db = Get-ChildItem $entry -Recurse -Filter *.db -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($db) { Copy-Item $db.FullName $out -Force; Write-Host "database copied to the out folder: $($db.Name) ($($db.Length) bytes)" }
}

# The harness's "is there a window?" check can't see Edge's tab, so a fetched page counts.
function Test-Shown { [bool]$script:GoClosedUrl }

# Closing the "window" means telling the page it was closed, which is what its Close button does.
function Close-Entry($p) {
    if ($script:GoClosedUrl) { try { Invoke-WebRequest $script:GoClosedUrl -UseBasicParsing | Out-Null } catch {} }
}
