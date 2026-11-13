# Pure Runtime-WPF-XAML Challenge: Exploratory Ralph-Loop Plan

**Status:** ready for agent execution  
**Baseline:** `dullroar/code-challenge` C# modernization (`net10.0-windows` WPF); use the checked-out repository, not this plan, as the source of truth.  
**Nature:** a bounded research experiment, not a production rewrite.

## Play charter

This is a “**You can DO that?**” experiment. Preserve the original challenge's play, discovery, irony, and deliberate architectural impropriety. If a working declarative-XAML-and-company solution can be made within the stated rules, the agent **must pursue and demonstrate it**; it must not retreat to conventional structure merely because a view model, service, `async` workflow, or ordinary C# would be sensible.

The evidence discipline in this plan exists to make the stunt reproducible and to expose exactly why it works—not to domesticate it into best practices. Treat professional-design guidance as out of scope except for the narrow safeguards that preserve the original demo, isolate generated data, and prevent external effects. A well-evidenced, marvelous monstrosity is the preferred positive result.

## 1. Research question: a generic declarative interpreter

> Can the WPF runtime-XAML machinery act as a **generic declarative interpreter**: accept a hunk of XML as its program, interpret it at runtime, and execute the demo's data, state transitions, effects, and termination—without transferring the algorithm into custom executable glue?

`XamlReader` already interprets XML into an object graph. This experiment tests whether the standard WPF/.NET object, binding, lifecycle, and invocation semantics amount to a useful execution vocabulary rather than merely a UI-description format. The time-card demo is a **benchmark program**, not the end in itself.

The required execution chain is:

```text
runtime XAML program
  → construct objects and data
  → invoke permitted framework/package operations
  → observe and change state
  → select and trigger the next transition
  → perform bounded effects
  → reach and expose a terminal state
```

The central audit question in every phase is: **Does the XML encode this behavior generically, or does a precompiled application-specific type already embody the algorithm?** A document that instantiates `RunEverything` (or its moral equivalent) is configuration over a hidden interpreter, not a success.

This plan deliberately separates two claims.

| Grade | Definition | May it claim “pure XAML”? |
|---|---|---|
| **Strict built-in pure runtime XAML** | All demo-specific runtime behavior is represented by loaded XAML plus unmodified built-in .NET/WPF runtime types. No application-specific compiled types, code-behind, helper methods, converters, markup extensions, custom controls, macros, generators, or hidden dispatcher. | Yes, but only if every required behavior passes. |
| **Package-backed pure declarative XAML** | All *application-specific* behavior is expressed in runtime-loaded XAML. Existing, unmodified baseline package types (including EF Core/SQLite) and already-present model types may be composed only through their public declarative/configurable surface. No new helper, mapper, converter, code-behind, or “do it all” dispatcher is permitted. | Yes, with the qualified label “package-backed pure declarative XAML.” |
| **Constrained declarative orchestration** | Runtime XAML owns composition and observable sequencing, but a narrowly documented imperative capability remains outside XAML. No new application-specific “do it all” method or type may be introduced. | No—call it constrained declarative orchestration. |
| **Negative result** | A required capability cannot be induced under the stated grade after bounded, independent probes. | Yes: this is a successful research outcome, not a failed loop. |

**Provenance is independent of declarative purity:** SQLite is not a .NET/WPF built-in persistence engine, so EF Core/`Microsoft.Data.Sqlite` must not be described as *built-in*. That does **not** rule out a pure-declarative-XAML result: the package-backed track explicitly tests whether runtime XAML can use the pre-existing EF/SQLite stack without new application code. A result using an existing provider is qualified by provenance, not downgraded automatically to constrained orchestration. Only an imperative capability outside XAML makes it constrained.

**Genericity is also independent of provenance:** EF Core and SQLite may be package-backed effect targets, while the interpreter/program claim depends on where the workflow semantics reside. A package-backed result can still be declaratively pure if XAML carries the application-specific state machine and uses EF only through generic public operations. Conversely, a built-in-only solution fails the genericity test if a custom or preconfigured type hides the workflow.

## 2. Up-front questions (defaults permit autonomous start)

Answer these before starting if any default is unacceptable. Otherwise record the defaults in the experiment manifest and proceed.

