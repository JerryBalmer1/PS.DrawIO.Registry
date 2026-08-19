function Test-PSDrawIOProviderNameInternal {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    return $Name -match '^[A-Z][a-zA-Z0-9]+$' -and $Name -notmatch '\.'
}
