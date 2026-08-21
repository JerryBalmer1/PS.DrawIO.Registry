# ADR 0002: Node and Edge Declaration Kinds

## Status
Accepted (defect recorded; contract v1 unchanged)

## Context
Registry contract v1 models provider visual vocabulary as one opaque map:

> `Shapes` maps semantic type names to opaque declaration data; the registry stores it and never renders XML or performs layout.
>
> — `docs/CONTRACT.md` (Registry `53cd0bb` / tag `v1.0.0`)

Registration validation treats every entry the same. `ConvertTo-PSDrawIODeclaration` only rejects blank keys or null values:

```powershell
foreach ($shapeType in $shapes.Keys) {
    if ([string]::IsNullOrWhiteSpace([string]$shapeType) -or $null -eq $shapes[$shapeType]) {
        throw "Provider declaration field 'Shapes' contains an invalid shape entry."
    }
}
```

— `src/Private/ConvertTo-PSDrawIODeclaration.ps1` (Registry `53cd0bb`)

There is no `NodeTypes` / `EdgeTypes` field, no required kind discriminator, and no property schema that distinguishes identity/layout declarations from relationship declarations.

Providers still need both kinds. Nodes carry identity, variants, source links, and layout hints. Edges carry relationship semantics (and sometimes edge stroke style). Forcing both into one map produces an unvalidated side-channel and blocks acceptance criteria that require separate declaration collections.

### Evidence — Provider.PowerShell (`ce5e7c13d22a77c3327c325d8e3e1908fd2c1935`)

Manifest `PrivateData.PSDrawIO.Shapes` mixes four node keys and four edge keys. Edges are marked only by an ad-hoc flag the contract neither defines nor validates:

```powershell
Shapes = @{
    PSFunction = @{ Variants = @('Public', 'Private'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Functions'; Direction = 'Vertical' } }
    PSClass = @{ Variants = @('Public', 'Private'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Types'; Direction = 'Vertical' } }
    PSEnum = @{ Variants = @('Public', 'Private'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Types'; Direction = 'Vertical' } }
    PSModule = @{ Variants = @('Public'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Module'; Direction = 'Vertical' } }
    Internal = @{ Edge = $true }
    External = @{ Edge = $true }
    Unresolved = @{ Edge = $true }
    Inherits = @{ Edge = $true }
}
```

— `src/PS.DrawIO.Provider.PowerShell.psd1`

Property presence (measured from that manifest):

| Name | Kind | Style | LinkTemplate | LayoutHints | Variants | Edge |
|---|---|---|---|---|---|---|
| PSFunction | node | no | yes | yes | yes | no |
| PSClass | node | no | yes | yes | yes | no |
| PSEnum | node | no | yes | yes | yes | no |
| PSModule | node | no | yes | yes | yes | no |
| Internal | edge | no | no | no | no | yes |
| External | edge | no | no | no | no | yes |
| Unresolved | edge | no | no | no | no | yes |
| Inherits | edge | no | no | no | no | yes |

Provider documentation recorded the limitation without inventing a second declaration source:

> The provider exposed a concrete contract limitation: node types and edge types have different properties, different validation needs, and different rendering paths, but Registry v1 models both as entries in one opaque `Shapes` collection. The resulting acceptance finding is not missing provider work; adding `NodeTypes` and `EdgeTypes` locally would duplicate declarations and create a second source of truth beside `Shapes`.
>
> Option 1 is therefore retained: keep the Registry v1 `Shapes` collection and leave the separate-declaration acceptance test failing as evidence.
>
> — `docs/PATTERNS.md`

Provider ADR 0003 chose the same option and deferred a contract change until a second provider confirmed the friction:

> Choose option 1. Do not add provider-local `NodeTypes` or `EdgeTypes`, and do not modify the Registry contract. The provider remains a faithful Registry v1 client. The acceptance failure is intentionally retained to record the contract limitation.
>
> Terraform is the next useful evidence source. If its resource nodes and dependency-reference edges exhibit the same property, validation, and rendering split, the Registry contract should be reconsidered with evidence from two providers.
>
> — `docs/DECISIONS/0003-node-edge-declaration-contract.md`

The deliberate acceptance failure asserts fields the v1 contract does not define:

```powershell
It (Get-Label 'Node types and edge types') -Tag Acceptance {
    $manifest = Import-PowerShellDataFile (Join-Path $script:providerRoot 'src/PS.DrawIO.Provider.PowerShell.psd1')
    $manifest.PrivateData.PSDrawIO.NodeTypes | Should -Not -BeNullOrEmpty
    $manifest.PrivateData.PSDrawIO.EdgeTypes | Should -Not -BeNullOrEmpty
}
```

— `tests/Acceptance/Provider.Acceptance.Tests.ps1` lines 275–278  
Label source: `PROVIDER.md` checklist item “Node types and edge types are declared separately, not merged into one collection”

CI on that commit fails **only** that test on both OS jobs:

- Run: https://github.com/JerryBalmer1/PS.DrawIO.Provider.PowerShell/actions/runs/32524363403
- HEAD: `ce5e7c13d22a77c3327c325d8e3e1908fd2c1935`
- `test (windows-latest)`: `Tests Passed: 61, Failed: 1` — sole failure `Node types and edge types are declared separately, not merged into one collection` (`Expected a value, but got $null or empty.`)
- `test (ubuntu-latest)`: same sole failure, `Tests Passed: 61, Failed: 1`

