function Test-PSDrawIOCapability {
    <#
    .SYNOPSIS
    Tests whether a provider declares a capability.
    .PARAMETER Name
    Capability name to test.
    .PARAMETER Provider
    Optional provider name. Without it, any registered provider may satisfy the capability.
    .EXAMPLE
    Test-PSDrawIOCapability -Provider PowerShell -Name Shapes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Provider
    )

    $providers = if ($Provider) {
        if (-not $script:PSDrawIORegistryState.Providers.Contains($Provider)) { return $false }
        @($script:PSDrawIORegistryState.Providers[$Provider])
    } else { @($script:PSDrawIORegistryState.Providers.Values) }
    return [bool]($providers | Where-Object { $_.Capabilities -contains $Name } | Select-Object -First 1)
}
