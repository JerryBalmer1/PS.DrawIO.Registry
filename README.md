# PS.DrawIO.Registry

The contract broker for PS.DrawIO providers.

```powershell
Import-Module ./src/PS.DrawIO.Registry.psd1
Register-PSDrawIOProvider -Path ./PS.DrawIO.Provider.PowerShell.psd1
$declaration = Resolve-PSDrawIOShape -Provider PowerShell -Type PSFunction
$declaration.Style
```

The registry validates and stores provider declarations. XML generation, layout, and domain knowledge remain in provider and Core modules.