| Question | Default | Why it matters |
|---|---|---|
| Where is the authoritative checkout? | Locate the `dullroar/code-challenge` checkout; if absent, stop before cloning or modifying anything. | Avoids treating a copied artifact as canonical. |
| Experiment isolation | New branch `experiment/pure-runtime-wpf-xaml` and new top-level path `experiments/pure-runtime-wpf-xaml/`. If the worktree is not a Git repo, create only the new path and record that branch isolation was unavailable. | Preserves original behavior. |
| Target framework order | Establish `net10.0-windows` first; investigate `net11.0-windows` only if an SDK and WPF targeting pack are actually installed. | .NET 11 support must be observed, not presumed. |
| Runtime-load definition | The experiment must parse/load the app behavior with `XamlReader` at runtime from a non-compiled `.xaml` file or an explicitly recorded string/file payload. | Prevents compiled BAML from being counted as runtime XAML. |
| Test execution | Automated build plus deterministic non-interactive probes; optional visible WPF smoke test only when an interactive desktop is available. | CI agents may lack a desktop session. |
| Database location | Per-run database under the experiment artifact directory, never the baseline demo database or any real time-reporting location. | Maintains demo-only safety. |
| Loop budget | 16 iterations total, maximum 2 attempts per unique mechanism/capability pair, and maximum 20 minutes per iteration excluding build restore. | Makes the loop finite and auditable. |

## 3. Non-negotiable constraints

1. Do not alter the original demo project, its default behavior, or its database path. Do not change its packages to make an experiment easier.
2. All generated records remain clearly named `Demo*`; no credentials, external systems, network access, employer/time-reporting data, or real identity data.
3. Treat baseline behavior as a regression oracle: generated bounded pseudo-random hour cards, persistence attempt, animated WPF window, and a background-thread-equivalent concern must remain observable in the experiment or be explicitly marked blocked.
4. Strict-track source must contain no new C# application code, code-behind, helper assembly, converter, markup extension, custom control, source generator, reflection dispatcher, macro, or `runEverything`-style delegation. Existing baseline types may be *read* for behavioral reference but are not permitted in strict runtime execution.
5. Do not count a method invocation as success merely because a custom method is invoked from `ObjectDataProvider`. The invoked target must be an unmodified built-in WPF/.NET runtime type in strict mode.
6. Do not evade the constraint through `Process`, shell commands, compiled XAML/BAML, serialized delegates, `x:Code`, dynamic compilation, external scripts, or pre-seeded data that performs the algorithm outside the XAML runtime.
7. Do not weaken a failing acceptance criterion. Record a blocker or open a separately labelled constrained-track hypothesis instead.
8. The runtime XAML must encode the demo-specific sequencing, branching/termination, and state transitions. Existing types may provide generic mechanisms or infrastructure, but may not embed a time-card-specific workflow, state machine, or dispatcher.
9. Do not substitute ordinary “best practice” application architecture for an available declarative route. An ugly but working, rule-compliant runtime-XAML mechanism is a success; an idiomatic rewrite is not an answer to this challenge.

## 4. Baseline characterization (iteration 0)

Before changing anything, inspect and run the source checkout. Capture the facts rather than trusting this plan. The known modernization artifact should be checked for these expected properties:

- SDK-style WPF executable targeting `net10.0-windows`.
- A one-statement, empty-body `for` in `Program.Main`.
- Runtime XAML loaded through `XamlReader.Load`, including animation.
- Demo-only time-card generation and local EF Core/SQLite persistence.
- A named mutex, a background `Thread`, and reflection retained as comparison mechanics.

Write `evidence/00-baseline.md` with commit SHA, OS, `dotnet --info`, installed SDKs, project/package inventory, baseline build command/result, baseline database location/schema, and each observed behavior. Copy no databases containing prior data; use a fresh run-specific output location where configuration permits.

## 5. Experiment layout and evidence contract

Create only the isolated experiment path:

```text
experiments/pure-runtime-wpf-xaml/
  README.md
  manifest.json
  strict-built-in/
  package-backed-pure/
  constrained/
  probes/
  evidence/
    00-baseline.md
    iteration-01-*.md
    capability-matrix.md
    toolchain.md
    final-report.md
  artifacts/
    run-<utc-timestamp>/
```

`manifest.json` must include: baseline commit, experiment commit/branch, active framework, SDK version, package inventory, selected grade, RNG seed, database path, test commands, start/end UTC timestamps, and a hash for each runtime XAML input.

Each iteration note must state:

