function Test-PSDrawIOProviderConformance {
    <#
    .SYNOPSIS
    Tests a provider manifest against the registry contract.
    .PARAMETER Path
    Path to a provider manifest.
    .PARAMETER Manifest
    Imported provider manifest data.
    .PARAMETER ModuleName
    Optional module leaf name for the Manifest parameter set. When supplied, it
    must bind to ProviderName as PS.DrawIO.Provider.<ProviderName>. When omitted,
    no module-name evidence exists to check.
    .EXAMPLE
    Test-PSDrawIOProviderConformance -Path ./PS.DrawIO.Provider.PowerShell.psd1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path')][string]$Path,
        [Parameter(Mandatory, ParameterSetName = 'Manifest')][object]$Manifest,
        [Parameter(ParameterSetName = 'Manifest')][string]$ModuleName
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

    # Module-name binding: Path always has a filename; Manifest only when -ModuleName is supplied.
    # Omitting -ModuleName on Manifest is not a silent skip - there is no filename evidence to check.
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $resolvedModuleName = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path -Leaf $Path))
        if (-not (Test-PSDrawIOProviderModuleBinding -ProviderName $declaration.ProviderName -ModuleName $resolvedModuleName)) {
            return $false
        }
    }
    elseif ($PSBoundParameters.ContainsKey('ModuleName')) {
        if (-not (Test-PSDrawIOProviderModuleBinding -ProviderName $declaration.ProviderName -ModuleName $ModuleName)) {
            return $false
        }
    }

    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $suitePath = Join-Path $moduleRoot 'Conformance/Provider.Conformance.Tests.ps1'
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
