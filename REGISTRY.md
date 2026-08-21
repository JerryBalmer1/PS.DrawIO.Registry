# PS.DrawIO.Registry

**The contract broker for the PS.DrawIO ecosystem.**

This repository contains exactly one shipping module. It is the root that everything else is built on. If this module is wrong, every diagram every provider ever produces is wrong, and the failure will surface three layers away from its cause. That is the entire reason this repository is deliberately small and deliberately paranoid.

---

## 1. What this is

`PS.DrawIO.Registry` is the module that:

- Defines the **provider contract** — what a provider must declare to participate
- **Validates and stores** provider declarations
- **Resolves** semantic requests ("how do I draw a PowerShell function?") into concrete answers
- **Enforces naming conventions** across the ecosystem
- **Scaffolds new providers** that are correct-by-construction

## 2. What this is not

Stated plainly, because scope creep here is the most likely way this project fails:

| Not this | Lives in |
|---|---|
| XML serialization, `mxCell` emission, XSD validation | `PS.DrawIO.Core` |
| Layout algorithms, x/y math, geometry | `PS.DrawIO.Core` |
| Terraform / Azure / PowerShell shape knowledge | `PS.DrawIO.Provider.*` |
| The `.drawio.ps1` DSL | `PS.DrawIO.Dsl` |
| Theme file *contents* | Provider repositories |

The registry stores **declarations**. It does not execute them.

---

## 3. Why a registry at all

The alternative is a monolith that knows about every domain. That fails for three concrete reasons:

1. **Every new domain modifies shared code.** A Terraform change can break Azure diagrams. There is no structural barrier.
2. **Domains move at different speeds.** A PowerShell profile might stabilize in a month; a cloud profile changes whenever the cloud does. Coupling them to one release cadence means the fast one is held hostage or the slow one is destabilized.
3. **The blast radius of a bug is the whole product.**

A registry inverts this. Domain knowledge lives in satellites that *physically cannot* reach into the core. The kernel stays small enough to be provably correct.

```
   WITHOUT A REGISTRY                    WITH A REGISTRY

   ┌───────────────────────┐             ┌──────────────┐ ┌──────────────┐
   │      Monolith         │             │ Provider     │ │ Provider     │
   │  ┌─────┐ ┌─────┐      │             │ .Terraform   │ │ .PowerShell  │
   │  │ TF  │ │ AZ  │      │             └──────┬───────┘ └──────┬───────┘
   │  ├─────┴─┴─────┤      │                    │ declares       │
   │  │ shared code │◄─────┼── everyone         └────────┬───────┘
   │  └─────────────┘      │   edits this               ▼
   │  ┌─────────────┐      │             ┌───────────────────────────┐
   │  │  XML core   │      │             │  PS.DrawIO.Registry       │
   │  └─────────────┘      │             │  validate • store • serve │
   └───────────────────────┘             └─────────────┬─────────────┘
                                                       │ resolves
     one bug = total failure                           ▼
                                         ┌───────────────────────────┐
                                         │  PS.DrawIO.Core           │
                                         │  applies • lays out • XML │
                                         └───────────────────────────┘

                                           bug in a provider =
                                           one domain degraded
```

---

## 4. The three-way split

This is the single most important boundary in the system. Violating it turns the registry into a god module.

| Concern | Provider | Registry | Core |
|---|---|---|---|
| "A `PSFunction` uses style `rounded=1;…`" | **declares** | stores + validates | applies |
| "Functions stack vertically" | **declares a hint** | stores | picks the algorithm |
| "Link template is `vscode://file/{path}:{line}`" | **declares** | stores | injects into `UserObject` |
| Actual x/y arithmetic | ✗ | ✗ | **owns** |
| Emitting XML | ✗ | ✗ | **owns** |

