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

    if ($PSCmdlet.ParameterSetName -eq 'Path' -and -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Provider manifest path '$Path' was not found."
    }

    $inputObject = if ($PSCmdlet.ParameterSetName -eq 'Path') { $Path } else { $Manifest }
    try {
        $declaration = ConvertTo-PSDrawIODeclaration -InputObject $inputObject
    } catch {
        return $false
    }
    $validName = Test-PSDrawIOProviderNameInternal -Name $declaration.ProviderName
    if (-not $validName -or $declaration.ContractVersion -ne $script:PSDrawIORegistryState.ContractVersion) { return $false }

    $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $suitePath = Join-Path $moduleRoot 'tests/Conformance/Provider.Conformance.Tests.ps1'
    if (-not (Test-Path -LiteralPath $suitePath -PathType Leaf)) {
        throw "Provider conformance suite '$suitePath' was not found."
    }
    if (-not (Get-Command Invoke-Pester -ErrorAction SilentlyContinue)) {
        throw 'Pester is required to run provider conformance.'
    }

    $previousManifest = $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON
    try {
        $manifestData = if ($PSCmdlet.ParameterSetName -eq 'Path') { Import-PowerShellDataFile -LiteralPath $Path } else { $Manifest }
        $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON = $manifestData | ConvertTo-Json -Depth 20 -Compress
        $result = Invoke-Pester -Path $suitePath -PassThru
    } finally {
        $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON = $previousManifest
    }
    return [bool]($result.FailedCount -eq 0 -and @($result.Containers | Where-Object { $_.TotalCount -eq 0 }).Count -eq 0)
}
