# ADR 0003: Cross-Provider References

## Status
Accepted (defect recorded; contract v1 unchanged)

## Context
Registry contract v1 stores one declaration per provider and resolves shapes by a single `(Provider, Type)` pair. Nothing in the frozen surface names a far-end owner, joins two providers' graphs, or treats dual registration as multi-graph composition.

> `Shapes` maps semantic type names to opaque declaration data; the registry stores it and never renders XML or performs layout.
>
> `Metadata` is an optional hashtable of opaque, provider-defined key/value data under `PrivateData.PSDrawIO` … The registry stores and returns it and never interprets it; beyond requiring a hashtable when present, contents are unvalidated.
>
> The registry returns declarations to Core. Providers never execute during shape resolution.
>
> — `docs/CONTRACT.md` (Registry HEAD `ce38ef1`; tag `v1.1.0` `e6c19e8`, `src/` matches tag)

`ConvertTo-PSDrawIODeclaration` materializes exactly five contract fields plus `PSTypeName`. There is no foreign-provider, ownership, graph, or join field:

```powershell
return [pscustomobject]@{
    PSTypeName = 'PS.DrawIO.ProviderDeclaration'
    ProviderName = $providerName
    ContractVersion = $contractVersion
    Capabilities = $capabilities
    Shapes = $shapes
    Metadata = $metadata
}
```

— `src/Private/ConvertTo-PSDrawIODeclaration.ps1` (Registry `ce38ef1`)

Public surface at module version `1.1.0` (eight exports; zero join / estate / multi-provider resolve APIs):

```powershell
FunctionsToExport = @(
    'Register-PSDrawIOProvider',
    'Get-PSDrawIOProvider',
    'Unregister-PSDrawIOProvider',
    'Resolve-PSDrawIOShape',
    'Test-PSDrawIOCapability',
    'New-PSDrawIOProvider',
    'Test-PSDrawIOProviderConformance',
    'Test-PSDrawIOName'
)
```

— `src/PS.DrawIO.Registry.psd1`

`Resolve-PSDrawIOShape` takes only `-Provider` and `-Type`, looks up one registered declaration, and returns that provider's shape blob:

```powershell
param(
    [Parameter(Mandatory)][string]$Provider,
    [Parameter(Mandatory)][string]$Type
)
# …
return $declaration.Shapes[$Type]
```

— `src/Public/Resolve-PSDrawIOShape.ps1`

That is enough for coexistence of independent vocabularies. It is not enough for an estate edge whose far end is owned by another PS.DrawIO provider.

### Evidence — Provider.PowerShell (`facb1ed686ea2605090c092bd810b734e9840435`)

Manifest `PrivateData.PSDrawIO.Shapes` declares eight keys — four node types and four edge types. **It does not declare placeholder node types:**

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

**Central fact (verified against that manifest and the dual-register proof):** `PSExternalCommand` and `PSUnresolved` are **not** shape keys. Proof lines:

```
PowerShell declares PSExternalCommand    => False
PowerShell declares PSUnresolved         => False
PowerShell declares PSModule             => True
PowerShell declares External             => True
```

— `PS.DrawIO.Provider.Terraform/tools/proof-cross-provider-transcript.txt` (Terraform `fc571f2`)

Placeholders exist only in the **graph schema**, so a single-provider graph stays closed:

> External commands are represented by `PSExternalCommand` placeholder nodes, and unresolved invocations by `PSUnresolved` placeholder nodes, so every edge endpoint is present in `Nodes`.
>
> `Edges`: dependency records classified as `Internal`, `External`, or `Unresolved`. `From` and `To` always contain node `Id` values, never display names. … External edges also carry `ExternalKind`: `BuiltIn`, `Module`, or `Unknown`.
>
> — `docs/DOMAIN-MODEL.md`

> Emit placeholder nodes for external and unresolved references. Edge endpoints always use node `Id` values. Placeholder nodes carry the reference name and classification… The decision is a reusable contract concern for future providers, not a PowerShell-only workaround.
>
> — `docs/DECISIONS/0001-closed-graph.md`

