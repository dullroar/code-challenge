# Documentation finalizer: manifest.json (with real hashes), toolchain/baseline notes, matrix + report + README updates.
import hashlib
import json
import re
import subprocess

def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()

def git(*a):
    return subprocess.run(["git", *a], capture_output=True, text=True).stdout.strip()

first = git("log", "--reverse", "--format=%cI", "8c14a8e..HEAD").splitlines()
head = git("rev-parse", "HEAD")
xamls = ["strict-built-in/program.xaml", "package-backed-pure/program.xaml", "package-backed-ef/program.xaml"]
import glob
xamls += sorted(glob.glob("probes/*.xaml"))
man = {
    "baselineCommit": "8c14a8e369d16dddb9aa8c54ae22971b4d713971",
    "experimentBranch": "experiment/pure-runtime-wpf-xaml",
    "experimentCommitAtManifestWrite": head,
    "activeFrameworks": {"net10.0-windows": "verified", "net11.0-windows": "compatible (observed)"},
    "sdks": ["10.0.404", "11.0.100"],
    "runtimes": ["Microsoft.NETCore.App 10.0.15", "Microsoft.WindowsDesktop.App 10.0.15", "Microsoft.NETCore.App 11.0.0", "Microsoft.WindowsDesktop.App 11.0.0"],
    "packages": {
        "Microsoft.EntityFrameworkCore.Sqlite": "10.0.14 (unmodified; brings Microsoft.Data.Sqlite, SQLitePCLRaw.bundle_e_sqlite3 2.1.13)",
        "inventory": "evidence/baseline-env.txt"
    },
    "selectedGrades": {
        "strict-built-in": "whole demo with XML persistence substitution (DataTable.WriteXml)",
        "package-backed-pure": "whole demo, SQLite via Microsoft.Data.Sqlite",
        "package-backed-ef": "whole demo, EF Core via owner-approved model copy",
        "constrained": "not built (no remaining imperative capability)"
    },
    "rngSeed": 42,
    "databasePaths": {
        "package-backed-pure": "artifacts/run-<id>/artifacts/pkg-run/demo-timecards.db",
        "package-backed-ef": "artifacts/run-<id>/artifacts/ef-run/demo-timecards.db",
        "strict-output": "artifacts/run-<id>/artifacts/strict-run/demo-timecards.xml",
        "baselineLocalAppData": "never touched (verified absent)"
    },
    "testCommands": [
        "dotnet build probes/host/Host.csproj -c Release -o artifacts/host",
        "./run.ps1 strict-built-in <fresh-id>",
        "./run.ps1 package-backed-pure <fresh-id>",
        "./run.ps1 package-backed-ef <fresh-id>",
        "bash tools/collect_evidence.sh   # needs net11 host in artifacts/net11/host11 (see toolchain.md)"
    ],
    "startUtc": first[0] if first else None,
    "endUtc": subprocess.run(["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"], capture_output=True, text=True).stdout.strip(),
    "iterations": {"loopBudget": 16, "followUps": 4},
    "runtimeXamlSha256": {x: sha(x) for x in xamls},
}
json.dump(man, open("manifest.json", "w", encoding="utf-8"), indent=2)

open("evidence/toolchain.md", "w", encoding="utf-8").write("""# Toolchain / Phase A

- Initial state: SDK 10.0.404 only. Baseline built at `net10.0-windows` (0 warnings, 0 errors).
- Owner approved installing .NET 11: `winget install Microsoft.DotNet.SDK.11` -> SDK 11.0.100, runtimes Microsoft.NETCore.App 11.0.0 and Microsoft.WindowsDesktop.App 11.0.0 (`evidence/baseline-env.txt`).
- **.NET 11 status: compatible.**
  - Unmodified baseline copy (`artifacts/net11/baseline-copy`, only `TargetFramework` changed to `net11.0-windows`) built with 0 errors; `runtimeconfig` tfm `net11.0`.
  - EF Core packages stay at the baseline's 10.0.14 (no package changes); they restored and ran on net11.
  - Probe host and EfModel retargeted to net11 (copies under `artifacts/net11/hostsrc`); all three compositions and probes B1, C4, D1, H2, H3 gave results identical to net10 (see `iteration-20-net11-compat.md`, `runs/`).
  - The net10 baseline still builds with SDK 11 installed.
- Not tested: any net11-specific EF Core 11 packages (not requested; plan forbids changing packages).
""")

