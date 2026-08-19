$moduleRoot = Split-Path -Parent $PSCommandPath
$privatePath = Join-Path $moduleRoot 'Private'
$publicPath = Join-Path $moduleRoot 'Public'
if (Test-Path -LiteralPath $privatePath) { Get-ChildItem -LiteralPath $privatePath -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName } }
if (Test-Path -LiteralPath $publicPath) { Get-ChildItem -LiteralPath $publicPath -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName } }
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
