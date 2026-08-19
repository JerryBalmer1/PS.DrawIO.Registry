$moduleRoot = Split-Path -Parent $PSCommandPath
Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'Classes') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'Private') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'Public') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Export-ModuleMember -Function @(
    'Register-PSDrawIOProvider',
    'Get-PSDrawIOProvider',
    'Unregister-PSDrawIOProvider',
    'Resolve-PSDrawIOShape',
    'Test-PSDrawIOCapability',
    'New-PSDrawIOProvider',
    'Test-PSDrawIOProviderConformance',
    'Test-PSDrawIOName'
)
