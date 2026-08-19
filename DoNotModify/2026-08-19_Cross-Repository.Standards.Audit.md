# Cross-Repository Standards Audit

Audited from the public GitHub repos, 2026-08-19. Findings verified against actual file contents, not handoff reports.

**Headline: the registry has the same defects the provider spent three passes fixing, and it is the root everything else is built on.**

---

## P0 — Registry: the build cannot detect failure

`PS.DrawIO.Registry/build/build.ps1` lines 18–20:

```powershell
Invoke-Pester (Join-Path $root 'tests') -CI
if ($LASTEXITCODE -ne 0) { throw 'Pester tests failed.' }
```

Both bugs already diagnosed and fixed in the provider are still live here:

- `-CI` sets `Run.Exit`, terminating the host process on failure. This is what was killing the agent's terminal repeatedly.
- `$LASTEXITCODE` is set by native executables, not cmdlets. It never reflects Pester's result. The build passes regardless of test outcome.

Any green build reported from the registry to date is meaningless.

**Fix:** port the provider's corrected version verbatim — `-PassThru`, `FailedCount` check first, then empty-container check, `exit 1` only under CI.

---

## P0 — Registry: 31 checkboxes, 6 unit tests, no acceptance suite

```
PS.DrawIO.Registry.md      31 Definition-of-Done checkboxes
tests/Unit/Registry.Tests.ps1     6 It blocks
tests/Acceptance/                 does not exist
```

The root module's Definition of Done has never been evaluated. This is precisely the state the provider was in when it reported "47 tests passed" while the suite defining done had never executed an assertion.

The registry also exports `Test-PSDrawIOProviderConformance`, which the provider depends on and asserts against — but there is no `tests/Conformance/` directory. The suite providers are supposed to run does not exist as a shipped artifact.

**Fix:** port the provider's acceptance pattern. It is proven and it works: parse checkboxes matching `^\- \[[ x]\] `, key tests by label text via `Get-Label`, meta-test asserting every checkbox has a matching `It`, no `-Skip`.

---

## P0 — Registry: spec filename mismatch, still live

| | |
|---|---|
| File on disk | `PS.DrawIO.Registry.md` |
| `AGENTS.md` references | `REGISTRY.md` at lines 5, 28, 64, 112, 199 |

Identical to the confusion that cost a pass in the provider repo. Rename to `REGISTRY.md`.

---

## P1 — Registry: no ADRs, and a known-wrong instruction still in place

`docs/DECISIONS/` does not exist. Two decisions that should be recorded are not:

1. **The class-identity finding.** `PATTERNS.md` in the provider established that PowerShell class types are tied to the defining module's session state, so `-Force` re-import invalidates casts. The generalizable rule is **classes internal, duck-typed at module boundaries.**

2. `REGISTRY.md` still advises *"Prefer PS classes for the contract objects (real type safety)."* For a registry that dynamically loads providers passing declaration objects across module boundaries, this is wrong — cross-module class parameters require `using module`, which resolves at parse time and cannot be dynamic. This instruction should be corrected and the reasoning recorded.

This matters more than it looks: `New-PSDrawIOProvider` scaffolds providers, so a wrong instruction here propagates into every provider ever generated.

---

## P1 — Both repos: `/DoNotModify` does not exist

Both `AGENTS.md` files reference it as an off-limits directory in at least six places each. Neither repo contains it. A guardrail pointing at nothing trains agents to treat guardrails as decorative.

**Fix:** create it with a `README.md` explaining its purpose, or remove the references. Creating it is better — the concept is sound and you'll want it.

---

## P1 — Both repos: root `Build.ps1` is a broken stub

Both repos contain a root `Build.ps1` whose entire content is:

```
./build/build.ps1
```

No trailing newline, and **no parameter passthrough**. So `./Build.ps1 -Task Test` silently ignores `-Task` and runs `All`. Anyone using the root script gets different behavior than documented.

**Fix:** either delete it and always use `./build/build.ps1`, or make it forward properly:

```powershell
[CmdletBinding()]
param([string]$Task = 'All')
& (Join-Path $PSScriptRoot 'build/build.ps1') -Task $Task
```

---

## P1 — No CI exists, yet a DoD gate depends on it

