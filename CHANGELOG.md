# Changelog

All notable changes to this project will be documented here.

## [Unreleased]

## [1.1.0] - 2026-08-21

- Documented the optional `Metadata` hashtable already accepted on `PrivateData.PSDrawIO` (opaque provider data; registry stores and returns it without interpretation).
- `Test-PSDrawIOProviderConformance` now enforces module-name binding: the `.psd1` leaf (Path set) or optional `-ModuleName` (Manifest set) must be `PS.DrawIO.Provider.<ProviderName>` with a single PascalCase segment. Registration is unchanged. ContractVersion remains 1. ModuleVersion 1.1.0.

## [1.0.0] - 2026-08-21

- Added the PS.DrawIO provider contract and in-memory registry.
- Added provider validation, resolution, capability negotiation, naming checks, scaffolding, and conformance checks.
- Added executable acceptance and shipped conformance suites, safer build failure detection, and Registry v1 class-boundary guidance.