`ExternalKind` is a PowerShell command taxonomy (`BuiltIn` / `Module` / `Unknown`), not a pointer to another PS.DrawIO provider or type. Closed-graph placeholders answer "outside this analysis unit." They do **not** answer "owned by provider PowerShell, type `PSModule`, instance X."

### Evidence — Provider.Terraform cross-provider spike (`fc571f2c69a7892b7a0d9935aad615b96362ff9f`)

A second spike dual-registered Terraform and PowerShell against Registry `v1.1.0` and asked whether registry cmdlets alone can join graphs. The spike added one edge shape only — style plus the same private `Edge` flag as ADR 0002 — and **did not** write invented ownership fields into the shipping shape:

```powershell
CrossProviderReference = @{
    Edge  = $true
    Style = 'endArrow=open;dashed=1;dashPattern=2 2;'
    # Attempted (not contract fields — private convention only, like Edge):
    # FarEndProvider = 'PowerShell'
    # FarEndType     = 'PSModule'
    # Those keys would round-trip inside the opaque shape hashtable if
    # written, but Resolve-PSDrawIOShape never interprets them and no
    # registry cmdlet joins them to another provider's declaration.
}
```

— `src/PS.DrawIO.Provider.Terraform.psd1`

Wanted first-class fields vs contract reality:

| Wanted field | In CONTRACT.md? | In ConvertTo-PSDrawIODeclaration? | Result |
|---|---|---|---|
| `FarEndProvider` / `TargetProvider` | No | No | Not a declaration field |
| `FarEndType` / `TargetType` | No | No | Not a declaration field |
| `Owner` on edge | No | No | Not a declaration field |
| Keys inside a `Shapes[...]` hashtable | Opaque blob | Copied as-is into `Shapes` | Round-trips if written; **never interpreted** |
| `Metadata` on `PSDrawIO` | Yes, opaque | Stored, unvalidated | Same private-convention cost as `Edge = $true` |

Proof against Registry `v1.1.0` (`tools/Prove-CrossProviderSpike.ps1` → `tools/proof-cross-provider-transcript.txt`):

1. Both manifests passed `Test-PSDrawIOProviderConformance` (4/4 each).
2. Dual `Register-PSDrawIOProvider -Force` succeeded: registered `PowerShell`, `Terraform`.
3. `Resolve-PSDrawIOShape -Provider Terraform -Type CrossProviderReference` returned keys `Edge`, `Style` only — no owner.
4. Ownership probes on that shape: `FarEndProvider`, `FarEndType`, `TargetProvider`, `TargetType`, `Owner`, `OwnerProvider`, `ForeignProvider` all `False`.
5. `Resolve-PSDrawIOShape -Provider PowerShell -Type PSModule` works **only when the caller already knows** the far-end provider name and type.
6. `Resolve-PSDrawIOShape -Provider Terraform -Type PSModule` throws: *Provider 'Terraform' does not declare shape 'PSModule'.*
7. Join probe conclusion:

```
Join method: none — registry has no join/ownership API
Join answer: UNANSWERABLE from registry cmdlets alone
```

Spike conclusions (Q1–Q7 condensed):

> **Q1** — Far-end ownership is **not** expressible as a first-class Registry v1 field. Only via unvalidated private conventions inside opaque `Shapes` entries or `Metadata` (same cost class as `Edge = $true` / ADR 0002).
>
> **Q2** — Dual registration does **not** enable a registry-level join. Two independent declarations; `Resolve-PSDrawIOShape` is keyed by `(Provider, Type)` only.
>
> **Q3** — Join belongs in **Core (unbuilt) or a graph-composition layer above providers — not the registry store.**
>
> **Q4** — PowerShell closed-graph placeholders are **necessary but not sufficient** for multi-provider estates.
>
> **Q5** — This is a **new seam**, adjacent to the node/edge kind split — not the same defect.
>
> **Q7 / bottom line:** Registry v1 can hold two providers. It cannot join their graphs. Cross-provider estate diagrams are a **Core + graph-schema** problem; treating dual registration as join would be a lie.
>
> — `docs/SPIKE-FINDINGS-CROSS-PROVIDER.md`

