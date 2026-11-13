# Documentation generator: writes evidence/iteration-NN-*.md in the plan's section-5 template from the table below,
# filling in real sha256 hashes of the referenced files. Documentation only.
import hashlib
import os

HOST = "probes/host/Host.exe (generic loader; `Host.exe <file.xaml> <ms>`) built from probes/host"
ENV = "Win11 Pro 10.0.26300 x64, .NET SDK 10.0.404 (net10.0-windows); iterations 17+ also SDK 11.0.100"
CMD = "cd artifacts/<scratch>; ../host/Host.exe ../../probes/<probe>.xaml 800"


def sha(path):
    if not os.path.exists(path):
        return "(file not present)"
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()[:16]


# id, slug, title, hypothesis, grade, probe files, observed, classification, ownership, next
IT = [
 (1, "window-animation", "Window composition and storyboard", "EventTrigger/BeginStoryboard in runtime-loaded XAML animates a property.", "S: WPF only", ["probes/B1-window-animation.xaml"],
  "content opacity 0.2 held after the 0.4 s animation; root = System.Windows.Window; STA host.", "pass",
  "XAML declares window, trigger, storyboard; WPF runtime executes. Nothing hidden.", "Probe object construction and method invocation."),
 (2, "odp-seeded-random", "ObjectDataProvider and seeded Random", "ODP can construct and call a built-in; a seed is available through x:Arguments.", "S: System.Random, ObjectDataProvider", ["probes/C1-odp-random.xaml"],
  "x:Arguments built Random(42); Next(10,20)=16 at parse time. `{Binding}` on ObjectInstance: XamlParseException (not a DP). `{StaticResource provider}` and `{x:Reference}` as ObjectInstance are unwrapped to the provider Data (MissingMethodException Int32.Refresh).", "partial",
  "Construction/invocation: XAML + ODP semantics. Provider-as-receiver for Refresh: blocked (2 mechanisms, closed).", "Retrigger via a smuggled reference."),
 (3, "refresh-retrigger", "Re-trigger a call", "A provider can invoke Refresh on another provider if hidden inside a collection.", "S: x:Array, ObjectDataProvider, DataSourceProvider.Refresh", ["probes/C2-refresh-retrigger.xaml"],
  "provider stored in x:Array, fetched by GetValue(0), Refresh invoked: Next advanced 16 -> 11.", "pass",
  "XAML wires the retrigger; ODP/DataSourceProvider runtime semantics execute it.", "Probe dynamic parameters."),
 (4, "dynamic-params", "Late-bound method parameters", "A Binding or a provider can be a MethodParameter.", "S", ["probes/C3-dynamic-params.xaml"],
  "`<Binding>` in MethodParameters: parse error (cannot be used within a ParameterCollection). StaticResource of a provider passes the provider object (ArrayList held an ODP).", "blocked",
  "Missing primitive at this point: late-bound scalar arguments. Resolved later by carriers (iteration 16).", "Probe ordering and arithmetic."),
 (5, "sequence-order", "Execution order and determinism", "Providers execute in document order and the seeded sequence is reproducible.", "S", ["probes/C4-sequence-order.xaml"],
  "five providers on one Random(42): 16,11,11,15,11 on every run; execution at parse (EndInit) in document order; dictionary enumeration order varies per process but is irrelevant.", "pass",
  "Document order = program order (WPF parser semantics); data from Random.", "Arithmetic/comparison primitives."),
 (6, "shuffle-sum", "Arithmetic and generics", "Built-in static methods give arithmetic and comparison; generic methods are reachable.", "S: System.Linq.Enumerable, Int32", ["probes/E1-shuffle-sum.xaml"],
  "Enumerable.Sum(int[])=60, Int32.CompareTo(40)=1 via receiver unwrapping. Random.Shuffle: MissingMethodException (generic).", "partial",
  "Sum/CompareTo executed by BCL; generic methods unreachable through ODP.", "Probe SQLite provenance."),
 (7, "sqlite-package", "SQLite from XAML", "Microsoft.Data.Sqlite can be driven through x:Arguments and ODP.", "P: Microsoft.Data.Sqlite via Microsoft.EntityFrameworkCore.Sqlite 10.0.14", ["probes/F1-sqlite-package.xaml"],
  "SqliteConnection/SqliteCommand constructed; Open, ExecuteNonQuery run; row (1,'Coding',12.0,1) verified with the sqlite3 CLI / Python. Provenance: NuGet package, not built-in.", "pass",
  "Orchestration in XAML; SQLite engine is a package effect target.", "Threading."),
 (8, "threading", "Background work", "XAML can build, start and join a Thread and run provider work off the UI thread.", "S: System.Threading.Thread, Delegate.CreateDelegate, ODP IsAsynchronous", ["probes/G1-thread-delegate.xaml", "probes/G2-thread-async-odp.xaml"],
  "ThreadStart from x:FactoryMethod CreateDelegate over ArrayList.Clear; Thread(IsBackground) started/joined; thread id 7 vs host 2; count 2->0. IsAsynchronous ODP ran on pool thread 4. A provider-produced delegate in x:Arguments failed (not unwrapped).", "pass",
  "XAML owns construction and sequencing; BCL executes.", "Probe deferred execution of providers."),
 (9, "initial-load", "Deferring a provider", "IsInitialLoadEnabled=False arms a provider to run later by Refresh.", "P", [],
  "Provider with the flag still executed at parse once MethodName was set (attribute order irrelevant; IsAsynchronous also ran once). A first thread-over-Refresh design double-inserted rows and was discarded. Probe code was inline in the session (scratch dirs); result recorded in iteration-log.md.", "blocked",
  "No arm-now/fire-later mechanism found; document order used instead.", "Integrate."),
 (10, "strict-v1", "First strict composition", "Compose passed strict capabilities.", "S", ["strict-built-in/program.xaml"],
  "Superseded by iteration 16 (v2). v1 had hand-copied constants and wrong window bindings (Path=Data).", "partial", "Superseded.", "Fix bindings (iteration 12)."),
 (11, "package-backed-v1", "First package-backed composition", "SQLite persistence in document order with SQL guard.", "P", ["package-backed-pure/program.xaml"],
  "Superseded by iteration 16 (v2): v1 used an SQL formula instead of the seeded Random.", "partial", "Superseded.", "Seeded values into the DB."),
 (12, "datatrigger-branch", "Data-dependent branch", "A DataTrigger can branch on a computed value.", "S: DataTrigger, Sum, CompareTo", ["probes/D1-datatrigger-branch.xaml"],
  "text switched to 'OVER-40: terminal'. Typed Int32 Value required (string '1' never matched); local property beats style trigger setter. Correction: a provider used as Binding Source is unwrapped; `Path=Data` finds nothing (window texts in iterations 10/11 had been blank).", "pass",
  "Branch declared in XAML; WPF trigger engine evaluates.", "Probe trigger-driven effects."),
 (13, "trigger-effect-animation", "Animation-driven CLR write", "An animated Tag with a OneWayToSource binding writes ObjectDataProvider.MethodName.", "S", ["probes/D2-trigger-effect.xaml"],
  "Tag became 'Clear' but the binding did not push the animated value; only the initial null push occurred.", "blocked", "Conditional effect selection not available via this mechanism.", "Try trigger-setter binding."),
 (14, "trigger-effect-setter", "Trigger-setter CLR write", "A DataTrigger setter with an OWTS binding pushes a default value.", "S", ["probes/D3-trigger-binding-effect.xaml"],
  "binding pushed its own empty value, not the style default.", "blocked", "Second mechanism failed: conditional effect selection by triggers closed.", "EF probe."),
 (15, "ef-core-first-try", "EF Core from XAML (no model)", "DbContext can be constructed from XAML.", "P: Microsoft.EntityFrameworkCore 10.0.14", ["probes/F2-ef-core.xaml", "probes/F2-ef-core-ctx-fail.xaml.txt"],
  "UseSqlite and get_Options worked; new DbContext(options) failed because x:Arguments received the provider. (F3/F4 in iteration 16 showed ODP ConstructorParameters do not unwrap either.)", "blocked",
  "Superseded by the EF composition (follow-up J1).", "Carrier experiment."),
 (16, "carriers", "Mutable carriers for dynamic data", "Parameters evaluated at call time + by-reference arrays can carry dynamic data between calls.", "S and P (see compositions)", ["probes/H1-carrier-to-sqlite.xaml", "probes/H2-carrier-datatable-sum.xaml", "probes/F3-ef-odp-ctor.xaml", "probes/F4-odp-ctor-semantics.xaml", "strict-built-in/program.xaml", "package-backed-pure/program.xaml"],
  "H1: seeded draw 16 reached SQLite. H2: four draws -> XML carrier -> DataTable.ReadXml -> Compute('Sum(h)')=53. Strict composition: prefix sums, DataView RowFilter guard, WriteXml on a pool thread, byte-identical XML across runs. Package composition: 16,11,11,15 = 53 h in SQLite. Several sub-probes under one hypothesis (budget stretch disclosed).", "pass",
  "XAML: sequence, state (carriers), guard (RowFilter / SQL WHERE). Runtime/BCL: Random, Encoding, DataTable, DataView. Package: SQLite.", "Raw typed values; EF."),
 (17, "raw-typed-values", "Carriers to raw typed values (follow-up H3)", "A raw node declared after the carrier writers sees the filled carrier.", "S", ["probes/H3-carrier-to-raw-typed.xaml"],
  "String(char[]) + Double.Parse produced a raw System.Double equal to the draw (CompareTo(15.5)=1 for 16).", "pass", "Document-order construction semantics; BCL parsing.", "EF composition."),
 (18, "localappdata-redirect", "Isolating the baseline context (follow-up I1)", "LOCALAPPDATA can redirect Environment.GetFolderPath.", "S", ["probes/I1-localappdata.xaml"],
  "GetFolderPath(LocalApplicationData) returned the real path with and without the env override. Enum parameters need x:Static Member=\"sys:Environment+SpecialFolder.X\".", "blocked", "Owner approved a copy with changed DB folder.", "Build EF composition."),
 (19, "ef-composition", "EF Core composition (follow-up J1)", "With an instantiable existing model/context, EF Add/SaveChanges can be driven from XAML with seeded values.", "P: EF Core 10.0.14; existing types DemoTimeCard/DemoTimeCardContext (owner-approved copy: internal->public, DB folder)", ["package-backed-ef/program.xaml", "package-backed-ef/model/DemoTimeCard.cs", "package-backed-ef/model/DemoTimeCardContext.cs"],
  "4 cards 16/11/11/15 = 53 h, year 2026 week 46, via TimeCards.Add x4 and SaveChanges; SQL trigger guard live (threshold 30 keeps 3). Runs identical on net10 and net11. Baseline LOCALAPPDATA untouched.", "pass",
  "XAML: orchestration, state, guard text. Package: EF Core/SQLite. Existing types: entity + context only.", "Final report."),
 (20, "net11-compat", ".NET 11 compatibility", "Baseline and compositions run on net11.0-windows with SDK 11.0.100.", "S/P/EF", ["evidence/runs/net11-a-strict/trace.txt", "evidence/runs/net11-a-pkg/db-dump.txt", "evidence/runs/net11-a-ef/db-dump.txt", "tools/collect_evidence.sh"],
  "Unmodified baseline copy retargeted to net11.0-windows built; EF Core 10.0.14 packages restored and worked. Host + model rebuilt for net11. All three compositions and probes B1, C4, D1, H2, H3 gave identical results to net10: Random(42) sequence 16,11,11,15,11; total 53; strict XML sha256 94ac35b9...; identical DB rows; animation active (g.Opacity ~0.655 at 700 ms).", "pass",
  "Platform compatibility only; no semantic change observed.", "Status: compatible (EF Core 10.0.14 on net11 not an officially matched pairing; observed working).")
]

