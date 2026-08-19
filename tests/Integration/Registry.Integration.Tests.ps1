BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/PS.DrawIO.Registry.psd1') -Force
}

Describe 'Registry multi-provider integration' {
    BeforeEach {
        Get-PSDrawIOProvider | ForEach-Object { Unregister-PSDrawIOProvider -Name $_.ProviderName -Confirm:$false }
    }

    It 'keeps provider replacement isolated while another provider remains registered' {
        Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Alpha'; Capabilities = @('Shapes'); Shapes = @{ Resource = @{ Version = 'one' } } } } } | Out-Null
        Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Beta'; Capabilities = @('Shapes'); Shapes = @{ Resource = @{ Version = 'beta' } } } } } | Out-Null
        Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Alpha'; Capabilities = @('Shapes'); Shapes = @{ Resource = @{ Version = 'two' } } } } } -Force | Out-Null

        Resolve-PSDrawIOShape -Provider Alpha -Type Resource | Select-Object -ExpandProperty Version | Should -Be 'two'
        Resolve-PSDrawIOShape -Provider Beta -Type Resource | Select-Object -ExpandProperty Version | Should -Be 'beta'
    }
}