### Structural reading — two seams, not one

| Seam | Defect | Workaround today | Recorded in |
|---|---|---|---|
| Node vs edge | One `Shapes` bucket for two kinds | `Edge = $true` private flag | ADR 0002 |
| Cross-provider ownership | No field and no API for "far end owned by provider X type Y" | None in registry; Metadata/shape side-channel would be de-facto contract without a major | **this ADR** |

Splitting `Shapes` into `NodeTypes` / `EdgeTypes` (ADR 0002) does **not** create ownership or join. A future contract major scoped only to kind-split would leave estate diagrams unaddressed.

## Decision
1. **Record the defect against contract v1.** Far-end ownership and multi-provider graph join are not expressible or answerable through the frozen declaration fields or public surface. Dual registration proves coexistence, not join.
2. **Treat this as a separate seam from ADR 0002.** Node/edge kind-split and cross-provider ownership must not be collapsed into one "fix `Shapes`" item. Kind-split does not yield join.
3. **Do not change contract v1 in place.** `CONTRACT.md`, `ConvertTo-PSDrawIODeclaration`, `Resolve-PSDrawIOShape`, and the v1.1.0 export list stay as shipped at Registry `ce38ef1` / tag `v1.1.0`. This ADR does not amend the live schema or add a registry join API.
4. **Do not promote Metadata or opaque shape keys into a de-facto join contract.** Stashing `FarEndProvider` / `FarEndType` (or equivalent) in `Metadata` or inside a shape hashtable would register and round-trip, but it is the same unvalidated private-convention debt as `Edge = $true` (ADR 0002). Acceptable only as a temporary spike note, not as the design.
5. **Leave multi-provider composition ownership undecided.** The registry role remains store + validate + resolve-by-`(Provider, Type)` unless a future ADR deliberately expands it. Nothing in any current specification describes a component that composes multiple providers' graphs. `REGISTRY.md` §4 assigns Core geometry and XML emission, which does not include composition. Therefore either Core's scope expands or a component is missing; that choice is not made here.
6. **Do not scope a future contract major as "NodeTypes/EdgeTypes only."** Any major that claims to unlock multi-provider estate diagrams must also answer ownership on edge instances, placeholder upgrade rules, cross-provider Id stability, declaration-vs-instance ownership, whether placeholder types become real shape keys, and whether the registry stays join-free. Kind-split alone is incomplete for that claim.
7. **Keep PowerShell placeholder types out of the v1 shape map unless a major says otherwise.** `PSExternalCommand` / `PSUnresolved` remaining graph-only (not in `Shapes`) is evidence of the seam, not a provider bug to "fix" by silently adding keys under v1.

## Consequences
- Contract v1 remains registerable and useful for single-provider shape resolution and multi-provider **coexistence**. Callers must not treat dual `Register-PSDrawIOProvider` as an estate join.
- Multi-provider graph composition is not specified today; whether it expands Core or requires a missing component is open. This repository does not grow join/ownership APIs under v1.x without a deliberate major and ADR.
- A future major has a two-seam evidence pack: ADR 0002 (kind split) **and** this ADR (cross-provider ownership). Designing only the first leaves estate diagrams dishonest.
- Providers must not invent first-class ownership fields under contract v1, and must not teach later providers a Metadata join schema as if it were contracted.
- PowerShell closed-graph placeholders remain the per-provider baseline; they do not substitute for foreign-provider pointers or Core composition policy.
- The durable record lives here. Provider.Terraform `docs/SPIKE-FINDINGS-CROSS-PROVIDER.md` and `tools/proof-cross-provider-transcript.txt` are client evidence; they are not a substitute for a registry ADR.
- The Terraform cross-provider spike was run with knowledge of ADR 0002 and the PowerShell closed-graph model. It is confirmatory instrumentation against Registry `v1.1.0`, not a blind discovery that the public surface lacks join APIs (that absence is readable from the manifest alone). The proof still supplies the measurable dual-register / UNANSWERABLE / `PSExternalCommand=False` facts cited above.
