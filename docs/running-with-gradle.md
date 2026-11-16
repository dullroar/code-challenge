# Running entries with Gradle

The root [`build.gradle`](../build.gradle) has a task for every entry, plus tasks for the [Docker sandbox](../sandbox/README.md):

```powershell
.\gradlew.bat runForth            # Windows
./gradlew runForth                # Linux, macOS
```

In IntelliJ IDEA, open the repository, trust it, and reload Gradle. The tasks appear in the **Gradle** tool window under **code-challenge → Tasks**, in the groups below.

A task only starts an entry from its own folder. You still need that entry's language installed.

## application: Java, Kotlin, Python, Go

`runJava` and `runKotlin` need JDK 25. `runPython` needs Python 3 for Windows (the `py` launcher). `runGo` needs the Go toolchain.

## application (.NET)

`runLinq1`, `runLinq2`, `runModern`, `runXamlStrict`, `runXamlSqlite`, `runXamlEfcore`, `runRegexDotnet`

They need the .NET 10 SDK. All but `runRegexDotnet` are WPF, so they're Windows only.

## application (WSL) / application (Linux)

`runRust`, `runApl`, `runAplWeird`, `runForth`, `runForthWeird`, `runHaskell`, `runHaskellWeird`, `runCmake`, `runMakeGnu`, `runRegexPcre2`, `runRegexPcre2grep`, `runRegexPerl`, `runRegexSed`, `runCobol`, `runCobolWeird`, `runLisp`, `runLispWeird`, `runM4`, `runTcl`, `runTclWeird`, `runAwk`, `runAwkWeird`

On Windows they run inside WSL 2 (distribution `Ubuntu`, or `-PwslDistro=Name`). Elsewhere they run in `bash`. Each checks for its tool first, and if it's missing, names it and stops with exit code 127.

On Ubuntu 24.04 this installs nearly everything:

```bash
sudo apt install build-essential pkg-config sqlite3 perl make cmake gforth ghc gnucobol \
    libpcre2-dev cargo rustc libgtk-4-dev libsqlite3-dev \
    sbcl m4 tcl tk libsqlite3-tcl gawk
```

The last line is for the Lisp, m4, Tcl and AWK entries. `runTclWeird` and `runTcl` need the Tcl `sqlite3` package (`libsqlite3-tcl`), and the tasks run text mode only: the optional Tk window (`tk`) is for running `tclsh timecards.tcl --gui` yourself. `runAwkWeird` needs gawk (it uses `RT`); the tool check names `gawk`, so Ubuntu's default mawk is not enough for that one.

The two exceptions are built from source:

- **GNU APL** (`runApl`, `runAplWeird`): see [`src/apl/README.md`](../src/apl/README.md).
- **`pcre2grep` with callout scripts** (`runRegexPcre2grep`): Ubuntu's lacks them. See [`src/regex-pcre2grep/README.md`](../src/regex-pcre2grep/README.md). The task looks in `~/.local/bin`, or wherever `PCRE2GREP` points.

`runRust` opens a GTK window, which needs a display (WSLg on Windows), and stays open until you close it. It builds into `~/.cache/code-challenge/RustChallenge1-target` on the Linux side, because builds on a Windows drive mounted in WSL would start from scratch every time.

Each entry writes its records under `~/.local/share/<Name>/` (or `$XDG_DATA_HOME`). On Windows that's inside WSL, at `\\wsl$\Ubuntu\home\<you>\.local\share\`.

## sandbox, sandbox (check), sandbox (show)

These run the repository's sandbox scripts. They need Docker, set up as in [`SANDBOX-SETUP.md`](../SANDBOX-SETUP.md#docker). On Windows they also need Git Bash, from Git for Windows (or `-PgitBash=path`).

| Task | Does |
| --- | --- |
| `sandboxBuildBases` | Builds the trusted images. Run it once first (it needs network, about 2.5 GB), and again with `-Pforce` after pulling changes to `sandbox/`. |
| `sandboxSelftest` | Proves the lockdown works on your machine. |
| `sandboxCheck<Entry>` | Runs the entry's `check.sh` exactly as the [gate](../sandbox/README.md) does. One for each entry with a `check.sh`. |
| `sandboxCheckAll` | All of the above. Each entry prints `PASS` or `FAIL`. |
| `sandboxShow<Entry>` | Builds the entry's container image, runs it locked down, and shows what it wrote. One for each entry with a `Dockerfile`. A copy goes to `build/sandbox-out/<entry>/`, including `screenshot.png` for GUI entries. |

Task names come from the folder names (`src/apl-weird` gives `sandboxCheckAplWeird`), so new entries get tasks automatically. A new entry whose Dockerfile downloads while it builds must be added to the `onlineBuild` list in `build.gradle`.

**The WPF entries** (`LinqChallenge1`, `LinqChallenge2`, `ModernChallenge1`, `xaml`) have no `sandbox…` tasks, because WPF can't run in Docker's Linux containers. To run them isolated, use Windows Sandbox (`sandbox\windows\run.ps1 src\<entry>`, see [`SANDBOX-SETUP.md`](../SANDBOX-SETUP.md#windows-sandbox)), which needs Windows 11 Pro, Enterprise or Education. The Linq entries' `check.ps1` runs there and in the gate's Windows job.

## Options

| Option | Default | For |
| --- | --- | --- |
| `-PwslDistro=Name` | `Ubuntu` | The WSL distribution for the Linux tasks |
| `-PgitBash=path` | `C:/Program Files/Git/bin/bash.exe` | The Git Bash for the sandbox tasks |
| `-Pforce` | off | `sandboxBuildBases`: rebuild every image |

Add them after the task name (`.\gradlew.bat runForth -PwslDistro=Ubuntu-24.04`), in an IntelliJ run configuration's **Run** field, or permanently in `~/.gradle/gradle.properties` (`wslDistro=Ubuntu-24.04`).

## When something goes wrong

| Symptom | Fix |
| --- | --- |
| `<tool> is not installed in WSL` | Install it in WSL (see above). |
| `/usr/bin/env: 'bash\r'` | The checkout has Windows line endings. [`.gitattributes`](../.gitattributes) prevents this in new clones. In an older one, run this once with a clean working tree: `git rm -r --cached -q src && git reset -q --hard` |
| `failed to connect to the docker API` | Start Docker Desktop. |
| `missing cc-rt-…:local` or `command not found` in a sandbox check | Run `sandboxBuildBases` (with `-Pforce` if `sandbox/` changed). |
| No colour animation from `runCmake`, `runMakeGnu` or the regex entries | Gradle's output isn't a terminal, so they switch it off. Run the entry in a terminal instead (see its README). |
