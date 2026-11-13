# Iteration 21: EF Core 11.0.0 packages (follow-up)

## Hypothesis
The compositions behave identically when the experiment copy uses EF Core 11.0.0 (with Microsoft.Data.Sqlite 11.0.0) on `net11.0-windows`.

## Grade and allowed types/packages
P: Microsoft.EntityFrameworkCore.Sqlite **11.0.0** (experiment copy only; the baseline project and the net10 experiment stay on 10.0.14). Existing model copy `EfModel` unchanged.

## Smallest probe
Copy `probes/host` and `package-backed-ef/model` to `artifacts/net11/hostsrc11`, set `TargetFramework` to `net11.0-windows` and the package `Version` to `11.0.0`, build, and run the three program XAML files unchanged.

## Command(s) and environment
`cp -r artifacts/net11/hostsrc artifacts/net11/hostsrc11; sed -i 's/Version="10.0.14"/Version="11.0.0"/' hostsrc11/host/Host.csproj hostsrc11/model/EfModel.csproj; (cd hostsrc11/host && dotnet build -c Release -o ../../host11ef)`, then `Host.exe program.xaml 700` in fresh dirs. SDK 11.0.100, Win11 26300.

## Observed result (include exception type/message and relevant stack-frame names)
Build succeeded with no errors. Loaded assemblies: Microsoft.EntityFrameworkCore.Sqlite 11.0.0, Microsoft.Data.Sqlite 11.0.0. No load or runtime errors. EF composition: 4 cards Meetings 16, Coding 11, Debugging 11, Learning 15 (year 2026, week 46), window `Saved via EF Core: 4 cards, 53.0 hours`; EF-generated schema and the SQL guard trigger present. SQLite composition: identical 4 rows. Strict composition: XML sha256 prefix 94ac35b93f8248ab (identical).

## Evidence paths and hashes
- `evidence/runs/net11-efcore11-ef/` (trace, db-dump with schema, screenshot)
- `evidence/runs/net11-efcore11-pkg/`, `evidence/runs/net11-efcore11-strict/`

## Classification: pass | partial | blocked | invalid-by-constraint
pass

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
Unchanged from iteration 19; only the package version differs (EF Core 11.0.0 / Microsoft.Data.Sqlite 11.0.0 supply the same generic services).

## Next action or stop reason
None. Packages in the committed projects remain 10.0.14 per the plan's "do not change baseline packages"; the 11.0.0 run is a reproducible variant, not a replacement.
