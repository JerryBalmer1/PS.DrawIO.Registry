# ADR 0001: Class Identity at Module Boundaries

## Status
Accepted

## Context
The registry dynamically discovers providers and passes declaration data across module boundaries. PowerShell class identity is tied to the defining module session; a `-Force` re-import can invalidate casts against previously created instances. Class-typed parameters across modules also require `using module`, which resolves at parse time, cannot be dynamic, and pins provider versions.

That behavior is unsuitable for a registry that must load independently versioned providers and exchange declarations without compile-time coupling.

## Decision
Keep PS classes internal to a module. At module boundaries, use PSCustomObject data with a `PSTypeName` and validate it with functions. Do not expose class-typed contract parameters or require providers to share class definitions.

## Consequences
Registry and providers can be reloaded and discovered dynamically without brittle class casts or parse-time module dependencies. Validation remains explicit and executable. Internal classes may still be used where they do not cross the boundary.

`New-PSDrawIOProvider` currently emits manifest declarations as PowerShell data and does not scaffold class-based contract objects, so no scaffolder migration is required for this decision.