os.makedirs("evidence", exist_ok=True)
idx = ["# Iteration index (plan section 5 template)", "",
       "Each note follows the plan's template. Numbering: 1-16 are the original loop budget; 17-20 are owner-requested follow-ups (H3, I1, J1, .NET 11). Narrative history, including superseded designs, remains in `iteration-log.md`.", ""]
for (i, slug, title, hyp, grade, files, obs, cls, own, nxt) in IT:
    name = f"iteration-{i:02d}-{slug}.md"
    ev = "\n".join(f"- `{f}` sha256 `{sha(f)}`" for f in files) or "- (none)"
    body = f"""# Iteration {i}: {title}

## Hypothesis
{hyp}

## Grade and allowed types/packages
{grade}

## Smallest probe
{', '.join(files) if files else 'see iteration-log.md'}

## Command(s) and environment
`{CMD}` with host {HOST}.
Environment: {ENV}.
Compositions: `./run.ps1 <grade> <fresh-id>`; `tools/collect_evidence.sh` for the final runs under `evidence/runs/`.

## Observed result (include exception type/message and relevant stack-frame names)
{obs}

## Evidence paths and hashes
{ev}

## Classification: pass | partial | blocked | invalid-by-constraint
{cls}

## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
{own}

## Next action or stop reason
{nxt}
"""
    open(os.path.join("evidence", name), "w", encoding="utf-8").write(body)
    idx.append(f"- [{i}. {title}]({name}) - **{cls}**")
open("evidence/iterations.md", "w", encoding="utf-8").write("\n".join(idx) + "\n")
print("wrote", len(IT), "iteration notes")
