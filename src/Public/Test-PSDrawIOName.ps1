function Test-PSDrawIOName {
    <#
    .SYNOPSIS
    Validates PS.DrawIO names and parses diagram filenames.
    .PARAMETER Name
    Module or provider name to validate.
    .PARAMETER Kind
    Name category: Provider or Module.
    .PARAMETER Path
    Diagram path using X.Provider.drawio, .drawio.ps1, or .drawio.psd1.
    .EXAMPLE
    Test-PSDrawIOName -Path 'Function.PowerShell.drawio.ps1'
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Name')][string]$Name,
        [Parameter(ParameterSetName = 'Name')][ValidateSet('Provider', 'Module')][string]$Kind = 'Provider',
        [Parameter(Mandatory, ParameterSetName = 'Path')][string]$Path
    )

    if ($PSCmdlet.ParameterSetName -eq 'Name') {
        if ($Kind -eq 'Provider') { return (Test-PSDrawIOProviderNameInternal -Name $Name) }
        return $Name -match '^PS\.DrawIO\.[A-Za-z][A-Za-z0-9.]+$'
    }

    $fileName = Split-Path -Leaf $Path
    if ($fileName -notmatch '^(?<component>[^.]+)\.(?<provider>[A-Z][A-Za-z0-9]+)\.drawio(?<suffix>\.ps1|\.psd1)?$') {
        throw "Path '$Path' does not match 'X.Provider.drawio[.ps1|.psd1]'."
    }
    [pscustomobject]@{
        Component = $Matches.component
        Provider = $Matches.provider
        Kind = if ($Matches.suffix) { $Matches.suffix.TrimStart('.') } else { 'drawio' }
        Path = $Path
    }
}