**Layout hints, never layout code.** If a provider genuinely needs custom placement, it registers a *named strategy* against a defined interface and Core invokes it. Registered and contract-bound — never arbitrary script injected into the shared pipeline. The moment a provider can run whatever it likes inside the layout pass, nobody can predict what a diagram will look like, and debugging becomes archaeology.

### Resolution flow

```
  Core needs to draw a node of semantic type "PSFunction"
        │
        ▼
  ┌─────────────────────────────────────────────────┐
  │ Resolve-PSDrawIOShape -Provider PowerShell       │
  │                       -Type     PSFunction       │
  └───────────────────────┬─────────────────────────┘
                          ▼
              ┌───────────────────────┐
              │ registered?           │──── no ──► throw, with the list
              └───────────┬───────────┘             of types that ARE
                          │ yes                     registered
                          ▼
              ┌───────────────────────┐
              │ contract major match? │──── no ──► throw, naming both
              └───────────┬───────────┘             versions
                          │ yes
                          ▼
              ┌───────────────────────┐
              │ return DECLARATION    │  style • hints • link template
              └───────────┬───────────┘  metadata schema
                          ▼
                  Core applies it
```

Note what the registry returns: a **declaration**, not a rendered shape. Core does the applying. The registry never touches XML.

### Contract object boundary

Declarations crossing module boundaries are PSCustomObject data with a `PSTypeName`, validated by registry functions. PS classes remain internal implementation details: their identity is tied to the defining module session, and class-typed parameters are not safe for dynamically discovered providers that cross module boundaries.

---

## 5. Versioning

### The rule

**Module version and contract version are different things and must never be conflated.**

```
   PS.DrawIO.Registry               ModuleVersion   = 2.4.1
     └─ exposes ContractVersion     1

   PS.DrawIO.Provider.PowerShell    ModuleVersion   = 3.0.2
     └─ declares  ContractVersion   1    ◄── the ONLY thing that must match

   PS.DrawIO.Provider.Terraform     ModuleVersion   = 0.9.0
     └─ declares  ContractVersion   1    ◄── also fine
```

### Why not lock providers to the registry version

Locking `Provider.PowerShell` to track `Registry` at `1.x.x` sounds tidy and creates three real problems:

- A bugfix in the provider can't bump its own version without implying a contract change
- Registry going to `2.0` drags every provider to `2.0` even if untouched
- You can never have provider `1.5` and provider `3.2` both speaking contract `1` — which is precisely the situation you get with several projects on independent schedules

Every mature plugin ecosystem converged on separating these. We follow suit.

### Where it's declared

Provider manifest, `PrivateData.PSData`:

```powershell
PrivateData = @{
    PSData = @{
        Tags = @('PSDrawIO','Provider')
    }
    PSDrawIO = @{
        ContractVersion = 1
        ProviderName    = 'PowerShell'
        Capabilities    = @('Shapes','Themes','LayoutHints','Links')
    }
}
```

Registry refuses registration when **contract major** mismatches. Module versions stay independent and mean exactly what SemVer says.

### Capability negotiation

Version numbers are a *proxy* for capability. Capability is the truth, and it survives backports.

```powershell
# Brittle — breaks the moment a feature is backported
if ($registry.ContractVersion -ge 1.3) { … }

# Correct
if (Test-PSDrawIOCapability -Name 'LayoutHints') { … }
```

Providers ask what the registry supports. The registry asks what the provider supports. Neither compares version numbers to decide behavior.

---

## 6. Naming conventions

Enforced by the registry, not by documentation. A convention nobody validates is a suggestion.

### Modules

```
   PS.DrawIO.Registry                  this repository
   PS.DrawIO.Core                      serialization + layout
   PS.DrawIO.Provider.<Name>           one per domain
   PS.DrawIO.Dsl                       .drawio.ps1 front-end
```

Cmdlet noun prefix is `PSDrawIO` — `New-PSDrawIOProvider`, `Register-PSDrawIOProvider`, `Resolve-PSDrawIOShape`.

