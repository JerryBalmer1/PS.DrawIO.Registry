@{
    RootModule = 'PS.DrawIO.Registry.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'c3a0e5a9-7de7-4d96-9d19-2f9ef5dcf7b1'
    Author = 'Jerry Balmer'
    Description = 'Contract broker and provider registry for the PS.DrawIO ecosystem.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Register-PSDrawIOProvider',
        'Get-PSDrawIOProvider',
        'Unregister-PSDrawIOProvider',
        'Resolve-PSDrawIOShape',
        'Test-PSDrawIOCapability',
        'New-PSDrawIOProvider',
        'Test-PSDrawIOProviderConformance',
        'Test-PSDrawIOName'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('PSDrawIO', 'Registry', 'Provider')
        }
    }
}
