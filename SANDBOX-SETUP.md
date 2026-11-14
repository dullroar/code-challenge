# Setting up to run entries safely

Every entry here is code that does odd things on purpose, so nothing needs to run on your real machine to be enjoyed or reviewed. There are two throwaway places to run an entry, and this page is the one place that says how to get each one working. The per-entry READMEs only say what is specific to that entry and link back here.

| You want to run... | Use | Needs |
| --- | --- | --- |
| A Linux entry (APL, Forth, Haskell, regex, Make, CMake, Go, Rust/GTK, Python/Tk, Java/Kotlin Swing, .NET regex...) | **Docker**: `sandbox/container/run-image.sh src/<entry>` | [Docker](#docker) |
| A Windows or GUI entry (WPF, XAML, LINQ, Python/Tk, Java/Kotlin Swing, Go in a browser) | **Windows Sandbox**: `sandbox\windows\run.ps1 src\<entry>` | [Windows Sandbox](#windows-sandbox), plus the entry's [toolchain](#windows-toolchains) |
| To judge a pull request from someone you don't know | The same two, driven by the [gate](sandbox/README.md#reviewing-a-pull-request-from-someone-we-dont-know) | Both, or just GitHub Actions |

Neither is a substitute for reading the code. See [what this does and does not prove](sandbox/README.md#what-this-does-and-does-not-prove).

## Docker

Used for the Linux entries. Each runs from its own small image with **no network, a read-only file system, no capabilities, user `nobody`, resource limits and a timeout**, and shows you what it produced.

### Install

- **Windows 11:** install [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/) with the **WSL 2** backend (the default). Start it and wait for the whale icon to say it is running. The scripts run under **Git Bash** (it comes with [Git for Windows](https://git-scm.com/download/win)) or in a WSL shell.
- **macOS:** Docker Desktop for Mac.
- **Linux:** Docker Engine from your distribution or from Docker's repository. The scripts need to be able to run `docker` without `sudo` (add yourself to the `docker` group).

### Check it works

```bash
docker run --rm hello-world
```

### One-time: build the trusted base images

The first run needs the internet once, to download Ubuntu and its packages. After that, entries run with none.

```bash
sandbox/container/build-bases.sh
```

This builds the build toolchain (slow the first time: it includes GHC, .NET and GNU APL, about 2.5 GB) and the small runtime images the entries are built on (about 120 to 770 MB each). Run it again with `--force` after pulling changes to `sandbox/`.

### Run an entry

```bash
sandbox/container/run-image.sh src/forth                    # build the entry's image, run it, show the rows
sandbox/container/run-image.sh --out ./results src/haskell  # also copy what it wrote to ./results
sandbox/container/run-image.sh --tty src/regex-sed           # give it a terminal (for the animations)
sandbox/container/run-image.sh --online-build --out ./results src/RustChallenge1   # a GUI entry (Rust, Python, Java, Kotlin): screenshot.png lands in ./results
```

Entries that must download dependencies while building (the Go entry, which fetches its SQLite module; the Rust entry, which fetches its locked crates; and the Java and Kotlin entries, which fetch Gradle and their Maven dependencies) need `--online-build`. Use that only on entries already merged to `master`: the build then has network, though the run never does.

### If something goes wrong

| Symptom | Fix |
| --- | --- |
| `failed to connect to the docker API` | Docker Desktop isn't running. Start it and retry. |
| `missing cc-rt-...:local: run build-bases.sh first` | Run `sandbox/container/build-bases.sh`. |
| `$'\r': command not found` or `invalid option name` from a shell script | A Windows checkout with CRLF line endings. `run-image.sh` and `run.sh` convert them in a private copy; if you run a script by hand, don't. |
| Build is very slow or runs out of disk | Docker Desktop's disk image is full: `docker system prune`, or raise the limit in Docker Desktop's settings. |

## Windows Sandbox

Used for the Windows and GUI entries. It is a throwaway Hyper-V virtual machine with **networking off, no clipboard, printer, audio or camera, and only an output folder writable**. It starts fresh every time and is wiped when it closes.

### Install

Needs **Windows 11 Pro, Enterprise or Education** (not Home), with virtualization turned on in the BIOS/UEFI. In an **administrator** PowerShell:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All
```

Then restart. Windows 11 24H2 and later also ship the `wsb` command, which the scripts prefer because it can stop the VM for you; check with `wsb --help`.

### Rules of the road

- **Only one sandbox can run at a time.** Close any open Windows Sandbox window first.
- Your own sandbox stays out of the way: the script uses its own configuration and does not touch the default one.
- Windows Sandbox on ARM64 Windows needs ARM64 versions of the toolchains below, since they are mapped in from your machine.

### Run an entry

```powershell
sandbox\windows\run.ps1 src\PythonChallenge1     # builds/starts it, screenshots it, closes it, prints what it saved
sandbox\windows\run.ps1 src\xaml -RunArgs strict.xaml
sandbox\windows\run.ps1 src\ModernChallenge1 -Seconds 30 -Keep    # -Keep leaves the log and screenshot in a scratch folder
```

The profile (the kind of entry) is chosen from the files in the entry's folder. The result is a log, a screenshot (`screenshot.png`) and whatever the entry saved (its database, the page a Go entry served) in the scratch folder, which is deleted on success unless you pass `-Keep`.

### Windows toolchains

The sandbox has no internet, so it borrows your machine's toolchain, mapped in **read-only**, and restores packages only from your caches. Install what the entry needs, and run the entry once normally so the caches are filled.

| Entry kind | You need on the host | Notes |
| --- | --- | --- |
| .NET (C#, XAML, LINQ) | The .NET 10 SDK (`winget install Microsoft.DotNet.SDK.10`) | NuGet packages come from `%USERPROFILE%\.nuget\packages`; build the entry once on the host first. |
| Python (Tk) | Python 3 for Windows with **tcl/tk and IDLE** (`winget install Python.Python.3.14`) | Not the Microsoft Store stub. Needs nothing else. |
| Go | Go (`winget install GoLang.Go`) | Run `go mod download` once in the entry's folder so the module cache is filled. **Not yet tested on real hardware.** |
| Java, Kotlin | A JDK matching the entry (Java 25) and a populated `%USERPROFILE%\.gradle` | Run `.\gradlew.bat runJava` (or `runKotlin`) once on the host. **Not yet tested on real hardware.** |

If a toolchain is missing, `run.ps1` stops before starting anything and says which one.

### If something goes wrong

| Symptom | Fix |
| --- | --- |
| `Windows Sandbox is not enabled` | Do the [install](#install-1) step and restart. |
| `A Windows Sandbox is already running` | Close its window, or `wsb list` then `wsb stop --id <id>`. |
| `network was reachable; refusing to run` | The sandbox started with networking on. Don't override it; check your Sandbox configuration and Windows version. |
| Timed out, scratch folder kept | Open `inside.log` in the kept scratch folder it names. |
