function Test-PSDrawIOProviderModuleBinding {
    <#
    .SYNOPSIS
    Returns true when a provider module leaf name binds to ProviderName.
    .DESCRIPTION
    Module name must be PS.DrawIO.Provider.<ProviderName> with a single PascalCase
    segment after Provider. Multi-dot module names never bind.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProviderName,
        [Parameter(Mandatory)][string]$ModuleName
    )

    if ($ModuleName -notmatch '^PS\.DrawIO\.Provider\.(?<segment>[A-Z][A-Za-z0-9]+)$') {
        return $false
    }

    return $ProviderName -eq $Matches.segment
}
