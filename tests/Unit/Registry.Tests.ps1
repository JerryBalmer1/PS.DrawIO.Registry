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

    It 'returns a boundary-safe declaration object' {
        $manifest = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Boundary'; Capabilities = @('Shapes'); Shapes = @{} } } }
        $declaration = Register-PSDrawIOProvider -Manifest $manifest

        $declaration.PSTypeNames | Should -Contain 'PS.DrawIO.ProviderDeclaration'
        $declaration.GetType().Name | Should -Not -Be 'PSDrawIOProviderDeclaration'
    }

    It 'keeps declarations usable after registry module reload' {
        $manifest = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Reloadable'; Capabilities = @('Shapes'); Shapes = @{ Resource = @{ Style = 'reload-safe' } } } } }
        $declaration = Register-PSDrawIOProvider -Manifest $manifest
        Import-Module (Join-Path $PSScriptRoot '../../src/PS.DrawIO.Registry.psd1') -Force

        $declaration.PSTypeNames | Should -Contain 'PS.DrawIO.ProviderDeclaration'
        $declaration.ProviderName | Should -Be 'Reloadable'
    }

    It 'throws for a missing conformance manifest path' {
        { Test-PSDrawIOProviderConformance -Path (Join-Path $TestDrive 'missing.psd1') -ErrorAction Stop } | Should -Throw '*was not found*'
    }

    It 'returns false for a real non-conformant manifest' {
        $manifest = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'NonConformant'; Shapes = @{} } } }
        Test-PSDrawIOProviderConformance -Manifest $manifest | Should -BeFalse
    }

    It 'reports a failed conformance run when the manifest input is absent' {
        $previous = $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON
        try {
            Remove-Item Env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON -ErrorAction SilentlyContinue
            $suite = Join-Path $PSScriptRoot '../../src/Conformance/Provider.Conformance.Tests.ps1'
            # Pester catches BeforeAll failures and returns a result; it does not rethrow.
            $result = Invoke-Pester -Path $suite -PassThru
            $result.FailedCount | Should -BeGreaterThan 0
        } finally {
            if ($null -eq $previous) { Remove-Item Env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON -ErrorAction SilentlyContinue } else { $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON = $previous }
        }
    }

    It 'reports failed conformance for missing capabilities' {
        $previous = $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON
        try {
            $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON = (@{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'MissingCapabilities'; Shapes = @{} } } } | ConvertTo-Json -Depth 20 -Compress)
            $result = Invoke-Pester -Path (Join-Path $PSScriptRoot '../../src/Conformance/Provider.Conformance.Tests.ps1') -PassThru
            $result.FailedCount | Should -BeGreaterThan 0
        } finally {
            if ($null -eq $previous) { Remove-Item Env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON -ErrorAction SilentlyContinue } else { $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON = $previous }
        }
    }

    It 'reports failed conformance for an invalid provider name' {
        $previous = $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON
        try {
            $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON = (@{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'bad.name'; Capabilities = @('Shapes'); Shapes = @{} } } } | ConvertTo-Json -Depth 20 -Compress)
            $result = Invoke-Pester -Path (Join-Path $PSScriptRoot '../../src/Conformance/Provider.Conformance.Tests.ps1') -PassThru
            $result.FailedCount | Should -BeGreaterThan 0
        } finally {
            if ($null -eq $previous) { Remove-Item Env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON -ErrorAction SilentlyContinue } else { $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON = $previous }
        }
    }

    It 'packages the conformance suite in the module payload' {
        $build = Join-Path $PSScriptRoot '../../build/build.ps1'
        & pwsh -NoLogo -NoProfile -NonInteractive -File $build -Task Package | Out-Null
        $packageSuite = Join-Path $PSScriptRoot '../../dist/PS.DrawIO.Registry/Conformance/Provider.Conformance.Tests.ps1'
        Test-Path $packageSuite | Should -BeTrue
    }

    It 'throws when the packaged conformance suite is missing' {
        $build = Join-Path $PSScriptRoot '../../build/build.ps1'
        & pwsh -NoLogo -NoProfile -NonInteractive -File $build -Task Package | Out-Null
        $packageManifest = Join-Path $PSScriptRoot '../../dist/PS.DrawIO.Registry/PS.DrawIO.Registry.psd1'
        $packageSuite = Join-Path $PSScriptRoot '../../dist/PS.DrawIO.Registry/Conformance/Provider.Conformance.Tests.ps1'
        Remove-Item -LiteralPath $packageSuite -Force
        $manifest = Join-Path $TestDrive 'PackagedProvider.psd1'
        "@{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Packaged'; Capabilities = @('Shapes'); Shapes = @{} } } }" | Set-Content $manifest
        $command = "`$ErrorActionPreference = 'Stop'; Import-Module '$packageManifest' -Force; Test-PSDrawIOProviderConformance -Path '$manifest'"
        $output = & pwsh -NoLogo -NoProfile -NonInteractive -Command $command 2>&1 | Out-String
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match 'Provider conformance suite'
    }

    It 'scaffolds a runnable provider conformance test' {
        $destination = Join-Path $TestDrive 'RunnableProvider'
        $manifestPath = New-PSDrawIOProvider -Name Runnable -Path $destination
        $testPath = Join-Path $destination 'tests/Conformance/Provider.Conformance.Tests.ps1'
        Test-Path $testPath | Should -BeTrue
        $previous = $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON
        try {
            $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON = (Import-PowerShellDataFile -LiteralPath $manifestPath | ConvertTo-Json -Depth 20 -Compress)
            $result = Invoke-Pester -Path $testPath -PassThru
            $result.FailedCount | Should -Be 0
            $result.Containers.TotalCount | Should -BeGreaterThan 0
        } finally {
            if ($null -eq $previous) { Remove-Item Env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON -ErrorAction SilentlyContinue } else { $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON = $previous }
        }
    }

    It 'has a valid about_ help topic file' {
        $helpFile = Join-Path $PSScriptRoot '../../src/en-US/about_PS.DrawIO.Registry.help.txt'
        Test-Path -LiteralPath $helpFile | Should -BeTrue
    }
}