### Evidence — Provider.Terraform spike (`b7031e4bdd0081ecfe0ef78ea5f403fab755dca8`)

A declaration-only Terraform spike hit the same wall while authoring shapes. After six node entries with `Style` / `LinkTemplate` / `LayoutHints`, edge keys had nowhere to go except `Shapes`, distinguished only by the same private convention:

```powershell
ExplicitDependsOn = @{
    Edge  = $true   # ad-hoc flag — not in CONTRACT.md
    Style = 'endArrow=block;dashed=0;'
}
```

> Without some private discriminator, a consumer of `Resolve-PSDrawIOShape` cannot tell whether the returned hashtable is a node declaration or an edge declaration. Registry validation only checks that each shape entry is non-null (`ConvertTo-PSDrawIODeclaration`); it does not know or care about `Edge`.
>
> I wanted to write `NodeTypes` / `EdgeTypes`. Per spike rules I stopped. That wanting is the finding.
>
> — `docs/SPIKE-FINDINGS.md` §2

Property presence (measured from `src/PS.DrawIO.Provider.Terraform.psd1`):

| Name | Kind | Style | LinkTemplate | LayoutHints | Variants | Edge |
|---|---|---|---|---|---|---|
| TfResource | node | yes | yes | yes | yes | no |
| TfModule | node | yes | yes | yes | yes | no |
| TfVariable | node | yes | yes | yes | no | no |
| TfOutput | node | yes | yes | yes | no | no |
| TfLocal | node | yes | yes | yes | no | no |
| TfProvider | node | yes | yes | yes | no | no |
| ExplicitDependsOn | edge | yes | no | no | no | yes |
| ImplicitReference | edge | yes | no | no | no | yes |
| ModuleBoundary | edge | yes | no | no | no | yes |
| ProviderAttachment | edge | yes | no | no | no | yes |

Spike conclusion:

> **Same friction.** … Second data point confirms ADR 0003's hypothesis: this is not a PowerShell-shaped coincidence.
>
> **Registry v1's `Shapes` model should change, but not in this spike and not by provider-local forks.** … Minimum contract change for a future major: split `Shapes` into `NodeTypes` and `EdgeTypes` (or add a required kind discriminator the registry validates) … Until that major, keep v1 as-is, do **not** add parallel `NodeTypes`/`EdgeTypes` beside `Shapes` in either provider …
>
> — `docs/SPIKE-FINDINGS.md` §3 and §6

### Structural reading
Across both providers, node rows cluster on identity/layout properties; edge rows cluster on `Edge = $true` (Terraform also puts stroke `Style` on edges). The asymmetry is kind-level, not domain-specific naming. Registry v1 cannot express or validate that split.

## Decision
1. **Record the defect against contract v1.** One opaque `Shapes` map is insufficient for node versus edge declaration kinds. Two independent providers required the same unvalidated `Edge = $true` workaround.
2. **Do not change contract v1 in place.** `CONTRACT.md`, declaration parsing, and the frozen v1.0.0 surface stay as shipped at Registry `53cd0bb` / `v1.0.0`. This ADR does not amend the live schema.
3. **Do not dual-declare in providers.** Providers must not add parallel `NodeTypes` / `EdgeTypes` beside `Shapes` under contract v1. That would create a second source of truth and teach every later provider a local fork (rejected as option 2 in Provider.PowerShell ADR 0003).
4. **Target a future contract major for the fix.** Prefer either:
   - separate collections `NodeTypes` and `EdgeTypes`, or
   - one map with a **required, registry-validated** kind discriminator  
   Entries remain otherwise opaque (no geometry, no XML). Layout and rendering stay in Core.
5. **Keep the PowerShell acceptance failure as living evidence** until a contract major lands and providers can declare kinds without forking. It is not a provider implementation gap.

## Consequences
- Contract v1 remains registerable and useful; Core and providers continue to consume `Shapes` as today.
- Kind discrimination stays a private convention (`Edge = $true`) until a major version; Core must not treat that flag as part of the frozen contract.
- A future major has a two-provider evidence pack (PowerShell PATTERNS + ADR 0003 + failing acceptance CI; Terraform spike findings + manifest) and does not need to re-discover the friction from one domain.
- Scaffolder (`New-PSDrawIOProvider`) and conformance stay on the v1 shape until that major is designed; no silent partial migration.
- This repository owns the durable record. Provider-local docs remain valid client notes; they are not a substitute for a registry ADR.
- The Terraform spike was conducted with knowledge of the PowerShell finding. Its hypothesis was pre-registered in Provider.PowerShell ADR 0003 before the spike ran, which is a stronger position than an unstructured confirmation, but it was not a blind test and this record should not imply otherwise.
- The property tables above are evidence independent of that framing. Across both providers, all ten node declarations carry `LinkTemplate` and `LayoutHints`; none of the eight edge declarations carries either. That asymmetry is measurable from the two manifests without reference to any narrative about how the finding was reached.