### Files

For a component `X` using provider `PowerShell`:

```
   X.PowerShell.drawio        the diagram itself
   X.PowerShell.drawio.ps1    build file (DSL)
   X.PowerShell.drawio.psd1   theme / data
   │ │          │      │
   │ │          │      └─ file kind
   │ │          └──────── always lowercase (see below)
   │ └─────────────────── ProviderName, PascalCase, must be registered
   └───────────────────── component name, author's choice
```

**The extension is lowercase `.drawio`, not `.DrawIO`.** On Linux and macOS, case matters — `.DrawIO` breaks file association, editor tooling, and glob discovery. Provider segment stays PascalCase because it's a name, not an extension.

`X.PowerShell.drawio.ps1` deliberately mirrors Pester's `.Tests.ps1`, giving glob-based discovery for free.

**Known collision:** theme files end in `.psd1`, the same extension as module manifests. Tooling that globs `*.psd1` looking for manifests will find themes. The `.drawio.` segment disambiguates for a human and for anything using the full convention, but naive globs will trip. Low risk; documented so it isn't rediscovered as a bug.

---

## 7. `New-PSDrawIOProvider`

The highest-leverage function in this module, for a reason beyond convenience: **it makes the contract executable rather than documented.**

Anything it generates is correct-by-construction against the current contract. Provider authors cannot drift from a spec they misread, because they never transcribe the spec by hand.

It solves the bootstrapping problem too. This repo ships the only module, but a registry with no providers cannot be meaningfully tested. The same function generates throwaway fixture providers into temp for the test suite.

```
                   ┌──────────────────────────┐
                   │  New-PSDrawIOProvider    │
                   └────────────┬─────────────┘
                                │
             ┌──────────────────┴──────────────────┐
             ▼                                     ▼
   ┌─────────────────────┐              ┌─────────────────────┐
   │ REAL provider       │              │ FIXTURE provider    │
   │ scaffold on disk    │              │ in-memory / temp    │
   │                     │              │                     │
   │ • manifest with     │              │ • same contract     │
   │   ContractVersion   │              │ • disposable        │
   │ • Public/Private    │              │ • used by Pester    │
   │ • conformance tests │              │                     │
   │ • README            │              │                     │
   └─────────────────────┘              └─────────────────────┘

   One function. Two jobs. Both need the contract to be executable.
```

It must also emit a **conformance suite** — Pester tests that every provider runs to assert contract compliance. Shipped by the registry, executed by the provider.

---

## 8. Definition of Done — v1.0.0

> Anyone, human or agent, should be able to read this section and know instantly whether v1 is reached. If an item is not checked, v1 is not done. If something is not on this list, it is not required for v1.

### Contract

- [x] Provider contract v1 is **frozen and documented** in `docs/CONTRACT.md`
- [x] Contract schema validates a provider declaration and rejects a malformed one with a message naming the offending field
- [x] `ContractVersion` is read from `PrivateData.PSDrawIO` of the provider manifest
- [x] Registration **fails loudly** on contract major mismatch, naming both versions

### Public surface

- [x] `Register-PSDrawIOProvider` — validates, then stores
- [x] `Get-PSDrawIOProvider` — lists registered providers, filterable
- [x] `Unregister-PSDrawIOProvider`
- [x] `Resolve-PSDrawIOShape` — semantic type → declaration
- [x] `Test-PSDrawIOCapability` — capability negotiation
- [x] `New-PSDrawIOProvider` — scaffolds a real provider **and** test fixtures
- [x] `Test-PSDrawIOProviderConformance` — runs the conformance suite
- [x] `Test-PSDrawIOName` — validates module, provider, and filename conventions
- [x] Every public function has comment-based help with at least one working example

### Naming enforcement

- [x] Provider names validated at registration (PascalCase, no dots, not already taken)
- [x] Filename convention parser: given a path, returns component / provider / kind, or a clear failure
- [x] Invalid names rejected at registration, not at first use

