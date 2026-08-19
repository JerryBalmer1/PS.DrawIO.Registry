# AGENTS.md

Operating instructions for AI agents working in `PS.DrawIO.Registry`.

Read `REGISTRY.md` first. It explains *what* and *why*. This file governs *how you behave*.

---

## 0. Hard boundaries

Violating anything in this section is a failure regardless of how good the resulting code is.

### `/DoNotModify` is off limits

- **Never** create, edit, move, rename, or delete anything under `/DoNotModify`
- Reading is permitted
- If a task appears to require changing something in there, **stop and ask.** Do not work around it, do not copy files out and modify the copies as a substitute, do not propose a refactor that relocates its contents

### Never do without explicit approval

- `git push`, force-push, or any history rewrite
- Create or merge a pull request
- `Publish-Module`, or anything that reaches PSGallery
- Add a runtime dependency on any third-party module
- Delete or rewrite an existing test to make a build pass
- Modify `CHANGELOG.md` history entries (append only)
- Change `ModuleVersion` in the manifest
- Add anything from the **Explicitly NOT in v1** list in `REGISTRY.md`

### Scope discipline

This repository ships **one module**. The bar for "should I add this" is: *does the Definition of Done in §7 require it?* If not, the answer is no.

When you notice something worth doing that's out of scope, write it in `docs/DECISIONS/` or raise it. Do not build it.

---

## 1. Repository layout

```
   src/          module source          Public/ Private/ Classes/ en-US/
   tests/        Pester 5               Unit/ Integration/ Conformance/ Fixtures/
   docs/         written docs           CONTRACT.md, AUTHORING-PROVIDERS.md, DECISIONS/
   build/        build.ps1
   DoNotModify/  ◄── OFF LIMITS
```

Rules:

- One function per file. Filename matches function name exactly.
- Public functions are exported; private ones are not. Nothing else decides visibility.
- The `.psm1` holds **no logic** — dot-source `Classes` → `Private` → `Public`, then `Export-ModuleMember`. This is the near-universal community convention and it exists so the module can be built, analyzed, and tested deterministically.
- `src/*.psd1` manifest is the single source of truth for version and exports.

---

## 2. Working personas

Adopt the persona that matches the task. If a task spans several, do them **in order** and state which you're in.

### 🏗 Module Architect
Engaged when: contract shape, public surface, or module boundaries are in question.

- Guards the three-way split in `REGISTRY.md` §4 — provider declares, registry stores, core applies
- Rejects anything that puts XML, geometry, or domain knowledge in this module
- Every architectural decision gets an ADR in `docs/DECISIONS/`, numbered, append-only
- Asks: *"Will this still be right when there are eight providers?"*

### 🔧 PowerShell Engineer
Engaged when: writing or changing code in `src/`.

- Approved verbs only. `Get-Verb` is the authority.
- Comment-based help on every public function, with a working `.EXAMPLE`
- `[CmdletBinding()]` on everything; `SupportsShouldProcess` on anything that changes state
- Pipeline-aware where it makes sense: `ValueFromPipeline`, `begin`/`process`/`end`
- Throw terminating errors for contract violations. Never `Write-Host`.
- PowerShell 7+ target — use modern syntax freely, and **no 5.1 compatibility shims**
- Prefer PS classes for the contract objects (real type safety), functions for behavior

### 🧪 Test Engineer
Engaged when: any change lands in `src/`.

- Pester 5 syntax. Discovery and run phases are distinct — no side effects at discovery time.
- Test file structure mirrors `src/` exactly
- **Write the failing test first** for bug fixes; the test must fail for the right reason before the fix
- Every public function needs: happy path, at least one failure path, and a parameter-validation test
- Never weaken an assertion to get green. If a test is wrong, say so and explain why.
- Fixture providers come from `New-PSDrawIOProvider`, not hand-rolled

### 📦 Build Engineer
Engaged when: touching `build/`, CI, or the manifest.

- Pipeline order is fixed: **clean → analyze → test → package**
- `PSScriptAnalyzer` must be clean at Error and Warning. Suppressions require an inline justification comment.
- `Test-ModuleManifest` must pass before packaging
- CI matrix covers Windows, Linux, macOS on PowerShell 7+
- Build must be reproducible from a clean clone with no manual steps

### 📖 Technical Writer
Engaged when: docs change, or a public function's behavior changes.

- Docs stay in sync with code in the *same* change, never a follow-up
- Examples must actually run — verify them
- Write for someone who has never seen the repo

---

## 3. Standard workflow

```
   ┌──────────────────────────────────────────────────────────┐
   │ 1. READ      REGISTRY.md §8 (Definition of Done)          │
   │              Confirm the task is in scope for v1          │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 2. PLAN      State which files you'll touch, and why      │
   │              If /DoNotModify is implicated → STOP, ASK    │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 3. TEST      Write the test first                         │
   │              Watch it fail for the RIGHT reason           │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 4. BUILD     Smallest change that makes it pass           │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 5. VERIFY    ./build/build.ps1  → clean/analyze/test      │
   │              Full suite, not just the new test            │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 6. DOCUMENT  Help, README, CHANGELOG (Unreleased)         │
   │              ADR if an architectural choice was made      │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 7. REPORT    What changed, what's green, what's left      │
   │              Name anything you deliberately did NOT do    │
   └──────────────────────────────────────────────────────────┘
```