Neither repo has `.github/workflows/`. But both Definition-of-Done lists require:

> Pester 5 green on Windows and Linux — PowerShell 7+

The provider's handoff correctly noted "Linux remains a CI/environment-level responsibility." There is no CI, so that gate cannot be met by anyone. It will sit permanently unverifiable.

**Fix:** a minimal GitHub Actions workflow, matrix on `windows-latest` and `ubuntu-latest`, running `./build/build.ps1`. This is also the only place `-CI` should ever appear.

---

## P2 — Provider: `Agents.md` should be `AGENTS.md`

Case matters on Linux, and Linux is a DoD gate. Agent tooling looks for `AGENTS.md`. The registry has it correct; the provider does not.

Git on Windows won't see a pure case change — use `git mv Agents.md agents.tmp && git mv agents.tmp AGENTS.md`.

---

## P2 — Provider: `src/Analysis/` does not exist, which may make the wall test vacuous

`PROVIDER.md` §10 and `AGENTS.md` §1 both specify:

```
src/Declarations/   pure data
src/Analysis/       AST work
```

On disk there is `src/Declarations/PSDrawIO.Declarations.ps1` and **no `src/Analysis/`**. The AST code lives in `src/Public/`.

The Definition of Done includes:

> Nothing in `src/Declarations/` calls anything in `src/Analysis/` — enforced by a test

If `src/Analysis/` doesn't exist, that test may be passing vacuously — asserting that nothing calls into an empty set. That is the same defect class as the tautological sign-off test and the fake performance test, and it is currently reported as passing.

**Verify first, then decide:** either move the analysis code into `src/Analysis/` so the structure matches the spec and the wall becomes real, or amend the spec to describe the actual layout and rewrite the test to assert something meaningful. Do not leave a passing test that asserts nothing.

---

## P2 — Provider: committed artifacts and scratch files

- `coverage.xml` is committed. `.gitignore` contains only `dist/` and `testResults.xml`.
- `Test.ps1` at the repo root is an ad-hoc scratch script (imports the module, dumps a graph as JSON). Useful, but it's untracked-by-intent work sitting in version control at the top level.

**Fix:** add `coverage.xml`, `*.coverage`, `TestResults*.xml` to `.gitignore` and `git rm --cached coverage.xml`. Move `Test.ps1` to `tools/` or delete it.

---

## P2 — Missing directories against declared layout

| Directory | Registry | Provider |
|---|---|---|
| `DoNotModify/` | ✗ | ✗ |
| `docs/DECISIONS/` | ✗ | ✓ |
| `tests/Acceptance/` | ✗ | ✓ |
| `tests/Integration/` | ✗ | ✗ |
| `tests/Conformance/` | ✗ | ✗ |
| `src/en-US/` | ✗ | ✗ |
| `src/Analysis/` | n/a | ✗ |

`tests/Conformance/` is the notable one — the provider asserts against a conformance suite that has no shipped location in the registry.

---

## Confirmed working

Worth stating, since most of this document is problems:

- Provider `build/build.ps1` has the corrected Pester handling
- Provider acceptance suite exists with the label-keyed pattern and meta-test
- Provider has three real ADRs
- Registry public surface matches its declared v1 API — all eight functions present
- The node/edge finding is real and visible in the manifest: `Internal`, `External`, `Unresolved`, `Inherits` sit inside `Shapes` with `Edge = $true` flags, merged with node types exactly as ADR 0003 describes

---

## Terraform readiness

`PS.DrawIO.Provider.Terraform` contains only `README.md`. Nothing to remediate — it starts clean, which is the best position to be in.

**Do not start it until the registry is fixed.** The provider is a contract client, and the contract's own Definition of Done has never been verified. Building a second client against an unverified contract repeats the root-principle violation the whole structure exists to prevent.

Suggested order:

```
1. Registry P0s        build script, acceptance suite, spec rename
2. Registry P1s        ADRs, class-identity correction, DoNotModify
3. Both repos          root Build.ps1, CI workflow
4. Provider P2s        AGENTS.md case, src/Analysis wall, gitignore
5. Provider sign-offs  human, then commit
6. Terraform spike     declaration-only, throwaway
```

Steps 1–3 are the ones that block. Step 4 can run in parallel; step 5 is yours.