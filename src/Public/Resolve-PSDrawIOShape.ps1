function Resolve-PSDrawIOShape {
    <#
    .SYNOPSIS
    Resolves a semantic shape type to a provider declaration.
    .PARAMETER Provider
    Registered provider name.
    .PARAMETER Type
    Semantic shape type.
    .EXAMPLE
    Resolve-PSDrawIOShape -Provider PowerShell -Type PSFunction
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Provider,
        [Parameter(Mandatory)][string]$Type
    )

    if (-not $script:PSDrawIORegistryState.Providers.Contains($Provider)) {
        $available = @($script:PSDrawIORegistryState.Providers.Keys) -join ', '
        throw "Provider '$Provider' is not registered. Registered providers: $available"
    }
    $declaration = $script:PSDrawIORegistryState.Providers[$Provider]
    if (-not $declaration.Shapes.ContainsKey($Type)) {
        $available = @($declaration.Shapes.Keys) -join ', '
        throw "Provider '$Provider' does not declare shape '$Type'. Declared shapes: $available"
    }
    return $declaration.Shapes[$Type]
}
