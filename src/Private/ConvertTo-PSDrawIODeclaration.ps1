function ConvertTo-PSDrawIODeclaration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $manifest = $InputObject
    if ($InputObject -is [string]) {
        if (-not (Test-Path -LiteralPath $InputObject -PathType Leaf)) {
            throw "Provider manifest path '$InputObject' was not found."
        }
        $manifest = Import-PowerShellDataFile -LiteralPath $InputObject
    }

    $privateData = $manifest.PrivateData
    $psDrawIO = if ($privateData -is [hashtable]) { $privateData.PSDrawIO } else { $null }
    if ($null -eq $psDrawIO) {
        throw "Provider manifest is missing the 'PrivateData.PSDrawIO' field."
    }

    foreach ($field in 'ContractVersion', 'ProviderName', 'Capabilities') {
        if (-not $psDrawIO.ContainsKey($field) -or $null -eq $psDrawIO[$field]) {
            throw "Provider declaration is missing the '$field' field."
        }
    }

    $contractVersion = 0
    try { $contractVersion = [int]$psDrawIO.ContractVersion } catch { throw "Provider declaration field 'ContractVersion' must be an integer." }
    $providerName = [string]$psDrawIO.ProviderName
    $capabilities = @($psDrawIO.Capabilities | ForEach-Object { [string]$_ })
    $shapes = if ($psDrawIO.Shapes) { @{} + $psDrawIO.Shapes } else { @{} }
    $metadata = if ($psDrawIO.Metadata) { @{} + $psDrawIO.Metadata } else { @{} }

    if ($contractVersion -lt 1) { throw "Provider declaration field 'ContractVersion' must be 1 or greater." }
    if ([string]::IsNullOrWhiteSpace($providerName)) { throw "Provider declaration field 'ProviderName' cannot be empty." }
    if ($capabilities.Count -eq 0) { throw "Provider declaration field 'Capabilities' must contain at least one capability." }
    foreach ($shapeType in $shapes.Keys) {
        if ([string]::IsNullOrWhiteSpace([string]$shapeType) -or $null -eq $shapes[$shapeType]) {
            throw "Provider declaration field 'Shapes' contains an invalid shape entry."
        }
    }

    return [pscustomobject]@{
        PSTypeName = 'PS.DrawIO.ProviderDeclaration'
        ProviderName = $providerName
        ContractVersion = $contractVersion
        Capabilities = $capabilities
        Shapes = $shapes
        Metadata = $metadata
    }
}
