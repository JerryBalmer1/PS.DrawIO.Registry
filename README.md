# PS.DrawIO.Registry

The contract broker for PS.DrawIO providers.

```powershell
Import-Module ./src/PS.DrawIO.Registry.psd1
Register-PSDrawIOProvider -Path ./PS.DrawIO.Provider.PowerShell.psd1
$declaration = Resolve-PSDrawIOShape -Provider PowerShell -Type PSFunction
$declaration.Style
```

The registry validates and stores provider declarations. XML generation, layout, and domain knowledge remain in provider and Core modules.

The cross-platform test gate has an unsigned manual sign-off at `docs/SIGNOFF.json`; a human must countersign it against the reviewed commit. macOS execution remains out of scope until hardware is available.

## Agent execution protocol

Agent work follows [`.agent/TRAPS.md`](.agent/TRAPS.md): accumulated failure knowledge read once before any task. Per-run plans and attempt logs go in `.agent/EXECUTION.md` (gitignored). See [`.agent/README.md`](.agent/README.md).

## Development

Run `git config core.hooksPath .githooks` after cloning to enable the commit-msg hook.
