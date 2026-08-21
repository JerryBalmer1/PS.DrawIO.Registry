$script:registryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script:specificationPath = Join-Path $script:registryRoot 'REGISTRY.md'
$script:acceptanceLabels = Select-String -Path $script:specificationPath -Pattern '^\- \[[ x]\] (.+)$' | ForEach-Object { $_.Matches[0].Groups[1].Value }
$script:registeredAcceptanceLabels = @()

function Get-Label {
    param([Parameter(Mandatory)][string]$Match)

    $normalizedMatch = $Match.Replace('`', '')
    $hit = @($script:acceptanceLabels | Where-Object { $_.Replace('`', '') -like "*$normalizedMatch*" })
    if ($hit.Count -ne 1) { throw "Spec label '$Match' matched $($hit.Count) checkboxes" }
    $script:registeredAcceptanceLabels += $hit[0]
    $hit[0]
}

BeforeAll {
    if (-not $script:registryRoot) {
        $script:registryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    }
    Import-Module (Join-Path $script:registryRoot 'src/PS.DrawIO.Registry.psd1') -Force
}

Describe 'PS.DrawIO.Registry acceptance' -Tag Acceptance {
    BeforeEach {
        Get-PSDrawIOProvider | ForEach-Object { Unregister-PSDrawIOProvider -Name $_.ProviderName -Confirm:$false }
    }

    It (Get-Label 'Provider contract v1') -Tag Acceptance {
        (Get-Content (Join-Path $script:registryRoot 'docs/CONTRACT.md') -Raw) | Should -Match 'ContractVersion'
        (Get-Content (Join-Path $script:registryRoot 'docs/CONTRACT.md') -Raw) | Should -Match 'Shapes'
    }

    It (Get-Label 'Contract schema validates') -Tag Acceptance {
        $valid = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Valid'; Capabilities = @('Shapes'); Shapes = @{} } } }
        Register-PSDrawIOProvider -Manifest $valid | Should -Not -BeNullOrEmpty
        $invalid = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Valid'; Shapes = @{} } } }
        { Register-PSDrawIOProvider -Manifest $invalid -ErrorAction Stop } | Should -Throw '*Capabilities*'
    }

    It (Get-Label 'is read from') -Tag Acceptance {
        $manifest = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Versioned'; Capabilities = @('Shapes'); Shapes = @{} } } }
        Register-PSDrawIOProvider -Manifest $manifest | Select-Object -ExpandProperty ContractVersion | Should -Be 1
    }

    It (Get-Label 'Registration **fails loudly**') -Tag Acceptance {
        $manifest = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 2; ProviderName = 'Future'; Capabilities = @('Shapes'); Shapes = @{} } } }
        { Register-PSDrawIOProvider -Manifest $manifest -ErrorAction Stop } | Should -Throw '*contract 2*contract 1*'
    }

    It (Get-Label 'validates, then stores') -Tag Acceptance {
        $manifest = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Registerable'; Capabilities = @('Shapes'); Shapes = @{} } } }
        Register-PSDrawIOProvider -Manifest $manifest | Select-Object -ExpandProperty ProviderName | Should -Be 'Registerable'
    }

    It (Get-Label '`Get-PSDrawIOProvider`') -Tag Acceptance {
        Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Listed'; Capabilities = @('Shapes'); Shapes = @{} } } } | Out-Null
        (Get-PSDrawIOProvider -Name Listed).ProviderName | Should -Be 'Listed'
    }

    It (Get-Label '`Unregister-PSDrawIOProvider`') -Tag Acceptance {
        Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Removable'; Capabilities = @('Shapes'); Shapes = @{} } } } | Out-Null
        Unregister-PSDrawIOProvider -Name Removable -Confirm:$false
        Get-PSDrawIOProvider -Name Removable | Should -BeNullOrEmpty
    }

    It (Get-Label '`Resolve-PSDrawIOShape`') -Tag Acceptance {
        Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Resolver'; Capabilities = @('Shapes'); Shapes = @{ Resource = @{ Style = 'rounded=1;' } } } } } | Out-Null
        Resolve-PSDrawIOShape -Provider Resolver -Type Resource | Select-Object -ExpandProperty Style | Should -Be 'rounded=1;'
    }

    It (Get-Label '`Test-PSDrawIOCapability`') -Tag Acceptance {
        Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Capable'; Capabilities = @('Shapes','Links'); Shapes = @{} } } } | Out-Null
        Test-PSDrawIOCapability -Provider Capable -Name Links | Should -BeTrue
    }

    It (Get-Label '`New-PSDrawIOProvider`') -Tag Acceptance {
        $destination = Join-Path $TestDrive 'RealProvider'
        $manifestPath = New-PSDrawIOProvider -Name Fixture -Path $destination
        Test-Path $manifestPath | Should -BeTrue
        Test-Path (Join-Path $destination 'README.md') | Should -BeTrue
        Test-Path (Join-Path $destination 'PS.DrawIO.Provider.Fixture.psm1') | Should -BeTrue
        $fixturePath = New-PSDrawIOProvider -Name Disposable -Path (Join-Path $TestDrive 'FixtureProvider') -Fixture
        Test-PSDrawIOProviderConformance -Path $fixturePath | Should -BeTrue
    }

    It (Get-Label '`Test-PSDrawIOProviderConformance`') -Tag Acceptance {
        $manifest = @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Conformant'; Capabilities = @('Shapes'); Shapes = @{ Resource = @{} } } } }
        Test-PSDrawIOProviderConformance -Manifest $manifest | Should -BeTrue
    }

    It (Get-Label '`Test-PSDrawIOName`') -Tag Acceptance {
        Test-PSDrawIOName -Name PowerShell | Should -BeTrue
        Test-PSDrawIOName -Name 'bad.name' | Should -BeFalse
    }

    It (Get-Label 'Every public function has comment-based help') -Tag Acceptance {
        $manifest = Import-PowerShellDataFile (Join-Path $script:registryRoot 'src/PS.DrawIO.Registry.psd1')
        foreach ($name in $manifest.FunctionsToExport) {
            (Get-Help $name -ErrorAction Stop).Synopsis | Should -Not -BeNullOrEmpty
            (Get-Help $name -Examples).Examples.Example | Should -Not -BeNullOrEmpty
        }
    }

    It (Get-Label 'Provider names validated') -Tag Acceptance {
        { Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'bad.name'; Capabilities = @('Shapes'); Shapes = @{} } } } -ErrorAction Stop } | Should -Throw '*Provider name*'
        Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Taken'; Capabilities = @('Shapes'); Shapes = @{} } } } | Out-Null
        { Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Taken'; Capabilities = @('Shapes'); Shapes = @{} } } } -ErrorAction Stop } | Should -Throw '*already registered*'
    }

    It (Get-Label 'Filename convention parser') -Tag Acceptance {
        $parts = Test-PSDrawIOName -Path 'Function.PowerShell.drawio.ps1'
        $parts.Component | Should -Be 'Function'
        $parts.Provider | Should -Be 'PowerShell'
        $parts.Kind | Should -Be 'ps1'
        { Test-PSDrawIOName -Path 'not-a-provider.txt' -ErrorAction Stop } | Should -Throw '*does not match*'
    }

    It (Get-Label 'Invalid names rejected at registration') -Tag Acceptance {
        { Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'invalid.name'; Capabilities = @('Shapes'); Shapes = @{} } } } -ErrorAction Stop } | Should -Throw
    }

    It (Get-Label 'Pester 5 suite green') -Tag Acceptance {
        $workflow = Get-Content (Join-Path $script:registryRoot '.github/workflows/ci.yml') -Raw
        $workflow | Should -Match 'windows-latest'
        $workflow | Should -Match 'ubuntu-latest'
        $workflow | Should -Match 'pwsh'

        # Sign-off cannot equal HEAD after the file is committed (hash moves).
        # Ancestry + drift: Commit must be a real commit; git diff Commit HEAD
        # may list only docs/SIGNOFF.json. Working-tree/index changes under src/
        # relative to Commit also count as stale source (proof: touch src/).
        $signoffPath = Join-Path $script:registryRoot 'docs/SIGNOFF.json'
        $signoff = Get-Content -LiteralPath $signoffPath -Raw | ConvertFrom-Json
        $signoff.Commit | Should -Not -BeNullOrEmpty
        $commitType = git -C $script:registryRoot cat-file -t $signoff.Commit 2>$null
        $commitType | Should -Be 'commit'
        git -C $script:registryRoot merge-base --is-ancestor $signoff.Commit HEAD
        $LASTEXITCODE | Should -Be 0 -Because "sign-off Commit must be an ancestor of HEAD"

        $committedDrift = @(
            git -C $script:registryRoot diff --name-only $signoff.Commit HEAD |
                Where-Object { $_ -and ($_ -ne 'docs/SIGNOFF.json') }
        )
        $committedDrift | Should -BeNullOrEmpty -Because "signed commit $($signoff.Commit) must match HEAD except docs/SIGNOFF.json; drifted: $($committedDrift -join ', ')"

        $sourceDrift = @(
            git -C $script:registryRoot diff --name-only $signoff.Commit -- src/
            git -C $script:registryRoot diff --name-only --cached $signoff.Commit -- src/
        ) | Where-Object { $_ } | Select-Object -Unique
        $sourceDrift | Should -BeNullOrEmpty -Because "src/ must not drift from signed commit $($signoff.Commit); drifted: $($sourceDrift -join ', ')"

        $signoff.Items | Should -Not -BeNullOrEmpty
        foreach ($item in @($signoff.Items)) {
            $item.Signed | Should -BeTrue -Because "sign-off item '$($item.Label)' must be Signed"
            $item.Signer | Should -Not -BeNullOrEmpty -Because "sign-off item '$($item.Label)' must name a Signer"
            $item.Date | Should -Not -BeNullOrEmpty -Because "sign-off item '$($item.Label)' must have a Date"
        }
    }

    It (Get-Label 'Code coverage') -Tag Acceptance {
        $public = Invoke-Pester (Join-Path $script:registryRoot 'tests/Unit') -CodeCoverage (Join-Path $script:registryRoot 'src/Public/*.ps1') -PassThru
        $overall = Invoke-Pester (Join-Path $script:registryRoot 'tests/Unit') -CodeCoverage (Join-Path $script:registryRoot 'src/**/*.ps1') -PassThru
        $public.CodeCoverage.CoveragePercent | Should -BeGreaterOrEqual 90
        $overall.CodeCoverage.CoveragePercent | Should -BeGreaterOrEqual 80
    }

    It (Get-Label '`PSScriptAnalyzer` clean') -Tag Acceptance {
        Invoke-ScriptAnalyzer -Path (Join-Path $script:registryRoot 'src') -Recurse -Severity Error, Warning | Should -BeNullOrEmpty
    }

    It (Get-Label '`Test-ModuleManifest` passes') -Tag Acceptance {
        Test-ModuleManifest (Join-Path $script:registryRoot 'src/PS.DrawIO.Registry.psd1') | Should -Not -BeNullOrEmpty
    }

    It (Get-Label 'Module imports clean') -Tag Acceptance {
        $manifest = Join-Path $script:registryRoot 'src/PS.DrawIO.Registry.psd1'
        $command = "`$ErrorActionPreference = 'Stop'; Import-Module '$manifest' -Force; (Get-Module PS.DrawIO.Registry).Name"
        $output = & pwsh -NoLogo -NoProfile -NonInteractive -Command $command 2>&1
        $LASTEXITCODE | Should -Be 0
        @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should -Be 0
        $output | Should -Contain 'PS.DrawIO.Registry'
    }

    It (Get-Label 'No function in `src/Public`') -Tag Acceptance {
        Get-ChildItem (Join-Path $script:registryRoot 'src/Public') -Filter '*.ps1' | ForEach-Object { (Get-Content $_.FullName).Count | Should -BeLessOrEqual 100 }
    }

    It (Get-Label 'All exported names') -Tag Acceptance {
        $commands = (Get-Module PS.DrawIO.Registry).ExportedCommands.Keys
        foreach ($name in $commands) { (Get-Verb ($name -split '-', 2)[0]).Verb | Should -Not -BeNullOrEmpty }
    }

    It (Get-Label 'scaffolded provider registers') -Tag Acceptance {
        $manifestPath = New-PSDrawIOProvider -Name EndToEnd -Path (Join-Path $TestDrive 'EndToEnd')
        Register-PSDrawIOProvider -Path $manifestPath | Select-Object -ExpandProperty ProviderName | Should -Be 'EndToEnd'
        Test-PSDrawIOProviderConformance -Path $manifestPath | Should -BeTrue
    }

    It (Get-Label 'Two providers coexist') -Tag Acceptance {
        foreach ($name in 'Azure', 'Terraform') { Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = $name; Capabilities = @('Shapes'); Shapes = @{ Resource = @{ Provider = $name } } } } } | Out-Null }
        (Resolve-PSDrawIOShape -Provider Azure -Type Resource).Provider | Should -Be 'Azure'
        (Resolve-PSDrawIOShape -Provider Terraform -Type Resource).Provider | Should -Be 'Terraform'
    }

    It (Get-Label 'provider declaring contract `2`') -Tag Acceptance {
        { Register-PSDrawIOProvider -Manifest @{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 2; ProviderName = 'Future'; Capabilities = @('Shapes'); Shapes = @{} } } } -ErrorAction Stop } | Should -Throw '*contract 2*contract 1*'
    }

    It (Get-Label 'deliberately malformed provider') -Tag Acceptance {
        $malformed = Join-Path $TestDrive 'Malformed.psd1'
        "@{ PrivateData = @{ PSDrawIO = @{ ContractVersion = 1; ProviderName = 'Broken'; Capabilities = @('Shapes') } } }" | Set-Content $malformed
        { Test-PSDrawIOProviderConformance -Path $malformed -ErrorAction Stop } | Should -Not -Throw
        Test-PSDrawIOProviderConformance -Path $malformed | Should -BeFalse
    }

    It (Get-Label '`README.md` — install') -Tag Acceptance {
        $lines = @(Get-Content (Join-Path $script:registryRoot 'README.md')) | Where-Object { $_.Trim() }
        $lines.Count | Should -BeLessOrEqual 20
        (Get-Content (Join-Path $script:registryRoot 'README.md') -Raw) | Should -Match 'Register-PSDrawIOProvider'
        (Get-Content (Join-Path $script:registryRoot 'README.md') -Raw) | Should -Match 'Resolve-PSDrawIOShape'
    }

    It (Get-Label '`docs/CONTRACT.md` — the frozen contract') -Tag Acceptance {
        Test-Path (Join-Path $script:registryRoot 'docs/CONTRACT.md') | Should -BeTrue
    }

    It (Get-Label '`docs/AUTHORING-PROVIDERS.md`') -Tag Acceptance {
        Test-Path (Join-Path $script:registryRoot 'docs/AUTHORING-PROVIDERS.md') | Should -BeTrue
    }

    It (Get-Label '`CHANGELOG.md` following') -Tag Acceptance {
        (Get-Content (Join-Path $script:registryRoot 'CHANGELOG.md') -Raw) | Should -Match '\[Unreleased\]'
    }

    It 'has one acceptance It block for every REGISTRY.md checkbox' -Tag Acceptance {
        foreach ($label in $script:acceptanceLabels) { $script:registeredAcceptanceLabels | Should -Contain $label }
    }
}