```markdown
## Hypothesis
## Grade and allowed types/packages
## Smallest probe
## Command(s) and environment
## Observed result (include exception type/message and relevant stack-frame names)
## Evidence paths and hashes
## Classification: pass | partial | blocked | invalid-by-constraint
## Semantic ownership: what is encoded in XAML; what is supplied generically by the runtime/package; what, if anything, is hidden outside XAML
## Next action or stop reason
```

Record negative results with the same care as passing results. Screenshots are supplementary; build logs, test output, XAML input, output database inspection, and hashes are primary evidence.

## 6. Capability matrix and completion states

Maintain this matrix after every iteration. “Pass” means demonstrated from runtime-loaded XAML under the specified grade, not merely believed possible.

| Capability | Strict built-in | Package-backed pure | Constrained | Required evidence |
|---|---:|---:|---:|---|
| Runtime XAML load and object graph | pending | pending | pending | parser/load probe and input hash |
| Window composition | pending | pending | pending | automated object-graph assertion; optional screenshot |
| Animation | pending | pending | pending | storyboard active/property changed evidence |
| Framework method invocation | pending | pending | pending | direct provider/binding probe and result |
| Object creation/collection mutation | pending | pending | pending | runtime object graph/collection observation |
| Generic state transition/retriggering | pending | pending | pending | transition trace, XAML semantic-ownership audit, bounded termination |
| Deterministic random-card equivalent | pending | pending | pending | seeded output trace and bounds |
| Persist to SQLite | pending | pending | pending | database file, schema/query output, provenance |
| Threading/background work | pending | pending | pending | thread identity/dispatcher trace; UI safety proof |
| Clean termination and repeatability | pending | pending | pending | two isolated runs with bounded completion |

## 7. Ralph loop protocol

Perform one capability-sized hypothesis per iteration. Do not attempt the full application until the corresponding component probes have passed.

```text
while budget remains and no escalation condition applies:
  select the highest-priority unresolved capability
  formulate one falsifiable hypothesis using one named built-in mechanism
  create the smallest isolated runtime-XAML probe
  statically audit it against strict constraints
  build and execute deterministic automated checks
  capture evidence and update the matrix
  if pass: integrate only into that grade's minimal composition harness
  if partial/blocked: classify the blocker, mark the mechanism attempted,
      and choose a materially different mechanism—or close the capability
  if the same mechanism/capability pair has failed twice: do not retry it
end
```

Priority order:

1. Toolchain and runtime loading.
2. Visual composition and animation.
3. Built-in object construction and method invocation.
4. State representation, transition, and re-trigger semantics.
5. Deterministic card generation and termination condition.
6. SQLite feasibility/provenance (run early enough to avoid false “pure” claims).
7. Threading/background-work feasibility and UI-affinity behavior.
8. Integrated strict-built-in attempt; then package-backed-pure attempt; then constrained orchestration only where a remaining imperative capability is documented.

## 8. Autonomous phases and specific probes

### Phase A — Toolchain and framework compatibility

1. Capture `dotnet --list-sdks`, `dotnet --info`, project `TargetFramework`, and WPF build results.
2. Build the untouched baseline at `net10.0-windows`.
3. For .NET 11, first check whether a compatible SDK and `net11.0-windows` reference pack exist. Only then make a **copy in the experiment path** with `TargetFramework` changed, restore/build it, and record exact errors or success. Do not install SDKs/packages or claim compatibility from version names.
4. If .NET 11 is unavailable, record `not evaluated: toolchain absent`, continue the .NET 10 experiment, and do not treat it as a program failure.

### Phase B — Runtime XAML, visual graph, and animation

Create a minimal XAML payload loaded with `XamlReader` at runtime. Prove that it constructs a `Window`/visual tree and starts a built-in `Storyboard`/animation via supported WPF lifetime mechanisms. Prefer observable dependency-property changes or storyboard state over a human-only screen inspection.

Reject any solution that moves animation initialization into a new code-behind event handler or custom attached behavior.

### Phase C — Declarative side effects: object construction and invocation

Probe standard mechanisms independently, documenting the actual supported behavior and restrictions in the target runtime:

- `ObjectDataProvider` construction/method invocation and refresh timing.
- `EventTrigger`, `BeginStoryboard`, and property/data triggers.
- `Binding`, `MultiBinding`, resources, `x:Shared`, and collection/object construction as applicable.
- Built-in routed commands only if a real source and target can be established without custom command implementations.

For each probe, document whether it executes at parse time, load time, activation, data-binding evaluation, or event time. Method invocation alone is not sequencing; demonstrate timing and repeatability.

### Phase D — Generic state machine, recurrence, and interpreter boundary