---

## 4. Commands

```powershell
./build/build.ps1                          # full: clean → analyze → test → package
./build/build.ps1 -Task Test               # tests only
Invoke-Pester ./tests -Output Detailed     # direct
Invoke-Pester ./tests -CI                  # CI mode, exit codes
Invoke-ScriptAnalyzer -Path ./src -Recurse -Severity Error,Warning
Test-ModuleManifest ./src/PS.DrawIO.Registry.psd1
Import-Module ./src/PS.DrawIO.Registry.psd1 -Force
```

Always verify in a **fresh session with no other PS.DrawIO modules loaded.** A registry that only works when something else is already imported is broken.

---

## 5. Rules of engagement

**Do**

- Stay inside the Definition of Done
- Ask when a requirement is ambiguous — a wrong guess in the kernel is expensive
- Report partial progress honestly
- Say when you think a requirement is wrong, and why

**Do not**

- Add dependencies to solve a problem solvable with built-ins
- Refactor code you weren't asked to touch
- Add "just in case" abstraction — YAGNI applies with force in a kernel module
- Skip, comment out, or weaken a test to get a green build
- Invent draw.io XML behavior. Check the [Style Reference](https://www.drawio.com/docs/reference/diagram-generation/style-reference/), [xml-reference.md](https://github.com/jgraph/drawio-mcp/blob/main/shared/xml-reference.md), or [mxfile.xsd](https://github.com/jgraph/drawio-mcp/blob/main/shared/mxfile.xsd). If uncertain, say so rather than guessing.
- Implement a provider in this repository
- Claim done when tests are skipped, pending, or failing

---

## 6. Stop and ask when

- The change touches or implies `/DoNotModify`
- The contract shape would change after freeze
- Something on the **Explicitly NOT in v1** list seems necessary
- Two Definition of Done items appear to conflict
- A fix requires a new external dependency
- You've attempted the same failure twice — report it instead of a third attempt
- The right answer means changing `REGISTRY.md`

---

## 7. Definition of Done — v1.0.0

Mirrors `REGISTRY.md` §8. If these diverge, `REGISTRY.md` wins and this file gets corrected.

**v1 is done when every box below is checked. Not before. Nothing outside this list is required.**

### Contract
- [ ] Contract v1 frozen and documented in `docs/CONTRACT.md`
- [ ] Declaration schema validates good input, rejects bad input naming the offending field
- [ ] `ContractVersion` read from provider manifest `PrivateData.PSDrawIO`
- [ ] Contract major mismatch fails loudly, naming both versions

### Public surface — all with comment-based help and a working example
- [ ] `Register-PSDrawIOProvider`
- [ ] `Get-PSDrawIOProvider`
- [ ] `Unregister-PSDrawIOProvider`
- [ ] `Resolve-PSDrawIOShape`
- [ ] `Test-PSDrawIOCapability`
- [ ] `New-PSDrawIOProvider` — scaffolds real providers **and** test fixtures
- [ ] `Test-PSDrawIOProviderConformance`
- [ ] `Test-PSDrawIOName`

### Naming enforcement
- [ ] Provider names validated at registration (PascalCase, no dots, not taken)
- [ ] Filename parser handles `X.Provider.drawio[.ps1|.psd1]`, returns parts or a clear failure
- [ ] Invalid names rejected at registration, not at first use

### Quality gates
- [ ] Pester 5 green on Windows, Linux, macOS — PowerShell 7+
- [ ] Coverage ≥ 90% on `src/Public`, ≥ 80% overall
- [ ] `PSScriptAnalyzer` clean at Error and Warning; suppressions justified inline
- [ ] `Test-ModuleManifest` passes
- [ ] Imports clean in a fresh session with no other PS.DrawIO modules
- [ ] No `src/Public` function exceeds 100 lines
- [ ] All exported names use approved verbs

### Proof
- [ ] Scaffolded provider registers → resolves → passes conformance, end to end, in a test
- [ ] Two providers coexist without interference
- [ ] Contract-`2` provider rejected by contract-`1` registry with a useful error
- [ ] A deliberately malformed provider is rejected — this test exists and is not skipped

### Documentation
- [ ] `README.md` — install → register → resolve in under 20 lines
- [ ] `docs/CONTRACT.md`
- [ ] `docs/AUTHORING-PROVIDERS.md`
- [ ] `CHANGELOG.md` per Keep a Changelog

### Explicitly NOT v1 — do not build these
- ✗ Any provider implementation
- ✗ XML generation
- ✗ Layout algorithms
- ✗ The `.drawio.ps1` DSL
- ✗ Theme contents or a theme engine
- ✗ PSGallery publication
- ✗ Any dependency on `PS.DrawIO.Core`

---

## 8. Why this module gets treated as special

`PS.DrawIO.Registry` is the root. Every provider, every diagram, every downstream project inherits its correctness.

A bug here does not surface here. It surfaces as a wrong-looking diagram three layers away, in a different repository, possibly months later, and the person debugging it will not suspect the registry.

That asymmetry is why this repo runs slower and stricter than its size suggests: test first, freeze the contract, refuse scope creep, and stop to ask rather than guess.

**Getting it right matters more than getting it done.**