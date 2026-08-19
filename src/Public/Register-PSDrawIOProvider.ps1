function Register-PSDrawIOProvider {
    <#
    .SYNOPSIS
    Registers a PS.DrawIO provider manifest.
    .DESCRIPTION
    Validates PrivateData.PSDrawIO, checks the contract major, and stores the declaration in memory.
    .PARAMETER Path
    Path to a provider module manifest.
    .PARAMETER Manifest
    Imported provider manifest data.
    .EXAMPLE
    Register-PSDrawIOProvider -Path ./PS.DrawIO.Provider.PowerShell.psd1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [Alias('ManifestPath')]
        [string]$Path,
        [Parameter(Mandatory, ParameterSetName = 'Manifest')]
        [object]$Manifest,
        [switch]$Force
    )

    $inputObject = if ($PSCmdlet.ParameterSetName -eq 'Path') { $Path } else { $Manifest }
    $declaration = ConvertTo-PSDrawIODeclaration -InputObject $inputObject
    if (-not (Test-PSDrawIOProviderNameInternal -Name $declaration.ProviderName)) {
        throw "Provider name '$($declaration.ProviderName)' must be PascalCase, contain only letters and numbers, and contain no dots."
    }
    if ($declaration.ContractVersion -ne $script:PSDrawIORegistryState.ContractVersion) {
        throw "Provider '$($declaration.ProviderName)' declares contract $($declaration.ContractVersion), but this registry supports contract $($script:PSDrawIORegistryState.ContractVersion)."
    }
    if ($script:PSDrawIORegistryState.Providers.Contains($declaration.ProviderName) -and -not $Force) {
        throw "Provider '$($declaration.ProviderName)' is already registered. Use -Force to replace it."
    }
    if ($PSCmdlet.ShouldProcess($declaration.ProviderName, 'Register PS.DrawIO provider')) {
        $script:PSDrawIORegistryState.Providers[$declaration.ProviderName] = $declaration
        return $declaration
    }
}