Attempt a visibly declarative finite-state model first: named states, dependency-property changes, trigger-driven transitions, and a traceable terminal state. Define the maximum number of transitions before testing. Treat the XAML document as the candidate program and WPF's standard object/lifecycle semantics as the candidate interpreter.

Pass only if the mechanism can: (a) represent current state, (b) advance after an observable event/change, (c) select a next transition from document-encoded conditions, (d) stop at a terminal condition, and (e) avoid uncontrolled reentrancy. The evidence must identify the generic interpreter mechanism and point to the XML element/attribute encoding each demo-specific transition. If arbitrary arithmetic, comparison, mutable application state, or event re-triggering requires custom code/conversion, mark strict blocked with the exact missing primitive.

Do not count a state type whose constructor, callback, property setter, or method already knows the time-card workflow. That moves the program from XML into a precompiled interpreter extension. Record such designs as `invalid-by-constraint`, even if they appear declarative at the XAML call site.

### Phase E — Random time cards and reproducibility

The baseline uses `Random.Shared`; strict reproducibility requires a controllable seed or a faithfully documented reason it cannot be seeded from XAML. Do not call non-deterministic output a test pass.

Explore only standard types/methods that can demonstrably be invoked from the allowed XAML mechanism. Validate: card values are within declared demo bounds, totals progress toward the terminal threshold, and two runs with the same seed produce the same trace. If use of `Random.Shared` cannot be seeded or sequenced declaratively, retain the baseline behavior only in the constrained track and label it non-reproducible unless an alternative is proven.

### Phase F — SQLite persistence feasibility, provenance, and safety

First establish type provenance: inventory all loaded assemblies/packages. If a SQLite provider is required, it cannot satisfy the **strict built-in** grade unless the platform demonstrably supplies it. That is a provenance result, not a claim that EF/SQLite cannot be driven from XAML.

Then run the **package-backed pure declarative** probe before considering a constrained fallback. Retain only the baseline's existing EF Core/SQLite package versions and model types—do not add a helper layer—and create a fresh experiment database. Test whether runtime-loaded XAML can construct/configure the provider/context/model objects and initiate `Add`/`SaveChanges` through an allowed standard WPF mechanism such as `ObjectDataProvider`. Prove that the XAML input itself owns the orchestration by tracing construction, invocation, and resulting rows. Existing `DbContext`/entity types make the result package-backed rather than built-in; they make it constrained only if a custom method, code-behind handler, or external imperative sequencer performs the application workflow.

Never point a probe at the baseline `%LOCALAPPDATA%` database. Query the experiment database after each run and archive a schema/query transcript with a hash; records must retain a prominent demo marker.

### Phase G — Threading and WPF affinity

First clarify the requirement: “background thread” may be satisfied only by a verifiable background execution path, not merely an asynchronous animation. Use built-in threading primitives only in strict mode. Prove thread identity, apartment/dispatcher relationship where applicable, and that UI objects are not accessed from the wrong thread.

If XAML can construct a type but cannot safely start/sequencing background work without an executable callback, record the strict blocker rather than introducing one. In the constrained track, any remaining baseline thread/reflection code is an explicit exception and must not be described as XAML-owned behavior.

### Phase H — Integration and comparison

Integrate only independently passed capabilities. Maintain three separate executable/minimal compositions: `strict-built-in/`, `package-backed-pure/`, and `constrained/`; never mix their evidence or let a lower-grade dependency leak into a higher-grade claim. Each integration must include a concise semantic-ownership map: XML-program constructs, generic interpreter/runtime constructs, package-backed effect targets, and any rejected hidden-workflow path.

Run each composition twice with isolated artifact roots. Compare expected state traces, database results, termination, build output, and constraint audits. A partial strict composition is valuable; do not introduce an escape hatch merely to complete the demo.

## 9. Build, test, and audit commands

The executing agent must fill in exact repository-relative project paths after discovery. It must record rather than invent commands. At minimum, preserve outputs for:

```powershell
dotnet --info
dotnet --list-sdks
dotnet restore <experiment-project>
dotnet build <experiment-project> -c Release
dotnet test <experiment-project-or-test-project> -c Release --no-restore
```

Add deterministic probe invocations with an explicit seed and artifact root. If GUI execution cannot run headlessly, test the runtime XAML load and its object graph in STA-capable automated tests; label visible-window validation as not executed rather than asserting it passed.

