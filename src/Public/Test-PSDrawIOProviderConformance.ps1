function Test-PSDrawIOProviderConformance {
    <#
    .SYNOPSIS
    Tests a provider manifest against the registry contract.
    .PARAMETER Path
    Path to a provider manifest.
    .PARAMETER Manifest
    Imported provider manifest data.
    .EXAMPLE
    Test-PSDrawIOProviderConformance -Path ./PS.DrawIO.Provider.PowerShell.psd1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path')][string]$Path,
        [Parameter(Mandatory, ParameterSetName = 'Manifest')][object]$Manifest
    )

    try {
        $inputObject = if ($PSCmdlet.ParameterSetName -eq 'Path') { $Path } else { $Manifest }
        $declaration = ConvertTo-PSDrawIODeclaration -InputObject $inputObject
        $validName = Test-PSDrawIOProviderNameInternal -Name $declaration.ProviderName
        return [bool]($validName -and $declaration.ContractVersion -eq $script:PSDrawIORegistryState.ContractVersion)
    } catch {
        return $false
    }
}
