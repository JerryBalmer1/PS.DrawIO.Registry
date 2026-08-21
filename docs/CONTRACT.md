# PS.DrawIO Provider Contract v1

A provider manifest declares its registry contract under `PrivateData.PSDrawIO`.

```powershell
PrivateData = @{
    PSDrawIO = @{
        ContractVersion = 1
        ProviderName = 'PowerShell'
        Capabilities = @('Shapes', 'Links')
        Shapes = @{
            PSFunction = @{
                Style = 'rounded=1;'
                LinkTemplate = 'vscode://file/{path}:{line}'
                LayoutHints = @{ Group = 'Functions'; Direction = 'Vertical' }
            }
        }
    }
}
```

`ContractVersion` is the provider contract major and is independent from the module version. Registration accepts only the registry's current major. `ProviderName` is PascalCase with letters and numbers only. `Capabilities` is a non-empty list of feature names. `Shapes` maps semantic type names to opaque declaration data; the registry stores it and never renders XML or performs layout.

`Metadata` is an optional hashtable of opaque, provider-defined key/value data under `PrivateData.PSDrawIO` (for example `Metadata = @{ Fixture = $true }`). The registry stores and returns it and never interprets it; beyond requiring a hashtable when present, contents are unvalidated. Providers use `Metadata` for taxonomy or descriptive data the contract does not model. The registry makes no promises about those contents.

Declarations crossing module boundaries are PSCustomObject data with a `PSTypeName` and function-based validation. PS classes are internal implementation details and are not part of the provider contract.

The registry returns declarations to Core. Providers never execute during shape resolution.