p = "evidence/00-baseline.md"
s = open(p, encoding="utf-8").read()
if "baseline-env.txt" not in s:
    s += "\n- Full `dotnet --info`, SDK/runtime lists and package inventory (direct + transitive, incl. SQLitePCLRaw.bundle_e_sqlite3 2.1.13) are in `baseline-env.txt`.\n- Baseline execution remains **not run** (hard-coded real LocalAppData path; I1 showed it cannot be redirected). Behaviors are source-observed; the experiment's compositions are the executed oracle.\n"
open(p, "w", encoding="utf-8").write(s)

p = "evidence/capability-matrix.md"
s = open(p, encoding="utf-8").read()
s = re.sub(r"\| Animation \|.*\n", lambda m: "| Animation | pass: B1 and final runs (`g.Opacity` ~0.655 at 700 ms, looping 1 -> 0.45) | pass: same | – | iteration 01; runs/*/trace.txt NAMED lines |\n", s)
s = re.sub(r"\| Window composition \|.*\n", lambda m: "| Window composition | pass (object graph + TEXT dump + screenshot) | pass | not needed | runs/*/trace.txt, runs/*/screenshot.png |\n", s)
s += "\nAdditional columns of evidence: all three compositions pass on **net10.0-windows (two runs) and net11.0-windows (one run)** with identical results; the package-backed EF variant (`package-backed-ef`) is a second P composition. Screenshots: `runs/<tfm>-<run>-<grade>/screenshot.png` (host-rendered PNG of the window content; the storyboard fades the content, so shots are mid-animation).\n"
open(p, "w", encoding="utf-8").write(s)

p = "evidence/final-report.md"
s = open(p, encoding="utf-8").read()
s = s.replace("Win11 Pro 10.0.26300; SDK 10.0.404 only; runtime 10.0.15; target `net10.0-windows`; .NET 11 **not evaluated: toolchain absent**.", "Win11 Pro 10.0.26300; SDKs 10.0.404 and 11.0.100; runtimes 10.0.15 and 11.0.0; targets `net10.0-windows` (verified) and `net11.0-windows` (**compatible**: baseline copy builds; all compositions identical results).")
s = s.replace("- Test environment: no visible-window verification, no .NET 11.", "- Test environment: windows are rendered by the host to PNG (screenshots in `runs/`), not exercised by a human; no interactive input.")
s = s.replace("no screenshot verification.", "screenshots are host-rendered PNGs.")
s = s.replace("4. Optional: a visible smoke test with screenshots.\n", "")
s = s.replace("(16 of 16 iterations plus follow-ups H3, I1, J1)", "(16 of 16 iterations plus follow-ups H3, I1, J1 and .NET 11)")
s += "\n## 11. Evidence map\n- Per-iteration notes (plan template): `iterations.md` -> `iteration-NN-*.md`; narrative history: `iteration-log.md`.\n- Final runs: `runs/` (net10 x2, net11 x1 per grade: trace, DB dump / XML, screenshot, hashes). Regenerate with `tools/collect_evidence.sh`.\n- Inventory and environment: `baseline-env.txt`, `toolchain.md`. Audit: `constraint-audit.txt`. Hashes: `../manifest.json`, `xaml-hashes.txt`.\n- Disclosures: authoring aids in `tools/` (generators and doc writers) are outside every graded source tree; the baseline project was built but never run; the strict persistence substitution is XML.\n"
open(p, "w", encoding="utf-8").write(s)

p = "README.md"
s = open(p, encoding="utf-8").read()
s = s.replace("Start with `evidence/final-report.md`", "Start with `evidence/final-report.md` (index of per-iteration notes: `evidence/iterations.md`)")
s += "\nPlatforms: `net10.0-windows` verified, `net11.0-windows` compatible (SDK 11.0.100). Final runs and screenshots: `evidence/runs/`.\n"
open(p, "w", encoding="utf-8").write(s)
print("ok")