Before every claimed strict pass, run a static constraint audit over the experiment path for prohibited constructs and manually inspect hits. The audit must include `.cs`, `.xaml`, project files, generated-output exclusions, and package references. Keep the exact search patterns/result in evidence; do not use an absence-of-text search as the only proof.

## 10. Stop, escalation, and refusal-loop rules

Stop and ask the owner before:

- cloning, downloading SDKs/packages, changing the global environment, or adding a new dependency;
- changing the baseline project or its persistence location;
- using a database outside the isolated artifact root;
- weakening strict definitions or allowing a custom helper/framework not listed here;
- needing credentials, network access, a real database, or a human-only UI decision;
- encountering an ambiguity that changes what counts as “built-in” or “pure.”

Stop the current capability and record a negative result when:

- two materially identical attempts fail;
- the platform lacks a required primitive (for example SQLite provider, arithmetic, event recurrence, safe background invocation);
- an exception is deterministic and attributable to an invariant API restriction; or
- the proposed next step would violate a hard constraint.

**Refusal-loop breaker:** Never rephrase the same forbidden design as a different XAML wrapper. If the next proposal depends on a custom converter, `x:Code`, code-behind, a helper method, a generated assembly, a dispatcher, shell/process execution, or a custom persistence facade, classify it `invalid-by-constraint`, cite the relevant rule, and move to either a materially different built-in mechanism or the constrained track.

## 11. Acceptance criteria

The experiment is complete when all items below are delivered, regardless of whether strict pure XAML succeeds.

- Untouched-baseline evidence and an isolated branch/path with the original behavior preserved.
- Verified .NET 10 results and an evidence-based .NET 11 status: `compatible`, `incompatible`, or `not evaluated: toolchain absent`.
- An updated capability matrix with evidence for every requested capability: animation, object creation, method invocation, state machine, random time cards, SQLite persistence, and threading.
- A semantic-ownership audit showing that application-specific sequencing, state, effect selection, and termination are encoded in the XAML program rather than hidden in a precompiled type.
- Separate strict-built-in, package-backed-pure, and constrained audits, source inventories, runtime-XAML hashes, deterministic test traces, and clean isolated run artifacts.
- A defensible classification of the maximum achieved built-in and package-backed behavior, plus exact blockers. No constrained result is called pure; a package-backed result must name its packages and existing model types.
- A repeatable build/test recipe that another agent can run from a clean checkout without relying on undocumented machine state (aside from explicitly documented installed SDK/desktop limitations).
- A final report written even if every hard behavior is blocked.

## 12. Required final report

Write `evidence/final-report.md` with:

1. Executive finding: maximum strict-built-in result; maximum package-backed-pure result; maximum constrained result; whether either pure-runtime-XAML grade achieved the whole demo.
2. Environment/compatibility table: OS, SDKs, framework target, WPF support observations, package inventory.
3. Capability matrix with links to per-iteration evidence.
4. Architecture diagram distinguishing the XAML program, generic interpreter/runtime semantics, package-backed effect targets, baseline/external infrastructure, and any disallowed hidden-workflow path deliberately rejected.
5. Reproducibility instructions and exact commands.
6. Safety statement confirming demo-only data, isolated database paths, and no external integrations.
7. Constraint audit and known limitations.
8. Failure taxonomy: parser/type-resolution limits, binding/trigger limits, expression/state limits, persistence-provider limits, threading/dispatcher limits, test-environment limits.
9. Recommended next experiment, explicitly labelled as either a new strict hypothesis or a scope change requiring owner approval.

Use conclusion language precisely:

- “Demonstrated in strict built-in pure runtime XAML” only for full strict-built-in passes.
- “Demonstrated as package-backed pure declarative XAML” only when XAML owns application-specific orchestration and every non-built-in package/model dependency is named.
- “Demonstrated as constrained declarative orchestration” when an imperative capability remains outside XAML.
- “Not demonstrated” or “blocked by <specific primitive>” for negative results.

## 13. Agent handoff instruction

Act as a playful research executor, not a best-practices feature implementer. Favor small falsifiable probes over clever monoliths, then integrate every rule-compliant mechanism that works. Preserve all evidence, keep the original demo untouched, and report a well-evidenced boundary as a successful outcome. Optimize first toward a working, delightfully inappropriate declarative-XAML-and-company answer; use reproducibility to prove the stunt and to identify the WPF/XAML interpreter's instruction vocabulary and boundaries under each grade. Do not “improve” the challenge by replacing its successful weirdness with conventional architecture.

