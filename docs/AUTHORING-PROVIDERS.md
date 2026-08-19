# Authoring Providers

1. Scaffold a provider with `New-PSDrawIOProvider -Name PowerShell -Path ./PS.DrawIO.Provider.PowerShell`.
2. Edit the generated manifest's `PrivateData.PSDrawIO` declaration.
3. Keep provider names PascalCase and avoid dots.
4. Put semantic shape declarations in `Shapes`; keep XML, geometry, and domain logic out of the registry contract.
5. Run `Test-PSDrawIOProviderConformance -Path ./PS.DrawIO.Provider.PowerShell/PS.DrawIO.Provider.PowerShell.psd1`.
6. Register the manifest with `Register-PSDrawIOProvider` when the provider is loaded.

The provider's module version can evolve independently. Increment `ContractVersion` only when the registry contract major changes.
