# Java and Kotlin entries (Gradle, Spring Boot, a Swing window). The host's JDK and Gradle home
# (wrapper distribution and dependency cache) are mapped in read-only; Gradle runs --offline, so
# only what the host has already downloaded can be used. Run the entry once on the host first.
#
# NOT YET RUN ON REAL HARDWARE: there was no JDK on the machine this was written on. The likely
# first problems are Gradle wanting to write into its home (this seeds a private writable copy,
# which can be large) and the toolchain version (the entries ask for Java 25).
function Test-Entry($dir) { [bool](Get-ChildItem $dir -Filter build.gradle* -ErrorAction SilentlyContinue) }

function Get-HostMaps {
    $jh = $env:JAVA_HOME
    if (-not $jh) { $j = Get-Command java.exe -ErrorAction SilentlyContinue; if ($j) { $jh = Split-Path (Split-Path $j.Source) } }
    if (-not $jh -or -not (Test-Path $jh)) { throw "No JDK found (set JAVA_HOME; see SANDBOX-SETUP.md, 'Windows toolchains')" }
    $gh = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { Join-Path $env:USERPROFILE '.gradle' }
    if (-not (Test-Path (Join-Path $gh 'caches'))) { throw "$gh has no caches folder: run the entry once on the host so Gradle downloads its dependencies" }
    @(@{ Host = $jh; Sandbox = 'C:\sbx\jdk' }, @{ Host = $gh; Sandbox = 'C:\sbx\gradle-home' })
}

function Initialize-Toolchain($work, $home2, $onRunner) {
    if ($onRunner) { return }
    $env:JAVA_HOME = 'C:\sbx\jdk'
    $env:PATH = "C:\sbx\jdk\bin;$env:PATH"
    # Gradle wants a writable home. Seed a private copy of the read-only one.
    $gh = Join-Path $home2 'gradle'
    robocopy 'C:\sbx\gradle-home' $gh /E /XD daemon native /NFL /NDL /NJH /NJS /NP | Out-Null
    $env:GRADLE_USER_HOME = $gh
    $env:GRADLE_OPTS = '-Dorg.gradle.offline=true'
}

function Build-Entry($entry) {
    Write-Host '+ gradlew --offline build -x test'
    & (Join-Path $entry 'gradlew.bat') --offline --no-daemon -q build -x test 2>&1 | Out-Host
    $LASTEXITCODE -eq 0
}

function Start-Entry($entry, $runArgs, $out) {
    $task = if (Select-String -Path (Join-Path $entry 'build.gradle') -Pattern 'runKotlin' -Quiet) { 'runKotlin' } else { 'runJava' }
    Write-Host "+ gradlew --offline $task"
    Start-Process (Join-Path $entry 'gradlew.bat') -ArgumentList '--offline', '--no-daemon', $task -WorkingDirectory $entry -PassThru
}

function Show-Outcome($entry, $out) {
    $db = Get-ChildItem $entry -Recurse -Filter *.db -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($db) { Copy-Item $db.FullName $out -Force; Write-Host "database copied to the out folder: $($db.Name) ($($db.Length) bytes)" } else { Write-Host 'no database was written' }
}
