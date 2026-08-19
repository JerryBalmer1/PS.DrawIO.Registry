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

    $declaration = [PSDrawIOProviderDeclaration]::new()
    try { $declaration.ContractVersion = [int]$psDrawIO.ContractVersion } catch { throw "Provider declaration field 'ContractVersion' must be an integer." }
    $declaration.ProviderName = [string]$psDrawIO.ProviderName
    $declaration.Capabilities = @($psDrawIO.Capabilities | ForEach-Object { [string]$_ })
    $declaration.Shapes = if ($psDrawIO.Shapes) { @{} + $psDrawIO.Shapes } else { @{} }
    $declaration.Metadata = if ($psDrawIO.Metadata) { @{} + $psDrawIO.Metadata } else { @{} }

    if ($declaration.ContractVersion -lt 1) { throw "Provider declaration field 'ContractVersion' must be 1 or greater." }
    if ([string]::IsNullOrWhiteSpace($declaration.ProviderName)) { throw "Provider declaration field 'ProviderName' cannot be empty." }
    if ($declaration.Capabilities.Count -eq 0) { throw "Provider declaration field 'Capabilities' must contain at least one capability." }
    foreach ($shapeType in $declaration.Shapes.Keys) {
        if ([string]::IsNullOrWhiteSpace([string]$shapeType) -or $null -eq $declaration.Shapes[$shapeType]) {
            throw "Provider declaration field 'Shapes' contains an invalid shape entry."
        }
    }

    return $declaration
}
