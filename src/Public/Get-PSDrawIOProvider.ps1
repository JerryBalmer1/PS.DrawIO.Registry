function Get-PSDrawIOProvider {
    <#
    .SYNOPSIS
    Gets registered PS.DrawIO providers.
    .PARAMETER Name
    Optional provider name to retrieve.
    .EXAMPLE
    Get-PSDrawIOProvider -Name PowerShell
    #>
    [CmdletBinding()]
    param([string]$Name)

    if ($Name) {
        if (-not $script:PSDrawIORegistryState.Providers.Contains($Name)) { return }
        return $script:PSDrawIORegistryState.Providers[$Name]
    }
    return @($script:PSDrawIORegistryState.Providers.Values)
}
