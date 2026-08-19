function Unregister-PSDrawIOProvider {
    <#
    .SYNOPSIS
    Removes a registered PS.DrawIO provider.
    .PARAMETER Name
    Name of the provider to remove.
    .EXAMPLE
    Unregister-PSDrawIOProvider -Name PowerShell
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([Parameter(Mandatory)][string]$Name)

    if (-not $script:PSDrawIORegistryState.Providers.Contains($Name)) {
        throw "Provider '$Name' is not registered."
    }
    if ($PSCmdlet.ShouldProcess($Name, 'Unregister PS.DrawIO provider')) {
        $script:PSDrawIORegistryState.Providers.Remove($Name)
    }
}
