BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/PS.DrawIO.Registry.psd1') -Force
}

Describe 'PS.DrawIO.Registry' {
    BeforeEach {
        Get-PSDrawIOProvider | ForEach-Object { Unregister-PSDrawIOProvider -Name $_.ProviderName -Confirm:$false }
    }

    It 'registers, resolves, and negotiates a provider' {
        $manifest = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'PowerShell'; Capabilities = @('Shapes','Links'); Shapes = @{ PSFunction = @{ Style = 'rounded=1;' } } } } }
        Register-PSDrawIOProvider -Manifest $manifest | Should -Not -BeNullOrEmpty
        (Resolve-PSDrawIOShape -Provider PowerShell -Type PSFunction).Style | Should -Be 'rounded=1;'
        Test-PSDrawIOCapability -Provider PowerShell -Name Links | Should -BeTrue
    }

    It 'rejects a contract major mismatch with both versions' {
        $manifest = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 2; ProviderName = 'Future'; Capabilities = @('Shapes'); Shapes = @{} } } }
        { Register-PSDrawIOProvider -Manifest $manifest -ErrorAction Stop } | Should -Throw '*contract 2*contract 1*'
    }

    It 'rejects malformed declarations and names the field' {
        $manifest = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Bad.Name'; Shapes = @{} } } }
        { Register-PSDrawIOProvider -Manifest $manifest -ErrorAction Stop } | Should -Throw '*Capabilities*'
    }

    It 'keeps two providers isolated' {
        foreach ($name in 'Azure', 'Terraform') {
            Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = $name; Capabilities = @('Shapes'); Shapes = @{ Resource = @{ Provider = $name } } } } } | Out-Null
        }
        (Resolve-PSDrawIOShape -Provider Azure -Type Resource).Provider | Should -Be 'Azure'
        (Resolve-PSDrawIOShape -Provider Terraform -Type Resource).Provider | Should -Be 'Terraform'
    }

    It 'parses diagram filenames and validates names' {
        (Test-PSDrawIOName -Name PowerShell) | Should -BeTrue
        (Test-PSDrawIOName -Name 'bad.name') | Should -BeFalse
        $parts = Test-PSDrawIOName -Path 'Function.PowerShell.drawio.ps1'
        $parts.Component | Should -Be 'Function'
        $parts.Provider | Should -Be 'PowerShell'
        $parts.Kind | Should -Be 'ps1'
    }

    It 'scaffolds a fixture that passes conformance' {
        $destination = Join-Path $TestDrive 'Provider'
        $manifestPath = New-PSDrawIOProvider -Name Fixture -Path $destination -Fixture
        Test-Path $manifestPath | Should -BeTrue
        Test-PSDrawIOProviderConformance -Path $manifestPath | Should -BeTrue
    }
}