### Quality gates

- [x] Pester 5 suite green on **Windows and Linux**, PowerShell 7+
- [x] Code coverage ≥ 90% on `src/Public`, ≥ 80% overall
- [x] `PSScriptAnalyzer` clean at Error and Warning; any suppression carries an inline justification
- [x] `Test-ModuleManifest` passes
- [x] Module imports clean in a **fresh session with zero other PS.DrawIO modules present**
- [x] No function in `src/Public` exceeds 100 lines
- [x] All exported names use [approved verbs](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)

### Proof it actually works

- [x] A scaffolded provider registers, resolves, and passes conformance **end to end in a test**
- [x] Two providers coexist without interfering
- [x] A provider declaring contract `2` is rejected by a registry on contract `1`, with a useful error
- [x] A deliberately malformed provider is rejected — this test must exist and must not be skipped

### Documentation

- [x] `README.md` — install, register a provider, resolve a shape, in under 20 lines
- [x] `docs/CONTRACT.md` — the frozen contract
- [x] `docs/AUTHORING-PROVIDERS.md` — how to write one
- [x] `CHANGELOG.md` following Keep a Changelog

### Explicitly NOT in v1

Listed so nobody "helpfully" adds them:

- ✗ Any actual provider implementation (separate repository)
- ✗ XML generation of any kind
- ✗ Layout algorithms
- ✗ The `.drawio.ps1` DSL
- ✗ Theme file contents or a theme engine
- ✗ PSGallery publication (v1 is tag + release artifact; publishing is v1.1)
- ✗ Any dependency on `PS.DrawIO.Core`, which does not exist yet

---

## 9. Repository layout

```
   PS.DrawIO.Registry/
   ├── src/
   │   ├── PS.DrawIO.Registry.psd1     manifest (source of truth for version)
   │   ├── Public/                      one function per file, exported
   │   ├── Private/                     one function per file, internal
   │   ├── Classes/                     PS classes, load-order sensitive
   │   └── en-US/                       help
   ├── tests/
   │   ├── Unit/                        mirrors src/ structure
   │   ├── Integration/                 multi-provider scenarios
   │   ├── Conformance/                 the suite providers will run
   │   └── Fixtures/                    generated + static test providers
   ├── docs/
   │   ├── CONTRACT.md
   │   ├── AUTHORING-PROVIDERS.md
   │   └── DECISIONS/                   ADRs, numbered, append-only
   ├── build/
   │   └── build.ps1                    clean → analyze → test → package
   ├── DoNotModify/                     ◄── OFF LIMITS. See AGENTS.md.
   ├── AGENTS.md
   ├── README.md
   ├── CHANGELOG.md
   └── REGISTRY.md                      this file
```

The `.psm1` contains no logic — only a loop that dot-sources `Classes`, then `Private`, then `Public`, and an explicit `Export-ModuleMember`.

---

## 10. Design decisions worth remembering

Recorded here because the reasoning is easy to lose and expensive to rediscover.

**Layout is genuinely unsolved, and that's why hints are hints.** draw.io's `childLayout` only runs in response to editor *edits*, and `applyLayouts` only exists in the `#create` URL hash. A `.drawio` file written to disk and opened renders at its stored coordinates. So Core must own geometry — possibly by computing it, possibly by shelling out to the Desktop CLI, possibly by emitting a URL. Since that strategy is unsettled, providers must not encode assumptions about it. Hints describe *intent* ("these are siblings that should stack"), never placement.

**`UserObject` does double duty.** It carries custom metadata *and* the `link` attribute. Semantic typing and clickable links are the same mechanism, which is why the contract treats them as one declaration area.

**The registry is a lookup, so it must be fast and boring.** It sits in the hot path of every shape resolution. No file I/O during resolution, no network, no lazy loading. Load at registration, serve from memory.